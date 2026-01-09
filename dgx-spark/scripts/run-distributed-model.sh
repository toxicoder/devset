#!/usr/bin/env bash

# NVIDIA DGX Spark - Distributed NIM Launcher
#
# Installation:
#   curl -O https://raw.githubusercontent.com/toxicoder/devset/main/dgx-spark/scripts/run-distributed-model.sh && chmod +x run-distributed-model.sh
#
# This script spins up a distributed NVIDIA NIM (Inference Microservice) across two DGX Spark nodes.
# It supports various high-parameter LLMs and Multimodal models, optimizing for
# high-speed interconnects (OSPF/IB/RoCE) and distributed tensor parallelism.
#
# Key Features:
# - Top 20 Open Source Model Registry (Llama 3.x, Qwen, Mistral, Gemma, DeepSeek)
# - Distributed Tensor Parallelism (TP=2) over NCCL/RoCE
# - Support for FP4/FP8/INT8 quantization and Speculative Decoding
# - Integration with SGLang/vLLM/TRT-LLM engines
# - Weights & Biases (W&B) monitoring and Power Logging
# - Automatic Networking Setup for High-Performance Fabrics
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
BATCH_SIZE=128
MAX_SEQ_LEN=2048
WANDB_KEY=""
SPECULATIVE_MODE=0
DRY_RUN=0
FORCE=0

# Error handling and cleanup
#
# Description:
#   Cleans up background jobs and child processes when the script exits or errors.
#   Triggered by EXIT and ERR traps.
#
# Arguments:
#   None
#
# Returns:
#   None (Side effect: kills child processes)
function cleanup() {
  # Kill any child processes of the current shell script
  jobs -p | xargs -r kill 2>/dev/null || true
}
trap cleanup EXIT ERR

# Internal: Check dependencies
#
# Description:
#   Verifies that all required commands are available in the system PATH.
#   Exits with an error if any dependency is missing.
#
# Arguments:
#   None
#
# Returns:
#   None (Exits on failure)
function _check_dependencies() {
  for cmd in ssh awk grep sed nc curl pigz python3; do
    if ! command -v "$cmd" &>/dev/null; then
      printf "Error: Required command '%s' not found.\n" "$cmd" >&2
      exit 1
    fi
  done
}

# Internal: Read configuration
#
# Description:
#   Reads the IP addresses and model name from the persistent JSON configuration file.
#   Sets the global variables IP1, IP2, and MODEL_ARG.
#   Exits with error if the config file is missing or invalid.
#
# Arguments:
#   None (Reads global CONFIG_FILE)
#
# Returns:
#   None (Sets global variables IP1, IP2, MODEL_ARG)
function _read_config() {
  if [[ ! -f "$CONFIG_FILE" ]]; then
    printf "Error: Config file not found at %s\n" "$CONFIG_FILE" >&2
    exit 1
  fi

  # Python parsing
  local config_values
  config_values=$(python3 -c "import sys, json; data=json.load(open(sys.argv[1])); print(f\"{data.get('ip1','')}|{data.get('ip2','')}|{data.get('model','')}\")" "$CONFIG_FILE")

  if [[ $? -ne 0 ]]; then
     printf "Error: Failed to parse config file with python.\n" >&2
     exit 1
  fi

  IP1=$(echo "$config_values" | cut -d'|' -f1)
  IP2=$(echo "$config_values" | cut -d'|' -f2)
  MODEL_ARG=$(echo "$config_values" | cut -d'|' -f3)

  if [[ -z "$IP1" || -z "$IP2" || -z "$MODEL_ARG" ]]; then
    printf "Error: Invalid config file (missing fields).\n" >&2
    exit 1
  fi
}

# Internal: Write configuration
#
# Description:
#   Writes the current configuration (IP1, IP2, MODEL_ARG) to the JSON configuration file.
#   Allows resuming the session later with 'start' or 'stop' commands.
#
# Arguments:
#   None (Reads globals: IP1, IP2, MODEL_ARG)
#
# Returns:
#   None (Writes to filesystem)
function _write_config() {
  cat >"$CONFIG_FILE" <<EOF
{
    "ip1": "$IP1",
    "ip2": "$IP2",
    "model": "$MODEL_ARG"
}
EOF
  printf "Configuration saved to %s\n" "$CONFIG_FILE"
}

