#!/usr/bin/env bash

# NVIDIA DGX Spark - Distributed NIM / TensorRT-LLM Launcher
#
# Installation:
#   curl -O https://raw.githubusercontent.com/toxicoder/devset/main/dgx-spark/scripts/run-distributed-model.sh && chmod +x run-distributed-model.sh
#
# This script spins up a distributed Inference Service across two DGX Spark nodes.
# It supports various high-parameter LLMs and Multimodal models, optimizing for
# high-speed interconnects (OSPF/IB/RoCE) and distributed tensor parallelism.
#
# Engines Supported:
# 1. NVIDIA NIM (vLLM backend default) - Easiest, standardized.
# 2. TensorRT-LLM (Native) - Maximum performance, custom engine building.
#
# Key Features:
# - Top 20 Open Source Model Registry (Llama 3.x, Qwen, Mistral, Gemma, DeepSeek)
# - Distributed Tensor Parallelism (TP=2) over NCCL/RoCE
# - Support for FP4/FP8/INT8 quantization and Speculative Decoding
# - Automatic Networking Setup for High-Performance Fabrics
# - Auto-Model Download and Engine Building (TRT-LLM mode)
#
# Assumes:
# 1. Passwordless SSH is configured between the runner and both nodes.
# 2. NGC_API_KEY is exported in the environment.
# 3. Docker and NVIDIA Container Toolkit are installed on both nodes.
# 4. The nodes are connected via a high-speed interconnect (200Gbps+).

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly CONFIG_FILE="$SCRIPT_DIR/dgx-spark-distributed-model-config.json"
# SSH options
readonly SSH_OPTS=(-o StrictHostKeyChecking=no -o ConnectTimeout=10)

# Global configuration variables
IP1=""
IP2=""
MODEL_ARG=""
MODE="setup"
IMAGE=""
PARAMS=0
CONTEXT=0
TP_SIZE=2
PP_SIZE=1
IS_VISION=0
EXTRA_NIM_ENV=""
PLATFORM_ARG=""
IFACES1=""
IFACES2=""
NET_CONF_1=""
NET_CONF_2=""
QUANT_OVERRIDE=""
ENGINE_OVERRIDE=""
IMAGE_OVERRIDE=""
BATCH_SIZE=128
MAX_SEQ_LEN=2048
WANDB_KEY=""
SPECULATIVE_MODE=0
DRY_RUN=0
FORCE=0
HF_TOKEN="${HF_TOKEN:-}"

# TRT-LLM Specifics
USE_TRT_LLM=0
HF_MODEL_ID=""
TRT_ENGINE_DIR="~/engines"
TRT_MODEL_DIR="~/models"

# Error handling and cleanup
function cleanup() {
  jobs -p | xargs -r kill 2>/dev/null || true
}
trap cleanup EXIT ERR

# Internal: Check dependencies
function _check_dependencies() {
  for cmd in ssh awk grep sed nc curl pigz python3; do
    if ! command -v "$cmd" &>/dev/null; then
      printf "Error: Required command '%s' not found.\n" "$cmd" >&2
      exit 1
    fi
  done
}

# Internal: Read configuration
function _read_config() {
  if [[ ! -f "$CONFIG_FILE" ]]; then
    printf "Error: Config file not found at %s\n" "$CONFIG_FILE" >&2
    exit 1
  fi

  # Python parsing
  local config_values
  config_values=$(python3 -c "import sys, json; data=json.load(open(sys.argv[1])); print(f\"{data.get('ip1','')}|{data.get('ip2','')}|{data.get('model','')}|{data.get('engine','')}|{data.get('image','')}\")" "$CONFIG_FILE")

  if [[ $? -ne 0 ]]; then
     printf "Error: Failed to parse config file with python.\n" >&2
     exit 1
  fi

  IP1=$(echo "$config_values" | cut -d'|' -f1)
  IP2=$(echo "$config_values" | cut -d'|' -f2)
  MODEL_ARG=$(echo "$config_values" | cut -d'|' -f3)
  local saved_engine
  saved_engine=$(echo "$config_values" | cut -d'|' -f4)
  local saved_image
  saved_image=$(echo "$config_values" | cut -d'|' -f5)

  if [[ -n "$saved_engine" && -z "$ENGINE_OVERRIDE" ]]; then
    ENGINE_OVERRIDE="$saved_engine"
  fi
  if [[ -n "$saved_image" && -z "$IMAGE_OVERRIDE" ]]; then
    IMAGE_OVERRIDE="$saved_image"
  fi

  if [[ -z "$IP1" || -z "$IP2" || -z "$MODEL_ARG" ]]; then
    printf "Error: Invalid config file (missing fields).\n" >&2
    exit 1
  fi
}

# Internal: Write configuration
function _write_config() {
  cat >"$CONFIG_FILE" <<EOF
{
    "ip1": "$IP1",
    "ip2": "$IP2",
    "model": "$MODEL_ARG",
    "engine": "$ENGINE_OVERRIDE",
    "image": "$IMAGE_OVERRIDE"
}
EOF
  printf "Configuration saved to %s\n" "$CONFIG_FILE"
}