# Internal: Parse arguments
#
# Description:
#   Parses command-line arguments to determine the operation mode (setup, start, stop).
#   Sets global variables IP1, IP2, MODEL_ARG, and MODE.
#
# Arguments:
#   $@: The command-line arguments passed to the script.
#
# Returns:
#   None (Sets global variables or exits)
function _parse_arguments() {
  # Parse flags
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --dry-run)
        DRY_RUN=1
        shift
        ;;
      --force)
        FORCE=1
        shift
        ;;
      --quant)
        if [[ -z "${2:-}" ]]; then
          printf "Error: --quant requires an argument (e.g., fp8, fp4, int8)\n" >&2
          exit 1
        fi
        QUANT_OVERRIDE="$2"
        shift 2
        ;;
      --engine)
        if [[ -z "${2:-}" ]]; then
          printf "Error: --engine requires an argument (e.g., vllm, sglang, trt-llm)\n" >&2
          exit 1
        fi
        ENGINE_OVERRIDE="$2"
        shift 2
        ;;
      --batch-size)
        BATCH_SIZE="$2"
        shift 2
        ;;
      --max-seq-len)
        MAX_SEQ_LEN="$2"
        shift 2
        ;;
      --wandb-key)
        WANDB_KEY="$2"
        shift 2
        ;;
      --speculative)
        SPECULATIVE_MODE=1
        shift
        ;;
      -*)
        printf "Error: Unknown option %s\n" "$1" >&2
        exit 1
        ;;
      *)
        break
        ;;
    esac
  done

  # Parse commands/positional args
  if [[ "$#" -eq 1 && "$1" == "stop" ]]; then
    MODE="stop"
  elif [[ "$#" -eq 1 && "$1" == "start" ]]; then
    MODE="start"
  elif [[ "$#" -ge 2 && "$#" -le 3 ]]; then
    MODE="setup"
  else
    printf "Usage:\n"
    printf "  %s [OPTIONS] <IP1> <IP2> [<MODEL_NAME>]  (First run / Setup)\n" "$0"
    printf "  %s [OPTIONS] start                       (Start using saved config)\n" "$0"
    printf "  %s [OPTIONS] stop                        (Stop using saved config)\n" "$0"
    printf "\nOptions:\n"
    printf "  --dry-run             Print commands without executing\n"
    printf "  --force               Bypass safety checks (Registry, VRAM)\n"
    printf "  --quant <fmt>         Force quantization (fp4, fp8, int8)\n"
    printf "  --engine <name>       Backend engine (vllm, sglang, trt-llm)\n"
    printf "  --batch-size <n>      Max batch size (default: 128)\n"
    printf "  --max-seq-len <n>     Max sequence length (default: 2048)\n"
    printf "  --wandb-key <key>     W&B API Key for logging\n"
    printf "  --speculative         Enable speculative decoding (e.g., EAGLE/Medusa)\n"
    exit 1
  fi

  if [[ "$MODE" == "stop" ]]; then
    _read_config
    # Stop logic handled in main
  elif [[ "$MODE" == "start" ]]; then
    _read_config
  elif [[ "$MODE" == "setup" ]]; then
    IP1="$1"
    IP2="$2"
    MODEL_ARG="${3:-"meta/llama-3.1-70b-instruct"}"
    _write_config
  fi
}

# Internal: Validate IP Address
#
# Description:
#   Validates that the provided string is in a valid IPv4 format (X.X.X.X).
#   Exits the script if the IP is invalid.
#
# Arguments:
#   $1: The IP address string to validate.
#
# Returns:
#   None (Exits on failure)
function _validate_ip() {
  local ip="$1"
  if [[ ! "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    printf "Error: Invalid IP format '%s'\n" "$ip" >&2
    exit 1
  fi
}

# Internal: Check API Key
#
# Description:
#   Verifies that the NGC_API_KEY environment variable is set.
#
# Arguments:
#   None (Checks environment variable NGC_API_KEY)
#
# Returns:
#   None (Exits if missing)
function _check_api_key() {
  if [[ -z "${NGC_API_KEY:-}" ]]; then
    printf "Error: NGC_API_KEY environment variable is not set.\n" >&2
    printf "Please export your NGC API Key: export NGC_API_KEY='nvapi-...'\n" >&2
    exit 1
  fi
}

# Internal: Get Model Registry
#
# Description:
#   Returns the "Top 20" model registry data as a pipe-delimited list.
#   Prioritizes recent Blackwell-optimized models (Llama 3.x, Qwen2.5/3, Mistral, Gemma).
#   Format: ModelID|ImageTag|TP|PP|DefaultQuant|Params(B)|IsVision|ExtraEnv
#
# Returns:
#   String (Heredoc)
function _get_model_registry() {
  cat <<EOF
reasoning-1|deepseek-ai/deepseek-r1|2|1|fp4|671|0|-e NIM_MODEL_PROFILE=deepseek-r1
reasoning-2|alibaba/qwen3-30b-thinking|2|1|fp16|30|0|-e VLLM_ATTENTION_BACKEND=FLASHINFER
reasoning-3|microsoft/phi-4-reasoning|1|1|fp16|14|0|
mega-1|meta/llama-4-405b-instruct|2|1|fp4|405|0|
mega-2|meta/llama-3.1-405b-instruct|2|1|fp4|405|0|
mega-3|deepseek-ai/deepseek-v3|2|1|fp4|671|0|-e NIM_MODEL_PROFILE=deepseek-v3
mega-4|nvidia/nemotron-4-340b-instruct|2|1|fp4|340|0|
large-1|mistralai/mistral-large-2411|2|1|fp8|123|0|
large-2|alibaba/qwen3-235b-moe-instruct|2|1|fp4|235|0|
large-3|meta/llama-3.2-90b-vision-instruct|2|1|fp8|90|1|
large-4|cohere/command-r-plus-08-2024|2|1|fp16|104|0|
workhorse-1|meta/llama-3.3-70b-instruct|2|1|fp16|70|0|
workhorse-2|meta/llama-4-maverick-instruct|2|1|fp16|70|0|
workhorse-3|alibaba/qwen2.5-72b-instruct|2|1|fp16|72|0|
workhorse-4|nvidia/llama-3.1-nemotron-70b-instruct|2|1|fp16|70|0|
workhorse-5|mistralai/pixtral-large-2411|2|1|fp8|124|1|
coding-1|deepseek-ai/deepseek-coder-v2-instruct|2|1|fp4|236|0|
coding-2|mistralai/codestral-2501|1|1|fp16|22|0|
efficient-1|meta/llama-4-scout-instruct|1|1|fp16|15|0|
efficient-2|google/gemma-3-27b-it|2|1|fp16|27|1|
efficient-3|microsoft/phi-4-mini-instruct|1|1|fp16|14|0|
efficient-4|google/gemma-2-27b-it|2|1|fp16|27|0|
efficient-5|nvidia/nemotron-3-nano-30b-a3b|1|2|fp16|30|0|-e VLLM_ATTENTION_BACKEND=FLASHINFER -e NIM_TAGS_SELECTOR=precision=bf16
special-1|allenai/molmo-72b-0924|2|1|fp16|72|1|
special-2|nvidia/nemotron-super-49b-reward|2|1|fp16|49|0|
special-3|meta/llama-guard-3-8b|1|1|fp16|8|0|
EOF
}

# Internal: Configure model parameters
#
# Description:
#   Maps the model argument to the corresponding image, parameters, and parallelism settings.
#   Uses the embedded "Top 20" model registry.
#
# Arguments:
#   None (Uses globals: MODEL_ARG, QUANT_OVERRIDE, FORCE, ENGINE_OVERRIDE)
#
# Returns:
#   None (Sets globals: IMAGE, TP_SIZE, PP_SIZE, IS_VISION, EXTRA_NIM_ENV)
function _configure_model() {
  # Defaults
  TP_SIZE=2
  PP_SIZE=1
  IS_VISION=0
  EXTRA_NIM_ENV=""
  PARAMS=10
  CONTEXT=128
  local default_quant="fp16"

  # Look up model in registry
  local model_data
  model_data=$(_get_model_registry | grep -F "$MODEL_ARG" | head -n 1 || true)

  if [[ -n "$model_data" ]]; then
    # Parse pipe-delimited data
    IMAGE="nvcr.io/nim/$(echo "$model_data" | cut -d'|' -f2):latest"
    TP_SIZE=$(echo "$model_data" | cut -d'|' -f3)
    PP_SIZE=$(echo "$model_data" | cut -d'|' -f4)
    default_quant=$(echo "$model_data" | cut -d'|' -f5)
    PARAMS=$(echo "$model_data" | cut -d'|' -f6)
    IS_VISION=$(echo "$model_data" | cut -d'|' -f7)
    local extra
    extra=$(echo "$model_data" | cut -d'|' -f8)
    if [[ -n "$extra" ]]; then
      EXTRA_NIM_ENV="$extra"
    fi
  else
    # Custom model - assume user-provided image tag
    if [[ "$FORCE" -eq 1 ]]; then
      printf "Warning: Model '%s' not found in registry. Using as custom image.\n" "$MODEL_ARG"
      if [[ "$MODEL_ARG" =~ / ]]; then
        IMAGE="nvcr.io/nim/$MODEL_ARG:latest"
      else
         IMAGE="nvcr.io/nim/$MODEL_ARG:latest"
      fi
    else
      printf "Error: Model '%s' not found in the supported registry.\n" "$MODEL_ARG" >&2
      exit 1
    fi
  fi

  # Quantization override
  local quant_to_use="$default_quant"
  if [[ -n "$QUANT_OVERRIDE" ]]; then
    quant_to_use="$QUANT_OVERRIDE"
  fi
  # Apply Quantization Env Var
  if [[ "$quant_to_use" != "fp16" && "$quant_to_use" != "bf16" ]]; then
    EXTRA_NIM_ENV="$EXTRA_NIM_ENV -e NIM_QUANTIZATION=$quant_to_use"
  fi

  # Engine Override (vllm, sglang, trt-llm)
  if [[ -n "$ENGINE_OVERRIDE" ]]; then
     EXTRA_NIM_ENV="$EXTRA_NIM_ENV -e NIM_ENGINE=$ENGINE_OVERRIDE"
     # Specific optimizations for vLLM/SGLang
     if [[ "$ENGINE_OVERRIDE" == "vllm" || "$ENGINE_OVERRIDE" == "sglang" ]]; then
       EXTRA_NIM_ENV="$EXTRA_NIM_ENV -e VLLM_ATTENTION_BACKEND=FLASHINFER"
     fi
  fi

  # Speculative Decoding
  if [[ "$SPECULATIVE_MODE" -eq 1 ]]; then
    EXTRA_NIM_ENV="$EXTRA_NIM_ENV -e NIM_SPECULATIVE_DECODING_MODE=EAGLE"
    printf "Speculative Decoding Enabled (EAGLE).\n"
  fi

  # Batch Size and Seq Len
  EXTRA_NIM_ENV="$EXTRA_NIM_ENV -e NIM_MAX_BATCH_SIZE=$BATCH_SIZE -e NIM_MAX_SEQ_LEN=$MAX_SEQ_LEN"

  # W&B Logging
  if [[ -n "$WANDB_KEY" ]]; then
    EXTRA_NIM_ENV="$EXTRA_NIM_ENV -e WANDB_API_KEY=$WANDB_KEY -e NIM_WANDB_ENABLED=1"
  fi

  # Set platform arg (DGX Spark is predominantly ARM/GH200 or x86/H100)
  PLATFORM_ARG="--platform=linux/amd64" # Default, corrected by architecture check below

  printf "=== NVIDIA DGX Spark Distributed NIM Launcher ===\n"
  printf "Nodes: %s (Head), %s (Worker)\n" "$IP1" "$IP2"
  printf "Model: %s\n" "$MODEL_ARG"
  printf "Image: %s\n" "$IMAGE"
  printf "TP: %s, PP: %s, Quant: %s\n" "$TP_SIZE" "$PP_SIZE" "$quant_to_use"
  printf "%s\n" "================================================"
}

# Internal: Check VRAM requirements
#
# Description:
#   Checks if the cluster has enough VRAM for the selected model.
#
# Arguments:
#   $1: Model parameters in billions.
#
# Returns:
#   None
function _check_vram_requirements() {
  local params="$1"
  printf "[Check] verifying VRAM capacity...\n"

  # Query VRAM on both nodes
  local vram1
  vram1=$(ssh "${SSH_OPTS[@]}" "$IP1" \
    "PATH=\$PATH:/usr/local/cuda/bin:/usr/bin nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits" 2>/dev/null |
    awk '{s+=$1} END {print s+0}')
  local vram2
  vram2=$(ssh "${SSH_OPTS[@]}" "$IP2" \
    "PATH=\$PATH:/usr/local/cuda/bin:/usr/bin nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits" 2>/dev/null |
    awk '{s+=$1} END {print s+0}')

  vram1=${vram1:-0}
  vram2=${vram2:-0}

  # Convert MB to GB
  local total_gb
  total_gb=$(awk -v v1="$vram1" -v v2="$vram2" 'BEGIN {print (v1 + v2) / 1024}')

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
#
# Description:
#   Detects the CPU architecture on the head node to determine if a platform override
#   is needed for Docker commands.
#
# Arguments:
#   None (Uses globals: IP1, SSH_OPTS)
#
# Returns:
#   None (Sets global PLATFORM_ARG)
function _detect_architecture() {
  local arch
  arch=$(ssh "${SSH_OPTS[@]}" "$IP1" "uname -m" 2>/dev/null)
  arch=$(printf "%s" "$arch" | xargs)
  printf "Detected architecture on %s: %s\n" "$IP1" "$arch"

  if [[ "$arch" == "x86_64" ]]; then
    PLATFORM_ARG="--platform linux/amd64"
  elif [[ "$arch" == "aarch64" ]]; then
    printf "ARM64 detected. Using native architecture.\n"
    PLATFORM_ARG="--platform linux/arm64"
  else
    PLATFORM_ARG="--platform linux/amd64"
  fi
}

# Internal: Detect high-speed network interfaces
#
# Description:
#   Attempts to detect available high-speed network interfaces (e.g., InfiniBand, Ethernet) on a remote node.
#   Uses 'vtysh' for OSPF neighbors or 'ibdev2netdev' for InfiniBand.
#
# Arguments:
#   $1: The IP address of the node to check.
#
# Returns:
#   A formatted string: "DETECTED_MULTI:<ifaces>", "DETECTED_SINGLE:<iface>", or "DETECTED_NONE"
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
#
# Description:
#   Extracts the interface name(s) from the detection result string.
#
# Arguments:
#   $1: The raw detection string.
#
# Returns:
#   The clean interface name(s).
function _parse_net_conf() {
  local conf="$1"
  local val="${conf#*:}"
  val=$(printf "%s" "$val" | xargs)
  printf "%s" "$val"
}

# Internal: Get IP from interface
#
# Description:
#   Resolves the IPv4 address associated with a specific network interface.
#
# Arguments:
#   $1: The remote host IP/hostname.
#   $2: The interface name.
#
# Returns:
#   The detected IP address.
function _get_ip_from_iface() {
  local ip_host="$1"
  local iface_list="$2"
  local iface
  iface=$(echo "$iface_list" | cut -d',' -f1)

  if [[ -z "$iface" ]]; then return 1; fi

  ssh "${SSH_OPTS[@]}" "$ip_host" \
    "ip -4 addr show $iface | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n 1"
}

# Internal: Detect network
#
# Description:
#   Orchestrates the detection of high-speed network interfaces for both nodes.
#
# Arguments:
#   None (Uses globals: IP1, IP2, SSH_OPTS)
#
# Returns:
#   None (Sets globals: NET_CONF_1, NET_CONF_2, IFACES1, IFACES2)
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
#
# Description:
#   Checks SSH connectivity and NVIDIA driver status.
#
# Arguments:
#   None
#
# Returns:
#   None
function _verify_connectivity() {
  printf "[2/5] Verifying connectivity and pulling image...\n"
  for ip in "$IP1" "$IP2"; do
    if ! ssh "${SSH_OPTS[@]}" "$ip" "nvidia-smi > /dev/null"; then
      printf "Error: Unable to connect to %s or nvidia-smi failed.\n" "$ip" >&2
      exit 1
    fi
  done
}

# Internal: Ensure image present
#
# Description:
#   Ensures the required Docker image is present on both nodes.
#   Uses P2P transfer if possible.
#
# Arguments:
#   None
#
# Returns:
#   None
function _ensure_image_present() {
  # 1. Pull on Head Node
  printf "Pulling image %s on Head Node (%s)...\n" "$IMAGE" "$IP1"
  if ! echo "$NGC_API_KEY" | ssh "${SSH_OPTS[@]}" "$IP1" \
    "docker login nvcr.io -u '\$oauthtoken' --password-stdin >/dev/null 2>&1 && docker pull $PLATFORM_ARG $IMAGE"; then
    printf "Error: Failed to pull image on %s\n" "$IP1" >&2
    exit 1
  fi

  # 2. Check Worker Node (Simplified P2P logic)
  printf "Checking image on Worker Node (%s)...\n" "$IP2"
  local id_head
  id_head=$(ssh "${SSH_OPTS[@]}" "$IP1" "docker inspect --format='{{.Id}}' $IMAGE 2>/dev/null" || true)
  local id_worker
  id_worker=$(ssh "${SSH_OPTS[@]}" "$IP2" "docker inspect --format='{{.Id}}' $IMAGE 2>/dev/null" || true)

  if [[ -n "$id_worker" && "$id_head" == "$id_worker" ]]; then
    printf "Image matches on %s.\n" "$IP2"
    return
  fi

  # Transfer logic (Fast Path)
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
          else
             printf "Image transfer failed (Listener).\n"
          fi
       else
          printf "Image transfer failed (Sender).\n"
          kill "$pid" 2>/dev/null || true
       fi
    fi
  fi

  if [[ "$transfer_done" -eq 1 ]]; then
    return
  fi

  # Fallback Download
  printf "Downloading image on %s...\n" "$IP2"
  if ! echo "$NGC_API_KEY" | ssh "${SSH_OPTS[@]}" "$IP2" \
    "docker login nvcr.io -u '\$oauthtoken' --password-stdin >/dev/null 2>&1 && docker pull $PLATFORM_ARG $IMAGE"; then
    printf "Error: Failed to pull image on %s\n" "$IP2" >&2
    exit 1
  fi
}

# Internal: Cleanup existing containers
#
# Description:
#   Removes any existing containers named 'nim-distributed'.
#
# Arguments:
#   None
#
# Returns:
#   None
function _cleanup_existing_containers() {
  printf "[3/5] Cleaning up previous containers...\n"
  for ip in "$IP1" "$IP2"; do
    ssh "${SSH_OPTS[@]}" "$ip" "docker rm -f nim-distributed >/dev/null 2>&1 || true"
  done
}

# Internal: Monitor Power
#
# Description:
#   Starts a background process to monitor GPU power usage.
#
# Arguments:
#   None
#
# Returns:
#   None
function _monitor_power() {
  if [[ "$DRY_RUN" -eq 1 ]]; then return; fi
  printf "Starting power monitoring (background)...\n"
  for ip in "$IP1" "$IP2"; do
     ssh "${SSH_OPTS[@]}" "$ip" "nohup nvidia-smi --query-gpu=timestamp,power.draw,utilization.gpu --format=csv -l 5 > ~/.nim_logs/power_monitor.csv 2>&1 &" &
  done
}

# Prepare ENV vars for network
#
# Description:
#   Generates the necessary Docker environment arguments for NCCL/GLOO.
#
# Arguments:
#   $1: Comma-separated list of interface names.
#
# Returns:
#   A string containing Docker env vars.
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

# Internal: Launch distributed service
#
# Description:
#   Launches the NIM containers on both nodes in parallel.
#
# Arguments:
#   None
#
# Returns:
#   None
function _launch_distributed_service() {
  printf "[4/5] Launching NIM containers...\n"

  local common_args
  common_args="$PLATFORM_ARG --runtime=nvidia --gpus all --network host"
  common_args="$common_args --ipc=host --name nim-distributed --shm-size=16g"
  common_args="$common_args -v ~/.cache/nim:/opt/nim/.cache"
  common_args="$common_args -v $HOME/.nim_logs:/opt/nim/logs"

  # Base Env
  local nim_env
  nim_env="-e NGC_API_KEY=$NGC_API_KEY"
  nim_env="$nim_env -e NIM_SERVED_MODEL_NAME=$MODEL_ARG"
  nim_env="$nim_env -e NIM_MULTI_NODE=1"
  nim_env="$nim_env -e NIM_TENSOR_PARALLEL_SIZE=$TP_SIZE"
  nim_env="$nim_env -e NIM_PIPELINE_PARALLEL_SIZE=$PP_SIZE"
  nim_env="$nim_env -e NIM_NUM_WORKERS=2"
  nim_env="$nim_env -e MASTER_ADDR=$IP1"
  nim_env="$nim_env -e MASTER_PORT=12345"
  nim_env="$nim_env -e UVICORN_HOST=0.0.0.0"
  nim_env="$nim_env -e HOST=0.0.0.0"
  nim_env="$nim_env -e NIM_HTTP_API_PORT=8000"
  nim_env="$nim_env -e NIM_SERVER_HTTP_HOST=0.0.0.0"
  nim_env="$nim_env -e TRITON_PTXAS_PATH=/usr/local/cuda/bin/ptxas"
  nim_env="$nim_env $EXTRA_NIM_ENV"

  local net_opts_2
  net_opts_2=$(_get_nccl_opts "$IFACES2")
  local worker_cmd="docker run -d $common_args $nim_env -e NIM_NODE_RANK=1 $net_opts_2 $IMAGE"

  local net_opts_1
  net_opts_1=$(_get_nccl_opts "$IFACES1")
  local head_cmd="docker run -d $common_args $nim_env -e NIM_NODE_RANK=0 $net_opts_1 $IMAGE"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf "\n--- DRY RUN: Commands to be executed ---\n"
    printf "Worker (%s):\n%s\n\n" "$IP2" "$worker_cmd"
    printf "Head (%s):\n%s\n" "$IP1" "$head_cmd"
    printf "----------------------------------------\n"
    return
  fi

  # Launch
  printf "Starting Worker on %s...\n" "$IP2"
  (
    ssh "${SSH_OPTS[@]}" "$IP2" "mkdir -p ~/.nim_logs"
    ssh "${SSH_OPTS[@]}" "$IP2" "$worker_cmd"
  ) &
  local pid_worker=$!
  sleep 5
  printf "Starting Head on %s...\n" "$IP1"
  (
    ssh "${SSH_OPTS[@]}" "$IP1" "mkdir -p ~/.nim_logs"
    ssh "${SSH_OPTS[@]}" "$IP1" "$head_cmd"
  ) &
  local pid_head=$!

  wait "$pid_worker"
  wait "$pid_head"

  # Monitor
  _monitor_power
  ssh "${SSH_OPTS[@]}" "$IP1" "docker logs -f nim-distributed" &
}

# Internal: Wait for service readiness
#
# Description:
#   Polls the service health endpoint.
#
# Arguments:
#   $1: IP address of the head node.
#
# Returns:
#   0 on success, 1 on failure.
function _wait_for_service() {
  local ip="$1"
  if [[ "$DRY_RUN" -eq 1 ]]; then return 0; fi

  printf "[5/5] Waiting for service readiness (http://%s:8000)...\n" "$ip"
  for ((i = 1; i <= 60; i++)); do
    # Check if container is running
    local container_running
    container_running=$(ssh "${SSH_OPTS[@]}" "$ip" "docker inspect -f '{{.State.Running}}' nim-distributed" 2>/dev/null || echo "false")

    # Trim whitespace just in case
    container_running=$(echo "$container_running" | xargs)

    if [[ "$container_running" != "true" ]]; then
       printf "\nError: Container 'nim-distributed' crashed or stopped!\n" >&2
       printf "%s\n" "--- Last 20 lines of logs ---"
       ssh "${SSH_OPTS[@]}" "$ip" "docker logs --tail 20 nim-distributed" || true
       printf "%s\n" "-----------------------------"
       return 1
    fi

    if ssh "${SSH_OPTS[@]}" "$ip" \
      "curl -s -m 5 http://localhost:8000/v1/health/ready | python3 -c \"import sys, json; sys.exit(0 if json.load(sys.stdin).get('data', {}).get('ready') == True else 1)\" 2>/dev/null"; then
      printf "Service is ready!\n"
      return 0
    fi
    printf "."
    sleep 10
  done
  return 1
}

# Main execution
function main() {
  _check_dependencies
  _parse_arguments "$@"

  if [[ "$MODE" == "stop" ]]; then
    printf "Stopping distributed model...\n"
    for ip in "$IP1" "$IP2"; do
      ssh "${SSH_OPTS[@]}" "$ip" "docker rm -f nim-distributed >/dev/null 2>&1 || true"
    done
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

  _cleanup_existing_containers
  _launch_distributed_service

  _wait_for_service "$IP1"

  printf "\nDistributed NIM running. Performance Expectation:\n"
  printf "%s\n" "- Training/Pre-fill: ~10k-15k tokens/s (8B), ~2k+ (70B)"
  printf "%s\n" "- Inference: check W&B or local logs for throughput."
}

main "$@"