# Internal: Parse arguments
function _parse_arguments() {
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --dry-run) DRY_RUN=1; shift ;;
      --force) FORCE=1; shift ;;
      --quant)
        if [[ -z "${2:-}" ]]; then printf "Error: --quant requires argument\n" >&2; exit 1; fi
        QUANT_OVERRIDE="$2"; shift 2 ;;
      --engine)
        if [[ -z "${2:-}" ]]; then printf "Error: --engine requires argument\n" >&2; exit 1; fi
        ENGINE_OVERRIDE="$2"; shift 2 ;;
      --image)
        if [[ -z "${2:-}" ]]; then printf "Error: --image requires argument\n" >&2; exit 1; fi
        IMAGE_OVERRIDE="$2"; shift 2 ;;
      --batch-size) BATCH_SIZE="$2"; shift 2 ;;
      --max-seq-len) MAX_SEQ_LEN="$2"; shift 2 ;;
      --wandb-key) WANDB_KEY="$2"; shift 2 ;;
      --speculative) SPECULATIVE_MODE=1; shift ;;
      -*) printf "Error: Unknown option %s\n" "$1" >&2; exit 1 ;;
      *) break ;;
    esac
  done

  if [[ "$#" -eq 1 && "$1" == "stop" ]]; then
    MODE="stop"
  elif [[ "$#" -eq 1 && "$1" == "start" ]]; then
    MODE="start"
  elif [[ "$#" -ge 2 && "$#" -le 3 ]]; then
    MODE="setup"
  else
    printf "Usage:\n"
    printf "  %s [OPTIONS] <IP1> <IP2> [<MODEL_NAME|HF_URL>]  (First run / Setup)\n" "$0"
    printf "  %s [OPTIONS] start                              (Start using saved config)\n" "$0"
    printf "  %s [OPTIONS] stop                               (Stop using saved config)\n" "$0"
    printf "\nOptions:\n"
    printf "  --dry-run             Print commands without executing\n"
    printf "  --force               Bypass safety checks\n"
    printf "  --quant <fmt>         Force quantization (fp4, fp8, int8)\n"
    printf "  --engine <name>       Backend engine (vllm, trt-llm)\n"
    printf "  --image <name>        Custom Docker image override\n"
    printf "  --batch-size <n>      Max batch size (default: 128)\n"
    printf "  --max-seq-len <n>     Max sequence length (default: 2048)\n"
    exit 1
  fi

  if [[ "$MODE" == "stop" ]]; then
    _read_config
  elif [[ "$MODE" == "start" ]]; then
    _read_config
  elif [[ "$MODE" == "setup" ]]; then
    IP1="$1"
    IP2="$2"
    MODEL_ARG="${3:-"meta/llama-3.1-70b-instruct"}"
    MODEL_ARG=$(echo "$MODEL_ARG" | tr '[:upper:]' '[:lower:]')
    _write_config
  fi
}

# Internal: Validate IP Address
function _validate_ip() {
  local ip="$1"
  if [[ ! "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    printf "Error: Invalid IP format '%s'\n" "$ip" >&2
    exit 1
  fi
}

# Internal: Check API Key
function _check_api_key() {
  if [[ -z "${NGC_API_KEY:-}" ]]; then
    printf "Error: NGC_API_KEY environment variable is not set.\n" >&2
    exit 1
  fi
}

# Internal: Check HF Token (for TRT-LLM)
function _check_hf_token() {
  if [[ -z "${HF_TOKEN:-}" ]]; then
    printf "Error: HF_TOKEN environment variable is required for TRT-LLM mode to download models.\n" >&2
    printf "Please export your Hugging Face Token: export HF_TOKEN='hf_...'\n" >&2
    exit 1
  fi
}

# Internal: Get Model Registry
# Format: ModelID|ImageTag|TP|PP|DefaultQuant|Params(B)|IsVision|ExtraEnv|HF_ID
function _get_model_registry() {
  cat <<EOF
reasoning-1|deepseek-ai/deepseek-r1|2|1|fp4|671|0|-e NIM_MODEL_PROFILE=deepseek-r1|deepseek-ai/DeepSeek-R1
reasoning-2|alibaba/qwen3-30b-thinking|2|1|fp16|30|0|-e VLLM_ATTENTION_BACKEND=FLASHINFER|Qwen/Qwen2.5-32B-Instruct
reasoning-3|microsoft/phi-4-reasoning|1|1|fp16|14|0||microsoft/phi-4
mega-1|meta/llama-4-405b-instruct|2|1|fp4|405|0||meta-llama/Llama-4-405b-Instruct
mega-2|meta/llama-3.1-405b-instruct|2|1|fp4|405|0||meta-llama/Meta-Llama-3.1-405B-Instruct
mega-3|deepseek-ai/deepseek-v3|2|1|fp4|671|0|-e NIM_MODEL_PROFILE=deepseek-v3|deepseek-ai/DeepSeek-V3
mega-4|nvidia/nemotron-4-340b-instruct|2|1|fp4|340|0||nvidia/Nemotron-4-340B-Instruct
large-1|mistralai/mistral-large-2411|2|1|fp8|123|0||mistralai/Mistral-Large-Instruct-2411
large-2|alibaba/qwen3-235b-moe-instruct|2|1|fp4|235|0||Qwen/Qwen2.5-235B-Instruct
large-3|meta/llama-3.2-90b-vision-instruct|2|1|fp8|90|1||meta-llama/Llama-3.2-90B-Vision-Instruct
large-4|cohere/command-r-plus-08-2024|2|1|fp16|104|0||CohereForAI/c4ai-command-r-plus-08-2024
workhorse-1|meta/llama-3.3-70b-instruct|2|1|fp16|70|0||meta-llama/Llama-3.3-70B-Instruct
workhorse-2|meta/llama-4-maverick-instruct|2|1|fp16|70|0||meta-llama/Llama-4-70b-Instruct
workhorse-3|alibaba/qwen2.5-72b-instruct|2|1|fp16|72|0||Qwen/Qwen2.5-72B-Instruct
workhorse-4|nvidia/llama-3.1-nemotron-70b-instruct|2|1|fp16|70|0||nvidia/Llama-3.1-Nemotron-70B-Instruct
workhorse-5|mistralai/pixtral-large-2411|2|1|fp8|124|1||mistralai/Pixtral-Large-Instruct-2411
coding-1|deepseek-ai/deepseek-coder-v2-instruct|2|1|fp4|236|0||deepseek-ai/DeepSeek-Coder-V2-Instruct
coding-2|mistralai/codestral-2501|1|1|fp16|22|0||mistralai/Codestral-22B-v0.1
efficient-1|meta/llama-4-scout-instruct|1|1|fp16|15|0||meta-llama/Llama-4-15b-Instruct
efficient-2|google/gemma-3-27b-it|2|1|fp16|27|1||google/gemma-2-27b-it
efficient-3|microsoft/phi-4-mini-instruct|1|1|fp16|14|0||microsoft/Phi-4-mini-4k-instruct
efficient-4|google/gemma-2-27b-it|2|1|fp16|27|0||google/gemma-2-27b-it
efficient-5|nvidia/nemotron-3-nano-30b-a3b|1|2|fp16|30|0|-e VLLM_ATTENTION_BACKEND=FLASHINFER -e NIM_TAGS_SELECTOR=precision=bf16|nvidia/nemotron-3-nano-30b-a3b
special-1|allenai/molmo-72b-0924|2|1|fp16|72|1||allenai/Molmo-72B-0924
special-2|nvidia/nemotron-super-49b-reward|2|1|fp16|49|0||nvidia/Nemotron-Super-49B-Reward
special-3|meta/llama-guard-3-8b|1|1|fp16|8|0||meta-llama/Llama-Guard-3-8B
EOF
}

# Internal: Configure model parameters
function _configure_model() {
  # Defaults
  TP_SIZE=2
  PP_SIZE=1
  IS_VISION=0
  EXTRA_NIM_ENV=""
  PARAMS=10
  CONTEXT=128
  local default_quant="fp16"

  # Check for Hugging Face URL
  if [[ "$MODEL_ARG" =~ ^https://huggingface.co/ ]]; then
    local stripped="${MODEL_ARG#https://huggingface.co/}"
    # Extract Organization/Repo from URL (stripping subpaths like /tree/main)
    HF_MODEL_ID=$(echo "$stripped" | cut -d'/' -f1,2)
    MODEL_ARG="$HF_MODEL_ID"
    printf "Detected Hugging Face URL. Extracted Model ID: %s\n" "$HF_MODEL_ID"
  fi

  # Look up model
  local model_data
  model_data=$(_get_model_registry | grep -F "$MODEL_ARG" | head -n 1 || true)

  if [[ -n "$model_data" ]]; then
    # Parse data
    local nim_tag
    nim_tag=$(echo "$model_data" | cut -d'|' -f2)
    IMAGE="nvcr.io/nim/${nim_tag}:latest"
    TP_SIZE=$(echo "$model_data" | cut -d'|' -f3)
    PP_SIZE=$(echo "$model_data" | cut -d'|' -f4)
    default_quant=$(echo "$model_data" | cut -d'|' -f5)
    PARAMS=$(echo "$model_data" | cut -d'|' -f6)
    IS_VISION=$(echo "$model_data" | cut -d'|' -f7)
    HF_MODEL_ID=$(echo "$model_data" | cut -d'|' -f9)
    local extra
    extra=$(echo "$model_data" | cut -d'|' -f8)
    if [[ -n "$extra" ]]; then EXTRA_NIM_ENV="$extra"; fi
  else
    if [[ -n "$IMAGE_OVERRIDE" ]]; then
      # Image provided by user, assume manual configuration
      printf "Using custom image override: %s\n" "$IMAGE_OVERRIDE"
      IMAGE="$IMAGE_OVERRIDE"
      if [[ -z "$HF_MODEL_ID" ]]; then HF_MODEL_ID="$MODEL_ARG"; fi
    elif [[ -n "$HF_MODEL_ID" ]]; then
      # Custom HF Model without Image -> Default to TRT-LLM
      printf "Warning: Custom HF Model detected (%s) without corresponding NIM Image.\n" "$HF_MODEL_ID"
      printf "Defaulting to TensorRT-LLM Engine Build (Native).\n"
      USE_TRT_LLM=1
      IMAGE="nvcr.io/nvidia/tensorrt-llm/release:latest"
    elif [[ "$FORCE" -eq 1 ]]; then
      printf "Warning: Model '%s' not found in registry. Using as custom image.\n" "$MODEL_ARG"
      IMAGE="nvcr.io/nim/$MODEL_ARG:latest"
      if [[ -z "$HF_MODEL_ID" ]]; then HF_MODEL_ID="$MODEL_ARG"; fi
    else
      printf "Error: Model '%s' not found in the supported registry.\n" "$MODEL_ARG" >&2
      exit 1
    fi
  fi

  # Image Override (Precedence over registry unless TRT-LLM forced)
  if [[ -n "$IMAGE_OVERRIDE" ]]; then
    IMAGE="$IMAGE_OVERRIDE"
  fi

  # Engine Override
  if [[ "$ENGINE_OVERRIDE" == "trt-llm" || "$USE_TRT_LLM" -eq 1 ]]; then
    USE_TRT_LLM=1
    if [[ -z "$IMAGE_OVERRIDE" ]]; then
      IMAGE="nvcr.io/nvidia/tensorrt-llm/release:latest"
    fi
    printf "Engine Mode: TensorRT-LLM (Container: %s)\n" "$IMAGE"
    if [[ -z "$HF_MODEL_ID" ]]; then
       printf "Error: HF Model ID not found for %s. Cannot build engine.\n" "$MODEL_ARG" >&2
       exit 1
    fi
  elif [[ -n "$ENGINE_OVERRIDE" ]]; then
    EXTRA_NIM_ENV="$EXTRA_NIM_ENV -e NIM_ENGINE=$ENGINE_OVERRIDE"
    if [[ "$ENGINE_OVERRIDE" == "vllm" || "$ENGINE_OVERRIDE" == "sglang" ]]; then
       EXTRA_NIM_ENV="$EXTRA_NIM_ENV -e VLLM_ATTENTION_BACKEND=FLASHINFER"
    fi
  fi

  # Quantization
  local quant_to_use="$default_quant"
  if [[ -n "$QUANT_OVERRIDE" ]]; then quant_to_use="$QUANT_OVERRIDE"; fi

  if [[ "$USE_TRT_LLM" -eq 0 ]]; then
      if [[ "$quant_to_use" != "fp16" && "$quant_to_use" != "bf16" ]]; then
        EXTRA_NIM_ENV="$EXTRA_NIM_ENV -e NIM_QUANTIZATION=$quant_to_use"
      fi
      # Other NIM vars
      EXTRA_NIM_ENV="$EXTRA_NIM_ENV -e NIM_MAX_BATCH_SIZE=$BATCH_SIZE -e NIM_MAX_SEQ_LEN=$MAX_SEQ_LEN"
      if [[ "$SPECULATIVE_MODE" -eq 1 ]]; then
        EXTRA_NIM_ENV="$EXTRA_NIM_ENV -e NIM_SPECULATIVE_DECODING_MODE=EAGLE"
      fi
  fi

  # W&B
  if [[ -n "$WANDB_KEY" ]]; then
    EXTRA_NIM_ENV="$EXTRA_NIM_ENV -e WANDB_API_KEY=$WANDB_KEY -e NIM_WANDB_ENABLED=1"
  fi

  # Platform
  PLATFORM_ARG="--platform=linux/amd64"

  printf "=== NVIDIA DGX Spark Distributed Launcher ===\n"
  printf "Nodes: %s (Head), %s (Worker)\n" "$IP1" "$IP2"
  printf "Model: %s (HF ID: %s)\n" "$MODEL_ARG" "${HF_MODEL_ID:-N/A}"
  printf "Image: %s\n" "$IMAGE"
  printf "TP: %s, PP: %s, Quant: %s\n" "$TP_SIZE" "$PP_SIZE" "$quant_to_use"
}

# Internal: Check VRAM requirements
function _check_vram_requirements() {
  local params="$1"
  printf "[Check] verifying VRAM capacity...\n"
  local vram1
  vram1=$(ssh "${SSH_OPTS[@]}" "$IP1" "PATH=\$PATH:/usr/local/cuda/bin:/usr/bin nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits" 2>/dev/null | awk '{s+=$1} END {print s+0}')
  local vram2
  vram2=$(ssh "${SSH_OPTS[@]}" "$IP2" "PATH=\$PATH:/usr/local/cuda/bin:/usr/bin nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits" 2>/dev/null | awk '{s+=$1} END {print s+0}')

  local total_gb
  total_gb=$(awk -v v1="${vram1:-0}" -v v2="${vram2:-0}" 'BEGIN {print (v1 + v2) / 1024}')

  if awk -v t="$total_gb" 'BEGIN {exit !(t <= 0)}'; then
     if [[ "$FORCE" -eq 1 ]]; then
         printf "Warning: VRAM detection failed (Total: 0.00 GB). Force enabled, proceeding...\n" >&2
     else
         printf "Error: VRAM detection failed (Total: %.2f GB).\n" "$total_gb" >&2
         printf "Debug Info (Head Node %s):\n" "$IP1"
         ssh "${SSH_OPTS[@]}" "$IP1" "PATH=\$PATH:/usr/local/cuda/bin:/usr/bin nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits" || true
         exit 1
     fi
  fi
  printf "Total Cluster VRAM Detected: %.2f GB\n" "$total_gb"

  # Simple heuristic: If model requires more VRAM than detected (with buffer)
  # Rough estimate: PARAMS * 2 (FP16) / TP_SIZE
  # But we deal with total cluster VRAM here, so Params * 2
  local required_gb=$(( params * 2 ))

  if [[ "$QUANT_OVERRIDE" == "fp8" || "$EXTRA_NIM_ENV" == *"fp8"* ]]; then required_gb=$(( required_gb / 2 )); fi
  if [[ "$QUANT_OVERRIDE" == "fp4" || "$EXTRA_NIM_ENV" == *"fp4"* ]]; then required_gb=$(( required_gb / 4 )); fi

  # Add 20GB buffer for context/overhead
  required_gb=$(( required_gb + 20 ))

  if awk -v r="$required_gb" -v t="$total_gb" 'BEGIN {exit !(r > t)}'; then
    printf "CRITICAL WARNING: Estimated VRAM required (~%d GB) exceeds detected VRAM (%.2f GB).\n" \
        "$required_gb" "$total_gb"

    if [[ "$FORCE" -eq 1 ]]; then
       printf "Force enabled. Proceeding despite memory risks...\n"
    else
       printf "Aborting to prevent potential crash. Use --force to override.\n" >&2
       exit 1
    fi
  else
    printf "VRAM Check Passed (Est. %d GB < %.2f GB)\n" "$required_gb" "$total_gb"
  fi
}

# Internal: Detect architecture
function _detect_architecture() {
  local arch
  arch=$(ssh "${SSH_OPTS[@]}" "$IP1" "uname -m" 2>/dev/null | xargs)
  if [[ "$arch" == "x86_64" ]]; then PLATFORM_ARG="--platform linux/amd64";
  elif [[ "$arch" == "aarch64" ]]; then PLATFORM_ARG="--platform linux/arm64"; fi
}

# Internal: Detect high-speed network interfaces
function _get_network_config() {
  local ip="$1"
  # OSPF Autodetection
  local ospf_neighbors
  if ospf_neighbors=$(ssh "${SSH_OPTS[@]}" "$ip" \
    "sudo vtysh -c 'show ip ospf neighbor' 2>/dev/null"); then
    local ifaces
    ifaces=$(echo "$ospf_neighbors" | grep "Full" | awk '{print $6}' | sort | uniq | tr '\n' ',' | sed 's/,$//' || true)
    if [[ -n "$ifaces" ]]; then
      if [[ "$ifaces" == *","* ]]; then
        printf "DETECTED_MULTI: %s" "$ifaces"
        return
      else
        printf "DETECTED_SINGLE: %s" "$ifaces"
        return
      fi
    fi
  fi

  # Fallback to ibdev2netdev
  local iface
  iface=$(ssh "${SSH_OPTS[@]}" "$ip" \
    "ibdev2netdev 2>/dev/null | grep 'Up' | awk -F'==> ' '{print \$2}' | awk '{print \$1}' | head -n 1")

  if [[ -n "$iface" ]]; then
    printf "DETECTED_SINGLE: %s" "$iface"
  else
    printf "DETECTED_NONE"
  fi
}

# Internal: Parse network configuration
function _parse_net_conf() {
  local conf="$1"
  local val="${conf#*:}"
  val=$(printf "%s" "$val" | xargs)
  printf "%s" "$val"
}

# Internal: Detect network
function _detect_network() {
  printf "[1/5] Detecting high-speed network interfaces...\n"

  # Pre-flight check
  if ssh "${SSH_OPTS[@]}" "$IP1" "command -v ib_write_bw >/dev/null"; then
    printf "  [+] ib_write_bw detected (RoCE/IB support confirmed).\n"
  fi

  NET_CONF_1=$(_get_network_config "$IP1")
  NET_CONF_2=$(_get_network_config "$IP2")

  IFACES1=$(_parse_net_conf "$NET_CONF_1")
  IFACES2=$(_parse_net_conf "$NET_CONF_2")

  printf "Node 1 Interfaces: %s\n" "$IFACES1"
  printf "Node 2 Interfaces: %s\n" "$IFACES2"

  if [[ -z "$IFACES1" || -z "$IFACES2" || "$NET_CONF_1" == *"DETECTED_NONE"* ]]; then
    printf "Warning: No high-speed interfaces detected. Defaulting to standard networking.\n" >&2
    printf "Recommendation: Check netplan config for static IPs on high-speed interfaces.\n"
  fi
}

# Internal: Verify connectivity
function _verify_connectivity() {
  printf "[2/5] Verifying connectivity...\n"
  for ip in "$IP1" "$IP2"; do
    if ! ssh "${SSH_OPTS[@]}" "$ip" "nvidia-smi > /dev/null"; then
      printf "Error: Connectivity failed to %s.\n" "$ip" >&2; exit 1
    fi
  done
}

# Internal: Get IP from interface
function _get_ip_from_iface() {
  local ip_host="$1"
  local iface_list="$2"
  local iface
  iface=$(echo "$iface_list" | cut -d',' -f1)

  if [[ -z "$iface" ]]; then return 1; fi

  ssh "${SSH_OPTS[@]}" "$ip_host" \
    "ip -4 addr show $iface | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n 1"
}

# Internal: Ensure image present (with P2P)
function _ensure_image_present() {
  printf "Pulling image %s on Head Node (%s)...\n" "$IMAGE" "$IP1"
  if ! echo "$NGC_API_KEY" | ssh "${SSH_OPTS[@]}" "$IP1" \
    "docker login nvcr.io -u '\$oauthtoken' --password-stdin >/dev/null 2>&1 && docker pull $PLATFORM_ARG $IMAGE"; then
    printf "Error: Failed to pull image on %s\n" "$IP1" >&2; exit 1
  fi

  # Worker check
  printf "Checking image on Worker Node (%s)...\n" "$IP2"
  local id_head
  id_head=$(ssh "${SSH_OPTS[@]}" "$IP1" "docker inspect --format='{{.Id}}' $IMAGE 2>/dev/null" || true)
  local id_worker
  id_worker=$(ssh "${SSH_OPTS[@]}" "$IP2" "docker inspect --format='{{.Id}}' $IMAGE 2>/dev/null" || true)

  if [[ -n "$id_worker" && "$id_head" == "$id_worker" ]]; then
    printf "Image matches on %s.\n" "$IP2"
    return
  fi

  # P2P Transfer
  local transfer_done=0
  if [[ -n "$IFACES2" ]]; then
    local fast_ip2
    fast_ip2=$(_get_ip_from_iface "$IP2" "$IFACES2")
    if [[ -n "$fast_ip2" ]]; then
       printf "Using High-Speed P2P Transfer to %s (%s)...\n" "$IP2" "$fast_ip2"
       # Start listener
       ( ssh "${SSH_OPTS[@]}" "$IP2" "nc -l -p 12346 | pigz -d | docker load" ) &
       local pid=$!
       sleep 5
       # Start sender
       if ssh "${SSH_OPTS[@]}" "$IP1" "docker save $IMAGE | pigz -c -1 | nc -w 60 -q 1 $fast_ip2 12346"; then
          if wait "$pid"; then
             printf "Image transfer successful.\n"
             transfer_done=1
          fi
       fi
    fi
  fi

  if [[ "$transfer_done" -eq 1 ]]; then return; fi

  # Fallback
  printf "Downloading image on %s...\n" "$IP2"
  if ! echo "$NGC_API_KEY" | ssh "${SSH_OPTS[@]}" "$IP2" \
    "docker login nvcr.io -u '\$oauthtoken' --password-stdin >/dev/null 2>&1 && docker pull $PLATFORM_ARG $IMAGE"; then
    printf "Error: Failed to pull image on %s\n" "$IP2" >&2; exit 1
  fi
}

# Internal: Align platform with image
function _align_platform_with_image() {
  local img_arch
  img_arch=$(ssh "${SSH_OPTS[@]}" "$IP1" "docker inspect -f '{{.Architecture}}' $IMAGE" 2>/dev/null | xargs)

  if [[ -n "$img_arch" ]]; then
     if [[ "$img_arch" == "amd64" && "$PLATFORM_ARG" == *"--platform linux/arm64"* ]]; then
        printf "Error: Image architecture (%s) is incompatible with Host architecture (arm64).\n" "$img_arch" >&2
        exit 1
     elif [[ "$img_arch" == "arm64" && "$PLATFORM_ARG" == *"--platform linux/amd64"* ]]; then
        printf "Error: Image architecture (%s) is incompatible with Host architecture (x86_64).\n" "$img_arch" >&2
        exit 1
     fi
  fi
}

# Internal: Robust mkdir on remote host
function _remote_mkdir() {
  local ip="$1"
  local dirs="$2"
  local out
  # Try normal mkdir first, capturing output for debug
  if ! out=$(ssh "${SSH_OPTS[@]}" "$ip" "mkdir -p $dirs" 2>&1); then
     printf "Warning: mkdir failed on %s. Output: %s. Attempting with sudo...\n" "$ip" "$out"
     # Try with sudo and fix ownership
     # Added -t to force pseudo-terminal for sudo password prompt
     ssh -t "${SSH_OPTS[@]}" "$ip" "sudo mkdir -p $dirs && sudo chown -R \$(whoami) $dirs"
  fi
}

# Internal: Generate Heuristic Conversion Script (Python)
function _generate_converter_script() {
  local ip="$1"
  local path="$2"

  # We write the python script to a temp file then cat it to remote
  # This script attempts to find the correct convert_checkpoint.py based on config.json

  cat <<'PYTHON_SCRIPT' > /tmp/convert_heuristic.py
import os
import sys
import json
import subprocess
import argparse

def find_examples_dir():
    # Standard locations in NVIDIA containers
    candidates = [
        "/app/tensorrt_llm/examples",
        "/workspace/tensorrt_llm/examples",
        "/usr/local/lib/python3.12/dist-packages/tensorrt_llm/examples", # Py3.12
        "/usr/local/lib/python3.10/dist-packages/tensorrt_llm/examples", # Py3.10
        "/opt/tensorrt_llm/examples",
        "/usr/src/tensorrt_llm/examples"
    ]

    # Try to find via site-packages dynamically
    try:
        import site
        if hasattr(site, 'getsitepackages'):
            for p in site.getsitepackages():
                candidates.append(os.path.join(p, "tensorrt_llm", "examples"))
    except:
        pass

    # Also check sys.path
    for p in sys.path:
        candidates.append(os.path.join(p, "tensorrt_llm", "examples"))

    checked = []
    for c in candidates:
        if c in checked: continue
        checked.append(c)
        if os.path.exists(c):
             # Validate content (look for common examples to ensure it's the right dir)
             if os.path.exists(os.path.join(c, "llama")) or os.path.exists(os.path.join(c, "gpt")):
                 return c, checked

    # Fallback: Clone from GitHub if not found
    print("[Info] Examples not found in standard paths. Attempting to clone from GitHub...")
    try:
        # Check/Install git
        try:
            subprocess.check_call(["git", "--version"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except:
            print("[Info] git not found, attempting to install...")
            try:
                subprocess.check_call(["apt-get", "update", "-y"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                subprocess.check_call(["apt-get", "install", "-y", "git"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            except Exception as e:
                print(f"[Warning] Failed to install git: {e}")

        import tensorrt_llm
        version = tensorrt_llm.__version__
        # Clean version string (e.g., 0.10.0.dev -> 0.10.0) for tagging
        base_ver = version.split('+')[0].split('-')[0]

        clone_dir = "/tmp/tensorrt_llm_examples_repo"
        if not os.path.exists(clone_dir):
            tags_to_try = [f"v{base_ver}", f"release/{base_ver}", "main"]
            success = False
            for tag in tags_to_try:
                print(f"[Info] Trying to clone tag: {tag}")
                try:
                    subprocess.check_call(["git", "clone", "--depth", "1", "--branch", tag, "https://github.com/NVIDIA/TensorRT-LLM.git", clone_dir], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                    success = True
                    break
                except subprocess.CalledProcessError:
                    continue

            if not success:
                 print("[Warning] Failed to clone specific tags. Trying default branch...")
                 try:
                    subprocess.check_call(["git", "clone", "--depth", "1", "https://github.com/NVIDIA/TensorRT-LLM.git", clone_dir], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                 except:
                    pass

        examples_path = os.path.join(clone_dir, "examples")
        checked.append(examples_path)
        if os.path.exists(examples_path):
             return examples_path, checked

    except Exception as e:
        print(f"[Warning] Failed to clone examples: {e}")

    return None, checked

def detect_architecture(model_dir):
    config_path = os.path.join(model_dir, "config.json")
    if not os.path.exists(config_path):
        return None
    try:
        with open(config_path, 'r') as f:
            config = json.load(f)
        # Check architectures list
        if "architectures" in config and config["architectures"]:
            return config["architectures"][0]
        # Fallback: check model_type
        if "model_type" in config:
            return config["model_type"]
    except:
        return None
    return None

def get_script_for_arch(arch, examples_dir):
    arch = arch.lower()
    mapping = {
        "llama": "llama", "mistral": "llama", "mixtral": "llama",
        "gpt": "gpt", "gptj": "gptj", "gptneox": "gptneox",
        "chatglm": "chatglm", "qwen": "qwen", "qwen2": "llama",
        "falcon": "falcon", "baichuan": "baichuan", "gemma": "gemma",
        "phi": "phi", "whisper": "whisper",
        "nemotron": "gpt", # Default assumption for older Nemotron
        "nemotronh": "mamba", # Hybrid Mamba
        "mamba": "mamba"
    }

    # 1. Exact mapping (Prioritize longer keys to handle shadowing e.g. nemotronh vs nemotron)
    for k in sorted(mapping.keys(), key=len, reverse=True):
        v = mapping[k]
        if k in arch:
            p = os.path.join(examples_dir, v, "convert_checkpoint.py")
            if os.path.exists(p): return p

    # 2. Directory match
    for d in os.listdir(examples_dir):
        if d in arch:
            p = os.path.join(examples_dir, d, "convert_checkpoint.py")
            if os.path.exists(p): return p

    # 3. Fallback to llama
    p = os.path.join(examples_dir, "llama", "convert_checkpoint.py")
    if os.path.exists(p): return p

    return None

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--model_dir", required=True)
    parser.add_argument("--output_dir", required=True)
    parser.add_argument("--tp_size", default="1")
    parser.add_argument("--pp_size", default="1")
    args, unknown = parser.parse_known_args()

    examples_dir, checked_paths = find_examples_dir()
    if not examples_dir:
        print("[Error] Could not find tensorrt_llm/examples directory.")
        # Debug info
        print(f"[Debug] Checked paths: {checked_paths}")
        print(f"[Debug] Py Version: {sys.version}")
        sys.exit(1)

    arch = detect_architecture(args.model_dir)
    if not arch:
        print("[Warning] Could not detect architecture. Defaulting to Llama.")
        arch = "llama"

    print(f"[Info] Detected Architecture: {arch}")

    script = get_script_for_arch(arch, examples_dir)
    if not script:
        print(f"[Error] No conversion script found for {arch}")
        print(f"[Debug] Examples Directory: {examples_dir}")
        try:
            print(f"[Debug] Contents: {os.listdir(examples_dir)}")
        except:
            pass
        sys.exit(1)

    print(f"[Info] Using conversion script: {script}")

    cmd = [sys.executable, script,
           "--model_dir", args.model_dir,
           "--output_dir", args.output_dir,
           "--tp_size", str(args.tp_size),
           "--pp_size", str(args.pp_size)]

    # Add dtype defaults if needed (many scripts default to float16)
    # If the user supplied extra arguments, we might need them, but here we keep it simple.

    print(f"[Exec] {' '.join(cmd)}")
    subprocess.check_call(cmd)

if __name__ == "__main__":
    main()
PYTHON_SCRIPT

  # Transfer to remote
  ssh "${SSH_OPTS[@]}" "$ip" "cat > $path" < /tmp/convert_heuristic.py
  rm -f /tmp/convert_heuristic.py
}

# Internal: Build TRT Engine (TRT-LLM Mode Only)
function _ensure_trt_engine() {
  if [[ "$USE_TRT_LLM" -eq 0 ]]; then return; fi

  _check_hf_token

  if [[ "$DRY_RUN" -eq 1 ]]; then
      printf "DRY RUN: Checking/Building TRT Engine (Skipping actual build)...\n"
      printf "Would execute: trtllm-build --checkpoint_dir /models/... --output_dir /engines/... \n"
      return
  fi
  local safe_model_id
  safe_model_id=$(echo "$HF_MODEL_ID" | tr '/' '--')

  # Host paths (for mkdir, existence checks, and tar)
  local host_engine_base="${TRT_ENGINE_DIR:-~/engines}"
  local host_model_base="${TRT_MODEL_DIR:-~/models}"
  local host_engine_path="$host_engine_base/$safe_model_id"
  local host_model_path="$host_model_base/$safe_model_id"

  # Container paths (Fixed standard paths inside container)
  local ctr_model_base="/models"
  local ctr_engine_base="/engines"
  local ctr_model_path="$ctr_model_base/$safe_model_id"
  local ctr_engine_path="$ctr_engine_base/$safe_model_id"

  printf "Checking for TRT-LLM Engine at %s (on Head Node)...\n" "$host_engine_path"

  # Check if engine exists on Head
  if ssh "${SSH_OPTS[@]}" "$IP1" "[ -f $host_engine_path/config.json ]"; then
      printf "Engine found. Skipping build.\n"
  else
      printf "Engine not found. Initiating Build Process on Head Node...\n"

      # 1. Download Model
      printf "Downloading model %s from Hugging Face...\n" "$HF_MODEL_ID"
      _remote_mkdir "$IP1" "$host_model_path $host_engine_path"

      # Use the container to download
      # Ensure huggingface-cli is available
      local dl_cmd="if ! command -v huggingface-cli &>/dev/null; then pip install -U huggingface_hub[cli]; fi; huggingface-cli download $HF_MODEL_ID --local-dir $ctr_model_path --local-dir-use-symlinks False"
      ssh "${SSH_OPTS[@]}" "$IP1" \
        "docker run --rm -e HF_TOKEN=$HF_TOKEN -v $host_model_base:$ctr_model_base $IMAGE bash -c '$dl_cmd'"

      # 2. Build Engine
      printf "Building Engine (TP=%s)...\n" "$TP_SIZE"
      local quant_flags=""
      if [[ "$QUANT_OVERRIDE" == "fp8" ]]; then quant_flags="--use_fp8_context_fmha enable"; fi

      # Assuming trtllm-build is in path or we use python script
      # New TRT-LLM uses 'trtllm-build' command
      # Step 2a: Convert Checkpoint (Required for TRT-LLM v0.9+)
      local ckpt_dir="$ctr_engine_path/ckpt"

      # Generate helper script on head node
      _generate_converter_script "$IP1" "$host_engine_path/convert_heuristic.py"

      local convert_cmd="python3 $ctr_engine_path/convert_heuristic.py --model_dir $ctr_model_path --output_dir $ckpt_dir --tp_size $TP_SIZE --pp_size $PP_SIZE"

      # Step 2b: Build Engine
      local build_cmd="trtllm-build --checkpoint_dir $ckpt_dir --output_dir $ctr_engine_path --workers $TP_SIZE --max_batch_size $BATCH_SIZE --max_seq_len $MAX_SEQ_LEN $quant_flags"

      # Chained execution with cleanup
      ssh "${SSH_OPTS[@]}" "$IP1" \
         "docker run --rm --gpus all -v $host_model_base:$ctr_model_base -v $host_engine_base:$ctr_engine_base $IMAGE bash -c '$convert_cmd && $build_cmd && rm -rf $ckpt_dir'"

      printf "Engine build complete.\n"
  fi

  # 3. Distribute Engine (Simple Copy)
  printf "Syncing engine to Worker Node...\n"
  # Using simple tar pipe over SSH (assuming high bandwidth or small engine config, though engines are large)
  # Ideally engines should be on shared storage. If not, we copy.
  _remote_mkdir "$IP2" "$host_engine_path"
  ssh "${SSH_OPTS[@]}" "$IP1" "tar -cf - -C $host_engine_path . | pigz -1" | \
      ssh "${SSH_OPTS[@]}" "$IP2" "pigz -d | tar -xf - -C $host_engine_path"
  printf "Engine synced.\n"
}

# Internal: Cleanup
function _cleanup_existing_containers() {
  printf "[3/5] Cleaning up...\n"
  for ip in "$IP1" "$IP2"; do
    ssh "${SSH_OPTS[@]}" "$ip" "docker rm -f nim-distributed trt-llm-distributed >/dev/null 2>&1 || true"
  done
}

# Prepare ENV vars for network
function _get_nccl_opts() {
  local ifaces="$1"
  local opts="-e NCCL_IB_DISABLE=0 -e NCCL_IB_GID_INDEX=${NCCL_IB_GID_INDEX:-3} -e NCCL_CROSS_NIC=1"

  if [[ -n "$ifaces" ]]; then
    opts="$opts -e NCCL_SOCKET_IFNAME=$ifaces -e GLOO_SOCKET_IFNAME=$ifaces"
    if [[ "$ifaces" == *","* ]]; then
      opts="$opts -e NCCL_MULTI_RAIL=1"
    fi
  fi
  printf "%s" "$opts"
}

# Internal: Launch
function _launch_distributed_service() {
  printf "[4/5] Launching Service...\n"

  # Common Mounts
  local host_engine_base="${TRT_ENGINE_DIR:-~/engines}"
  local host_model_base="${TRT_MODEL_DIR:-~/models}"
  local mounts="-v ~/.cache:/root/.cache -v $host_model_base:/models -v $host_engine_base:/engines"
  local net_args="$PLATFORM_ARG --runtime=nvidia --network host --ipc=host --shm-size=16g --ulimit memlock=-1"
  local container_name="nim-distributed"

  if [[ "$USE_TRT_LLM" -eq 1 ]]; then
      container_name="trt-llm-distributed"
      local safe_model_id=$(echo "$HF_MODEL_ID" | tr '/' '--')
      local engine_path="/engines/$safe_model_id"
      local hf_env=""
      if [[ -n "${HF_TOKEN:-}" ]]; then hf_env="-e HF_TOKEN=$HF_TOKEN"; fi

      # Generate SSH Keys for MPI
      if [[ "$DRY_RUN" -eq 0 ]]; then
          printf "Generating SSH keys for MPI...\n"
          _remote_mkdir "$IP1" "~/.ssh-trt"
          ssh "${SSH_OPTS[@]}" "$IP1" "ssh-keygen -t rsa -f ~/.ssh-trt/id_rsa -N '' && cat ~/.ssh-trt/id_rsa.pub > ~/.ssh-trt/authorized_keys"
          # Copy to worker
          _remote_mkdir "$IP2" "~/.ssh-trt"
          ssh "${SSH_OPTS[@]}" "$IP1" "cat ~/.ssh-trt/id_rsa" | ssh "${SSH_OPTS[@]}" "$IP2" "cat > ~/.ssh-trt/id_rsa && chmod 600 ~/.ssh-trt/id_rsa"
          ssh "${SSH_OPTS[@]}" "$IP1" "cat ~/.ssh-trt/id_rsa.pub" | ssh "${SSH_OPTS[@]}" "$IP2" "cat > ~/.ssh-trt/id_rsa.pub"
          ssh "${SSH_OPTS[@]}" "$IP1" "cat ~/.ssh-trt/authorized_keys" | ssh "${SSH_OPTS[@]}" "$IP2" "cat > ~/.ssh-trt/authorized_keys"
      fi

      mounts="$mounts -v ~/.ssh-trt:/root/.ssh"

      # Commands
      # Worker: Start SSHD (Robust check)
      local ssh_start_cmd="(service ssh start || /usr/sbin/sshd) && sleep infinity"

      local net_opts_2
      net_opts_2=$(_get_nccl_opts "$IFACES2")
      local worker_cmd="docker run -d --name $container_name $net_args $net_opts_2 $hf_env --gpus all $mounts $IMAGE bash -c '$ssh_start_cmd'"

      # Head: Start SSHD then Run MPI
      # We use python3 -m tensorrt_llm.serve if available
      local serve_cmd="mpirun --allow-run-as-root -n $TP_SIZE -H $IP1:1,$IP2:1 python3 -m tensorrt_llm.serve --model_repo $engine_path --port 8000 --host 0.0.0.0"
      local ssh_start_head="(service ssh start || /usr/sbin/sshd) && $serve_cmd"

      local net_opts_1
      net_opts_1=$(_get_nccl_opts "$IFACES1")
      local head_cmd="docker run -d --name $container_name $net_args $net_opts_1 $hf_env --gpus all $mounts $IMAGE bash -c '$ssh_start_head'"

      if [[ "$DRY_RUN" -eq 1 ]]; then
         printf "Worker: %s\nHead: %s\n" "$worker_cmd" "$head_cmd"
         return
      fi

      ssh "${SSH_OPTS[@]}" "$IP2" "$worker_cmd"
      sleep 5
      ssh "${SSH_OPTS[@]}" "$IP1" "$head_cmd"

  else
      # NIM Workflow (Existing)
      local nim_env="-e NGC_API_KEY=$NGC_API_KEY -e NIM_SERVED_MODEL_NAME=$MODEL_ARG -e NIM_MULTI_NODE=1 -e NIM_TENSOR_PARALLEL_SIZE=$TP_SIZE -e NIM_NUM_WORKERS=2 -e MASTER_ADDR=$IP1 -e MASTER_PORT=12345 -e NIM_HTTP_API_PORT=8000"
      # Extra NIM Env for Bindings
      nim_env="$nim_env -e UVICORN_HOST=0.0.0.0 -e HOST=0.0.0.0 -e NIM_SERVER_HTTP_HOST=0.0.0.0"
      if [[ -n "${HF_TOKEN:-}" ]]; then nim_env="$nim_env -e HF_TOKEN=$HF_TOKEN"; fi
      nim_env="$nim_env $EXTRA_NIM_ENV"

      local net_opts_2
      net_opts_2=$(_get_nccl_opts "$IFACES2")
      local worker_cmd="docker run -d --name $container_name $net_args $net_opts_2 --gpus all $mounts $nim_env -e NIM_NODE_RANK=1 $IMAGE"

      local net_opts_1
      net_opts_1=$(_get_nccl_opts "$IFACES1")
      local head_cmd="docker run -d --name $container_name $net_args $net_opts_1 --gpus all $mounts $nim_env -e NIM_NODE_RANK=0 $IMAGE"

       if [[ "$DRY_RUN" -eq 1 ]]; then
         printf "Worker: %s\nHead: %s\n" "$worker_cmd" "$head_cmd"
         return
      fi

      ssh "${SSH_OPTS[@]}" "$IP2" "$worker_cmd"
      sleep 5
      ssh "${SSH_OPTS[@]}" "$IP1" "$head_cmd"
  fi

  # Monitor
  ssh "${SSH_OPTS[@]}" "$IP1" "docker logs -f $container_name" &
}

# Internal: Wait for service
function _wait_for_service() {
  local ip="$1"
  local container_name="nim-distributed"
  if [[ "$USE_TRT_LLM" -eq 1 ]]; then container_name="trt-llm-distributed"; fi

  if [[ "$DRY_RUN" -eq 1 ]]; then return 0; fi

  printf "[5/5] Waiting for service (http://%s:8000)...\n" "$ip"
  for ((i = 1; i <= 60; i++)); do
    local state
    state=$(ssh "${SSH_OPTS[@]}" "$ip" "docker inspect -f '{{.State.Running}}' $container_name" 2>/dev/null || echo "false")
    if [[ "$state" != "true" ]]; then
       printf "Error: Container '%s' crashed or stopped!\n" "$container_name" >&2
       ssh "${SSH_OPTS[@]}" "$ip" "docker logs --tail 20 $container_name" || true
       return 1
    fi
    if ssh "${SSH_OPTS[@]}" "$ip" "curl -s -m 5 http://localhost:8000/v1/health/ready | grep -q 'ready' 2>/dev/null"; then
      printf "Service is ready!\n"
      return 0
    fi
    printf "."
    sleep 10
  done
  return 1
}

# Main
function main() {
  _check_dependencies
  _parse_arguments "$@"

  if [[ "$MODE" == "stop" ]]; then
    _cleanup_existing_containers
    exit 0
  fi

  _validate_ip "$IP1"
  _validate_ip "$IP2"
  _check_api_key

  _configure_model
  _check_vram_requirements "$PARAMS"
  _detect_architecture
  _detect_network
  _verify_connectivity
  _ensure_image_present
  _align_platform_with_image

  _ensure_trt_engine
  _cleanup_existing_containers
  _launch_distributed_service
  _wait_for_service "$IP1"
}

main "$@"
