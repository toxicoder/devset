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

# ==============================================================================
# Global Configuration (Modified by parse_model_config)
# ==============================================================================
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

# ==============================================================================
# Utilities & Logging
# ==============================================================================

# Internal: Log Info
function log_info() {
  printf "[INFO] %s\n" "$*"
}

# Internal: Log Warning
function log_warn() {
  printf "[WARN] %s\n" "$*" >&2
}

# Internal: Log Error
function log_error() {
  printf "[ERROR] %s\n" "$*" >&2
}

# Internal: Log Step
function log_step() {
  printf "[STEP] %s\n" "$*"
}

# Internal: Cleanup background jobs
function cleanup() {
  jobs -p | xargs -r kill 2>/dev/null || true
}
trap cleanup EXIT ERR

# Internal: Check dependencies
# Arguments: None
# Globals: None
function _check_dependencies() {
  log_info "Checking dependencies..."
  local cmd
  for cmd in ssh awk grep sed nc curl pigz python3; do
    if ! command -v "$cmd" &>/dev/null; then
      log_error "Required command '$cmd' not found."
      exit 1
    fi
  done
  log_info "Dependencies checked."
}

# Internal: Validate IP Address
# Arguments:
#   $1: IP address string
# Globals: None
function _validate_ip() {
  local ip="$1"
  if [[ ! "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    log_error "Invalid IP format '$ip'"
    exit 1
  fi
}

# Internal: Check API Key
# Arguments: None
# Globals: NGC_API_KEY
function _check_api_key() {
  if [[ -z "${NGC_API_KEY:-}" ]]; then
    log_error "NGC_API_KEY environment variable is not set."
    exit 1
  fi
}

# Internal: Check HF Token (for TRT-LLM)
# Arguments: None
# Globals: HF_TOKEN
function _check_hf_token() {
  if [[ -z "${HF_TOKEN:-}" ]]; then
    log_error "HF_TOKEN environment variable is required for TRT-LLM mode to download models."
    log_error "Please export your Hugging Face Token: export HF_TOKEN='hf_...'"
    exit 1
  fi
}

# Internal: Check passwordless sudo on remote nodes
# Arguments: None
# Globals: IP1, IP2, SSH_OPTS
function _check_remote_sudo() {
  local ip
  log_info "Verifying passwordless sudo access..."
  for ip in "$IP1" "$IP2"; do
    if ! ssh "${SSH_OPTS[@]}" "$ip" "sudo -n true 2>/dev/null"; then
      log_error "Passwordless sudo check failed for $ip."
      log_error "Please ensure the user has sudo privileges without password (NOPASSWD in sudoers)."
      if [[ "$FORCE" -eq 1 ]]; then
          log_warn "Force enabled. Proceeding despite sudo check failure..."
      else
          exit 1
      fi
    fi
  done
  log_info "Sudo access verified."
}

# ==============================================================================
# 1. Configuration & Registry Module
# ==============================================================================

# Internal: Get JSON value from config file
# Arguments: $1 key
function json_get() {
    local key="$1"
    # FIXED: Added robust error handling and removed blind error suppression
    # FIXED: Security improvement to pass config file as argument
    if ! python3 -c "import sys, json; print(json.load(open(sys.argv[1])).get(sys.argv[2], ''))" "$CONFIG_FILE" "$key"; then
        log_error "Failed to parse JSON key '$key' from config."
        exit 1
    fi
}

# Internal: Read configuration from file
# Arguments: None
# Globals: CONFIG_FILE, IP1, IP2, MODEL_ARG, ENGINE_OVERRIDE, IMAGE_OVERRIDE
function _read_config() {
  if [[ ! -f "$CONFIG_FILE" ]]; then
    log_error "Config file not found at $CONFIG_FILE"
    exit 1
  fi

  IP1=$(json_get "ip1")
  IP2=$(json_get "ip2")
  MODEL_ARG=$(json_get "model")
  local saved_engine
  saved_engine=$(json_get "engine")
  local saved_image
  saved_image=$(json_get "image")

  if [[ -n "$saved_engine" && -z "$ENGINE_OVERRIDE" ]]; then
    ENGINE_OVERRIDE="$saved_engine"
  fi
  if [[ -n "$saved_image" && -z "$IMAGE_OVERRIDE" ]]; then
    IMAGE_OVERRIDE="$saved_image"
  fi

  if [[ -z "$IP1" || -z "$IP2" || -z "$MODEL_ARG" ]]; then
    log_error "Invalid config file (missing fields)."
    exit 1
  fi
}

# Internal: Write configuration to file
# Arguments: None
# Globals: CONFIG_FILE, IP1, IP2, MODEL_ARG, ENGINE_OVERRIDE, IMAGE_OVERRIDE
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
  log_info "Configuration saved to $CONFIG_FILE"
}

# Internal: Get Model Registry Data
# Format: ModelID|ImageTag|TP|PP|DefaultQuant|Params(B)|IsVision|ExtraEnv|HF_ID
# Arguments: None
# Globals: SCRIPT_DIR
function get_model_registry_data() {
  if [[ -f "$SCRIPT_DIR/models.db" ]]; then
    cat "$SCRIPT_DIR/models.db"
  else
    log_error "Model registry not found at $SCRIPT_DIR/models.db"
    exit 1
  fi
}

# Internal: Parse Model Configuration and set Globals
# Arguments: None
# Globals: MODEL_ARG, TP_SIZE, PP_SIZE, IS_VISION, EXTRA_NIM_ENV, PARAMS, CONTEXT,
#          IMAGE, HF_MODEL_ID, USE_TRT_LLM, ENGINE_OVERRIDE, QUANT_OVERRIDE, BATCH_SIZE, MAX_SEQ_LEN,
#          SPECULATIVE_MODE, WANDB_KEY
function parse_model_config() {
  log_info "Parsing model configuration..."
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
    # FIXED: Ensure case preservation for HF_MODEL_ID
    HF_MODEL_ID=$(printf "%s" "$stripped" | cut -d'/' -f1,2)
    MODEL_ARG="$HF_MODEL_ID"
    log_info "Detected Hugging Face URL. Extracted Model ID: $HF_MODEL_ID"
  fi

  # Look up model
  local model_data
  model_data=$(get_model_registry_data | grep -F -i "$MODEL_ARG" | head -n 1 || true)

  if [[ -n "$model_data" ]]; then
    # Parse data
    local nim_tag
    nim_tag=$(printf "%s" "$model_data" | cut -d'|' -f2)
    IMAGE="nvcr.io/nim/${nim_tag}:latest"
    TP_SIZE=$(printf "%s" "$model_data" | cut -d'|' -f3)
    PP_SIZE=$(printf "%s" "$model_data" | cut -d'|' -f4)
    default_quant=$(printf "%s" "$model_data" | cut -d'|' -f5)
    PARAMS=$(printf "%s" "$model_data" | cut -d'|' -f6)
    IS_VISION=$(printf "%s" "$model_data" | cut -d'|' -f7)
    HF_MODEL_ID=$(printf "%s" "$model_data" | cut -d'|' -f9)
    local extra
    extra=$(printf "%s" "$model_data" | cut -d'|' -f8)
    if [[ -n "$extra" ]]; then EXTRA_NIM_ENV="$extra"; fi
  else
    if [[ -n "$IMAGE_OVERRIDE" ]]; then
      # Image provided by user, assume manual configuration
      log_info "Using custom image override: $IMAGE_OVERRIDE"
      IMAGE="$IMAGE_OVERRIDE"
      if [[ -z "$HF_MODEL_ID" ]]; then HF_MODEL_ID="$MODEL_ARG"; fi
    elif [[ -n "$HF_MODEL_ID" ]]; then
      # Custom HF Model without Image -> Default to TRT-LLM
      log_warn "Custom HF Model detected ($HF_MODEL_ID) without corresponding NIM Image."
      log_info "Defaulting to TensorRT-LLM Engine Build (Native)."
      USE_TRT_LLM=1
      # FIXED: Updated default TRT-LLM image to newer version for Nemotron support
      IMAGE="nvcr.io/nvidia/tensorrt-llm/release:1.2.0rc6"
    elif [[ "$FORCE" -eq 1 ]]; then
      log_warn "Model '$MODEL_ARG' not found in registry. Using as custom image."
      IMAGE="nvcr.io/nim/$MODEL_ARG:latest"
      if [[ -z "$HF_MODEL_ID" ]]; then HF_MODEL_ID="$MODEL_ARG"; fi
    else
      log_error "Model '$MODEL_ARG' not found in the supported registry."
      exit 1
    fi
  fi

  # Sanitize HF_MODEL_ID to prevent filesystem issues
  if [[ -n "$HF_MODEL_ID" ]]; then
    HF_MODEL_ID=$(printf "%s" "$HF_MODEL_ID" | tr -cd '[:alnum:]_./-')
  fi

  # Image Override (Precedence over registry unless TRT-LLM forced)
  if [[ -n "$IMAGE_OVERRIDE" ]]; then
    IMAGE="$IMAGE_OVERRIDE"
  fi

  # Engine Override
  if [[ "$ENGINE_OVERRIDE" == "trt-llm" || "$USE_TRT_LLM" -eq 1 ]]; then
    USE_TRT_LLM=1
    if [[ -z "$IMAGE_OVERRIDE" ]]; then
      # FIXED: Ensure override also defaults to newer image
      IMAGE="nvcr.io/nvidia/tensorrt-llm/release:1.2.0rc6"
    fi
    log_info "Engine Mode: TensorRT-LLM (Container: $IMAGE)"
    if [[ -z "$HF_MODEL_ID" ]]; then
       log_error "HF Model ID not found for $MODEL_ARG. Cannot build engine."
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

  log_info "=== NVIDIA DGX Spark Distributed Launcher ==="
  log_info "Nodes: $IP1 (Head), $IP2 (Worker)"
  log_info "Model: $MODEL_ARG (HF ID: ${HF_MODEL_ID:-N/A})"
  log_info "Image: $IMAGE"
  log_info "TP: $TP_SIZE, PP: $PP_SIZE, Quant: $quant_to_use"
  log_info "Model configuration parsed."
}

# ==============================================================================
# 2. System Discovery Module
# ==============================================================================

# Internal: Get total VRAM on a node in MB
# Arguments:
#   $1: IP address
# Globals: SSH_OPTS
function _get_node_vram() {
  local ip="$1"
  # FIXED: Improved VRAM detection logic for DGX Spark (Unified Memory)
  # DGX Spark/Grace-Hopper often reports "Not Supported" for memory queries via nvidia-smi
  # Fallback to system memory (free -m) if nvidia-smi fails to report capacity.
  local cmd="export PATH=/usr/local/bin:/usr/bin:/usr/local/nvidia/bin:/usr/local/cuda/bin:/usr/sbin:/sbin:/bin:\$PATH; \
             if command -v nvidia-smi &>/dev/null; then \
                mem=\$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>&1); \
                if [[ \"\$mem\" == *\"Not Supported\"* || -z \"\$mem\" ]]; then \
                    free -m | grep Mem | awk '{print \$2}'; \
                else \
                    echo \"\$mem\"; \
                fi; \
             else \
                echo '0'; \
             fi"

  local out
  # FIXED: Capture only stdout to avoid parsing SSH error messages as VRAM
  if ! out=$(ssh "${SSH_OPTS[@]}" "$ip" "$cmd"); then
      log_warn "SSH to $ip failed during VRAM check."
      echo "0"
      return
  fi

  # FIXED: Parse output to extract only numbers, handling multi-GPU output by summing
  # Refactored to use tr instead of sed to strictly match memory instructions and robustness
  local total_mem
  total_mem=$(printf "%s" "$out" | tr -d '\r' | grep -E '^[0-9]+$' | awk '{s+=$1} END {print s+0}')

  if [[ -z "$total_mem" || "$total_mem" -eq 0 ]]; then
      log_warn "Could not detect VRAM on $ip (nvidia-smi failed or returned 0). Assuming 0."
      echo "0"
  else
      echo "$total_mem"
  fi
}

# Internal: Get total cluster VRAM in GB
# Arguments:
#   $1: IP1
#   $2: IP2
# Returns: Total VRAM in GB (float) via stdout
function get_total_cluster_vram() {
  local ip1="$1"
  local ip2="$2"
  local vram1 vram2

  vram1=$(_get_node_vram "$ip1")
  vram2=$(_get_node_vram "$ip2")

  awk -v v1="${vram1:-0}" -v v2="${vram2:-0}" 'BEGIN {print (v1 + v2) / 1024}'
}

# Internal: Check if cluster satisfies VRAM requirements
# Arguments:
#   $1: Model parameters (billions)
#   $2: IP1
#   $3: IP2
#   $4: Force flag
#   $5: Quant override
#   $6: Extra env
function check_vram_requirements() {
  local params="$1"
  local ip1="$2"
  local ip2="$3"
  local force="$4"
  local quant_override="$5"
  local extra_env="$6"

  log_info "Verifying VRAM capacity..."

  local total_gb
  total_gb=$(get_total_cluster_vram "$ip1" "$ip2")

  # FIXED: Graceful fallback for failed VRAM detection
  if awk -v t="$total_gb" 'BEGIN {exit !(t <= 0)}'; then
     log_warn "VRAM detection failed or total is 0 GB."
     if [[ "$force" -eq 1 ]]; then
         log_warn "Force enabled, proceeding..."
         return 0
     else
         log_error "VRAM detection failed. Use --force to override."
         exit 1
     fi
  fi
  # Using printf for formatted float output, wrapped in log_info
  log_info "$(printf "Total Cluster VRAM Detected: %.2f GB" "$total_gb")"

  local required_gb=$(( params * 2 ))

  if [[ "$quant_override" == "fp8" || "$extra_env" == *"fp8"* ]]; then required_gb=$(( required_gb / 2 )); fi
  if [[ "$quant_override" == "fp4" || "$extra_env" == *"fp4"* ]]; then required_gb=$(( required_gb / 4 )); fi

  # Add 20GB buffer for context/overhead
  required_gb=$(( required_gb + 20 ))

  if awk -v r="$required_gb" -v t="$total_gb" 'BEGIN {exit !(r > t)}'; then
    # Using printf for formatted float output
    local msg
    msg=$(printf "Estimated VRAM required (~%d GB) exceeds detected VRAM (%.2f GB)." "$required_gb" "$total_gb")
    log_warn "CRITICAL WARNING: $msg"

    if [[ "$force" -eq 1 ]]; then
       log_warn "Force enabled. Proceeding despite memory risks..."
    else
       log_error "Aborting to prevent potential crash. Use --force to override."
       exit 1
    fi
  else
    local msg
    msg=$(printf "VRAM Check Passed (Est. %d GB < %.2f GB)" "$required_gb" "$total_gb")
    log_info "$msg"
  fi
}

# Internal: Detect architecture of the head node
# Arguments:
#   $1: IP address
# Returns: Platform argument string (e.g. --platform linux/amd64)
function _detect_architecture() {
  local ip="$1"
  local arch
  arch=$(ssh "${SSH_OPTS[@]}" "$ip" "uname -m" 2>/dev/null | xargs)
  if [[ "$arch" == "x86_64" ]]; then echo "--platform linux/amd64";
  elif [[ "$arch" == "aarch64" ]]; then echo "--platform linux/arm64"; fi
}

# Internal: Detect high-speed network interfaces for a given IP
# Arguments:
#   $1: IP address
# Returns: Comma-separated interface list or "DETECTED_NONE"
function detect_high_speed_iface() {
  local ip="$1"
  # OSPF Autodetection
  local ospf_neighbors
  if ospf_neighbors=$(ssh "${SSH_OPTS[@]}" "$ip" \
    "sudo vtysh -c 'show ip ospf neighbor' 2>/dev/null"); then
    local ifaces
    ifaces=$(printf "%s" "$ospf_neighbors" | grep "Full" | awk '{print $6}' | sort | uniq | tr '\n' ',' | sed 's/,$//' || true)
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
  # Updated to capture all Up interfaces, comma-separated (for multi-rail)
  iface=$(ssh "${SSH_OPTS[@]}" "$ip" \
    "ibdev2netdev 2>/dev/null | grep 'Up' | awk -F'==> ' '{print \$2}' | awk '{print \$1}' | tr '\n' ',' | sed 's/,\$//'")

  if [[ -n "$iface" ]]; then
    if [[ "$iface" == *","* ]]; then
      printf "DETECTED_MULTI: %s" "$iface"
    else
      printf "DETECTED_SINGLE: %s" "$iface"
    fi
  else
    printf "DETECTED_NONE"
  fi
}

# Internal: Orchestrate network detection
# Arguments: None
# Globals: IP1, IP2
# Side Effects: Sets NET_CONF_1, NET_CONF_2, IFACES1, IFACES2
function detect_network_config() {
  log_step "[1/5] Detecting high-speed network interfaces..."

  # Pre-flight check
  if ssh "${SSH_OPTS[@]}" "$IP1" "command -v ib_write_bw >/dev/null"; then
    log_info "ib_write_bw detected (RoCE/IB support confirmed)."
  fi

  # Setting globals directly as this is an orchestrator function
  NET_CONF_1=$(detect_high_speed_iface "$IP1")
  NET_CONF_2=$(detect_high_speed_iface "$IP2")

  # Helper to parse "DETECTED_X: val"
  local parse_val
  parse_val() {
      local val="${1#*:}"
      printf "%s" "$val" | xargs
  }

  IFACES1=$(parse_val "$NET_CONF_1")
  IFACES2=$(parse_val "$NET_CONF_2")

  log_info "Node 1 Interfaces: $IFACES1"
  log_info "Node 2 Interfaces: $IFACES2"

  if [[ -z "$IFACES1" || -z "$IFACES2" || "$NET_CONF_1" == *"DETECTED_NONE"* ]]; then
    log_warn "No high-speed interfaces detected. Defaulting to standard networking."
    log_info "Recommendation: Check netplan config for static IPs on high-speed interfaces."
  fi
  log_info "Network detection complete."
}

# Internal: Get IP from interface
# Arguments:
#   $1: Host IP
#   $2: Interface list (comma separated)
function _get_ip_from_iface() {
  local ip_host="$1"
  local iface_list="$2"
  local iface
  iface=$(printf "%s" "$iface_list" | cut -d',' -f1)

  if [[ -z "$iface" ]]; then return 1; fi

  ssh "${SSH_OPTS[@]}" "$ip_host" \
    "ip -4 addr show $iface | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n 1"
}

# ==============================================================================
# 3. Image Management Module
# ==============================================================================

# Internal: Standard Docker Pull
# Arguments:
#   $1: Node IP
#   $2: Image Name
function pull_image() {
  local ip="$1"
  local image="$2"

  log_info "Initiating docker pull on $ip..."
  # Use Heredoc with local expansion for the key (safe as it goes to stdin of ssh -> bash)
  if ! ssh "${SSH_OPTS[@]}" "$ip" "bash -s" <<EOF
    echo "$NGC_API_KEY" | docker login nvcr.io -u '\$oauthtoken' --password-stdin >/dev/null 2>&1
    if ! docker pull $PLATFORM_ARG "$image"; then
       echo "Error: Failed to pull image $image" >&2
       exit 1
    fi
EOF
  then
    log_error "Failed to pull image on $ip"
    return 1
  fi
  log_info "Docker pull complete on $ip."
}

# Internal: Transfer Docker image P2P
# Arguments:
#   $1: Source IP
#   $2: Target IP
#   $3: Image Name
#   $4: High Speed IP on Target (optional)
function transfer_docker_image_p2p() {
  local src_ip="$1"
  local tgt_ip="$2"
  local image="$3"
  local fast_ip_tgt="$4"

  if [[ -z "$fast_ip_tgt" ]]; then return 1; fi

  log_info "Using High-Speed P2P Transfer to $tgt_ip ($fast_ip_tgt)..."
  # Start listener
  ( ssh "${SSH_OPTS[@]}" "$tgt_ip" "nc -l -p 12346 | pigz -d | docker load" ) &
  local pid=$!

  # Poll for readiness
  printf "Waiting for receiver on %s:12346..." "$fast_ip_tgt"
  local ready=0
  for i in {1..30}; do
      if ssh "${SSH_OPTS[@]}" "$src_ip" "nc -z -w 1 $fast_ip_tgt 12346 2>/dev/null"; then
          ready=1
          printf " Ready.\n"
          break
      fi
      printf "."
      sleep 1
  done

  if [[ "$ready" -eq 0 ]]; then
      # Need newline after dots
      printf "\n"
      log_error "Receiver timed out."
      kill "$pid" 2>/dev/null
      return 1
  fi

  # Start sender
  if ssh "${SSH_OPTS[@]}" "$src_ip" "docker save $image | pigz -c -1 | nc -w 60 -q 1 $fast_ip_tgt 12346"; then
      if wait "$pid"; then
          log_info "Image transfer successful."
          return 0
      fi
  fi
  return 1
}

# Internal: Orchestrate Image Presence
# Arguments:
#   $1: IP1
#   $2: IP2
#   $3: Image
#   $4: Ifaces2
function ensure_image_present() {
  local ip1="$1"
  local ip2="$2"
  local image="$3"
  local ifaces2="$4"

  log_info "Pulling image $image on Head Node ($ip1)..."
  pull_image "$ip1" "$image"

  # Worker check
  log_info "Checking image on Worker Node ($ip2)..."
  local id_head
  id_head=$(ssh "${SSH_OPTS[@]}" "$ip1" "docker inspect --format='{{.Id}}' $image 2>/dev/null" || true)
  local id_worker
  id_worker=$(ssh "${SSH_OPTS[@]}" "$ip2" "docker inspect --format='{{.Id}}' $image 2>/dev/null" || true)

  if [[ -n "$id_worker" && "$id_head" == "$id_worker" ]]; then
    log_info "Image matches on $ip2."
    return
  fi

  # P2P Transfer attempt
  local transfer_done=0
  if [[ -n "$ifaces2" ]]; then
    local fast_ip2
    fast_ip2=$(_get_ip_from_iface "$ip2" "$ifaces2")
    if transfer_docker_image_p2p "$ip1" "$ip2" "$image" "$fast_ip2"; then
       transfer_done=1
    fi
  fi

  if [[ "$transfer_done" -eq 1 ]]; then return; fi

  # Fallback
  log_info "Downloading image on $ip2..."
  pull_image "$ip2" "$image"
  log_info "Image verification complete."
}

# Internal: Align platform with image
# Arguments:
#   $1: IP
#   $2: Image
#   $3: Platform Arg
function _align_platform_with_image() {
  log_info "Verifying platform alignment..."
  local ip="$1"
  local image="$2"
  local platform_arg="$3"

  local img_arch
  img_arch=$(ssh "${SSH_OPTS[@]}" "$ip" "docker inspect -f '{{.Architecture}}' $image" 2>/dev/null | xargs)

  if [[ -n "$img_arch" ]]; then
     if [[ "$img_arch" == "amd64" && "$platform_arg" == *"--platform linux/arm64"* ]]; then
        log_error "Image architecture ($img_arch) is incompatible with Host architecture (arm64)."
        exit 1
     elif [[ "$img_arch" == "arm64" && "$platform_arg" == *"--platform linux/amd64"* ]]; then
        log_error "Image architecture ($img_arch) is incompatible with Host architecture (x86_64)."
        exit 1
     fi
  fi
  log_info "Platform alignment verified."
}

# ==============================================================================
# 4. TensorRT-LLM Builder Module
# ==============================================================================

# Internal: Robust mkdir on remote host
# Arguments: $1 ip, $2 dirs
function _remote_mkdir() {
  local ip="$1"
  local dirs="$2"
  local out
  if ! out=$(ssh "${SSH_OPTS[@]}" "$ip" "mkdir -p $dirs" 2>&1); then
     log_warn "mkdir failed on $ip. Output: $out."
     # Try sudo non-interactive
     if ssh "${SSH_OPTS[@]}" "$ip" "sudo -n true" 2>/dev/null; then
         log_info "Sudo access confirmed. Fixing permissions..."
         ssh "${SSH_OPTS[@]}" "$ip" "sudo mkdir -p $dirs && sudo chown -R \$(id -u):\$(id -g) $dirs"
     else
         log_info "Sudo failed. Attempting Docker-based permission fix..."
         local fix_image="${IMAGE:-alpine}"
         local remote_script="
           export PATH=\$PATH:/usr/bin:/usr/local/bin
           dirs='$dirs'
           uid=\$(id -u)
           gid=\$(id -g)
           img='$fix_image'
           for d in \$dirs; do
             if [[ \"\$d\" == \"~\"* ]]; then d=\"\${HOME}\${d:1}\"; fi
             target=\"\$d\"
             if [ ! -d \"\$target\" ]; then target=\$(dirname \"\$target\"); fi
             if [ -d \"\$target\" ]; then
                 mount_dir=\$(dirname \"\$target\")
                 base_name=\$(basename \"\$target\")
                 echo \"Fixing permissions on \$target via Docker...\"
                 docker run --rm -v \"\$mount_dir\":/work \"\$img\" chown -R \"\$uid:\$gid\" \"/work/\$base_name\" 2>/dev/null || true
             fi
           done
         "
         if printf "%s" "$remote_script" | ssh "${SSH_OPTS[@]}" "$ip" "bash -s"; then
             if ssh "${SSH_OPTS[@]}" "$ip" "mkdir -p $dirs"; then
                 log_info "Permissions fixed via Docker. mkdir succeeded."
                 return 0
             fi
         fi
         log_error "Cannot create directories and passwordless sudo is not available."
         exit 1
     fi
  fi
}


# Internal: Download HF Model
# Arguments: $1 ip, $2 model_id, $3 container_model_path, $4 host_model_base, $5 container_model_base
function download_hf_model() {
  local ip="$1"
  local model_id="$2"
  local ctr_path="$3"
  local host_base="$4"
  local ctr_base="$5"

  log_info "Downloading model $model_id on $ip..."
  ssh "${SSH_OPTS[@]}" "$ip" "bash -s" <<EOF
    # Inner script for Docker
    read -r -d '' DOCKER_SCRIPT <<'INNER'
if ! command -v hf &>/dev/null; then pip install -U "huggingface_hub[cli]"; fi
for i in {1..3}; do
    if hf download $model_id --local-dir $ctr_path; then exit 0; fi
    echo "Download failed, retrying..." >&2
    sleep 5
done
exit 1
INNER

    # Expand tilde in host path if present (Docker requires absolute path)
    HB="$host_base"
    if [[ "\$HB" == "~"* ]]; then HB="\${HOME}\${HB:1}"; fi

    docker run --rm --gpus all \\
        -e HF_TOKEN='$HF_TOKEN' \\
        -v "\$HB":'$ctr_base' \\
        '$IMAGE' \\
        bash -c "\$DOCKER_SCRIPT"
EOF
  log_info "Model download complete."
}

# Internal: Patch model config for compatibility (e.g. Nemotron)
function _patch_model_config() {
  local ip="$1"
  local ctr_model_path="$2"
  local host_model_base="$3"
  local ctr_model_base="$4"

  log_info "Patching model config on $ip if needed..."

  # Use Heredoc for robust remote execution and variable handling
  ssh "${SSH_OPTS[@]}" "$ip" "bash -s" <<EOF
    # Expand tilde in host path
    HMB="$host_model_base"
    if [[ "\$HMB" == "~"* ]]; then HMB="\${HOME}\${HMB:1}"; fi

    # Python script to patch config
    cat > /tmp/patch_config.py <<'PYTHON'
import json, os, sys

try:
    config_path = '$ctr_model_path/config.json'
    if not os.path.exists(config_path):
        print(f"Config file not found at {config_path}")
        sys.exit(0)

    print(f"Reading config from {config_path}")
    with open(config_path, 'r') as f:
        config = json.load(f)

    changed = False

    # Nemotron / Mamba fixes
    if 'hidden_act' not in config:
        config['hidden_act'] = 'silu'
        changed = True
        print("Added hidden_act=silu")

    if 'rms_norm' not in config:
        config['rms_norm'] = True
        changed = True
        print("Added rms_norm=True")

    if 'ssm_state_size' in config and 'state_size' not in config:
        config['state_size'] = config['ssm_state_size']
        changed = True
        print("Mapped ssm_state_size to state_size")

    if 'norm_epsilon' in config and 'rms_norm_eps' not in config:
        config['rms_norm_eps'] = config['norm_epsilon']
        changed = True
        print("Mapped norm_epsilon to rms_norm_eps")

    # Sanitize MoE config to prevent ValueError in LLaMAConfig
    # Support aliases (e.g. DeepSeek uses n_routed_experts)
    try:
        moe_num_experts = config.get('num_experts', 0) or config.get('moe_num_experts', 0) or config.get('n_routed_experts', 0)
        moe_top_k = config.get('top_k', 0) or config.get('num_experts_per_tok', 0) or config.get('moe_top_k', 0)

        nk = int(moe_num_experts or 0)
        tk = int(moe_top_k or 0)
    except:
        nk, tk = 0, 0

    if nk > 0 and tk == 0:
        # MoE enabled but top_k missing -> Invalid state, disable MoE
        config['num_experts'] = 0
        if 'n_routed_experts' in config: config['n_routed_experts'] = 0
        if 'moe_num_experts' in config: config['moe_num_experts'] = 0
        changed = True
        print(f"Reset num_experts (and aliases) to 0 (was {nk}) to fix MoE validation error (missing top_k)")
    elif nk == 0 and tk > 0:
        # top_k enabled but num_experts missing -> Invalid state, disable top_k
        config['top_k'] = 0
        if 'num_experts_per_tok' in config: config['num_experts_per_tok'] = 0
        if 'moe_top_k' in config: config['moe_top_k'] = 0
        changed = True
        print(f"Reset top_k (and aliases) to 0 (was {tk}) to fix MoE validation error (missing num_experts)")
    elif nk > 0 and tk > 0:
        # Valid MoE state, ensure standard keys exist for TRT-LLM
        if 'num_experts' not in config:
             config['num_experts'] = nk
             changed = True
             print("Explicitly set num_experts from alias")
        if 'top_k' not in config:
             config['top_k'] = tk
             changed = True
             print("Explicitly set top_k from alias")

    mt = config.get('model_type', '').lower()
    if 'nemotron' in mt and mt != 'llama':
        config['model_type'] = 'llama'
        # Remove auto_map to force using standard LlamaConfig
        if 'auto_map' in config:
            del config['auto_map']
            print("Removed auto_map to force LlamaConfig")
        changed = True
        print(f"Changed model_type from {mt} to llama")

    if changed:
        with open(config_path, 'w') as f:
            json.dump(config, f, indent=2)
        print("Config patched successfully.")
    else:
        print("No patching required.")

except Exception as e:
    print(f"Error patching config: {e}")
    sys.exit(1)
PYTHON

    # Run docker to execute the patch script
    # We mount the host model base to the container model base
    docker run --rm \\
        -v "\$HMB":'$ctr_model_base' \\
        -v /tmp/patch_config.py:/tmp/patch_config.py \\
        '$IMAGE' \\
        python3 /tmp/patch_config.py

    rm -f /tmp/patch_config.py
EOF
}

# Internal: Compile TRT Engine
# Arguments: $1 ip, $2 ctr_engine_path, $3 ctr_model_path, $4 host_engine_base, $5 host_model_base, $6 ctr_engine_base, $7 ctr_model_base, $8 host_engine_path
function compile_trt_engine() {
  local ip="$1"
  local ctr_engine_path="$2"
  local ctr_model_path="$3"
  local host_engine_base="$4"

  log_info "Compiling TRT Engine on $ip..."
  local host_model_base="$5"
  local ctr_engine_base="$6"
  local ctr_model_base="$7"
  local host_engine_path="$8"

  # FIXED: Check for pre-quantized model (e.g. NVFP4) to skip conversion
  # We check config.json in the container for quantization_config format
  local quant_status=""
  # Use Python for robust JSON parsing via Heredoc to avoid quoting issues
  if quant_status=$(ssh "${SSH_OPTS[@]}" "$ip" "bash -s" <<EOF 2>/dev/null
    docker run --rm -v $host_model_base:$ctr_model_base $IMAGE python3 -c "
import json, sys, os
try:
    path = '$ctr_model_path/config.json'
    if os.path.exists(path):
        with open(path) as f:
            data = json.load(f)
            fmt = data.get('format')
            if not fmt and isinstance(data.get('quantization_config'), dict):
                fmt = data.get('quantization_config').get('format')
            if fmt == 'nvfp4-pack-quantized':
                print('DETECTED_NVFP4')
except Exception as e:
    sys.stderr.write(str(e))
"
EOF
  ); then
      :
  fi

  # Removed NVFP4 shortcut to ensure consistent conversion path with correct arguments and pynvml fixes.
  if [[ "$quant_status" == *"DETECTED_NVFP4"* ]]; then
       log_info "Detected pre-quantized NVFP4 model. Proceeding with standard conversion pipeline."
  fi

  # Standard flow for unquantized models
  local quant_flags=""
  if [[ "$QUANT_OVERRIDE" == "fp8" ]]; then quant_flags="--use_fp8_context_fmha enable"; fi

  local ckpt_dir="$ctr_engine_path/ckpt"

  # Patch config if needed (e.g. Nemotron/Mamba fixes)
  _patch_model_config "$ip" "$ctr_model_path" "$host_model_base" "$ctr_model_base"

  # Use CLI tools directly
  if ! ssh "${SSH_OPTS[@]}" "$ip" "bash -s" <<EOF
    set -e
    # Expand tilde in host paths if present
    HMB="$host_model_base"
    if [[ "\$HMB" == "~"* ]]; then HMB="\${HOME}\${HMB:1}"; fi
    HEB="$host_engine_base"
    if [[ "\$HEB" == "~"* ]]; then HEB="\${HOME}\${HEB:1}"; fi

    # Define Python Conversion Script
    # Use mktemp on remote host to store the script securely
    REMOTE_SCRIPT=\$(mktemp)

    # Ensure cleanup on exit
    trap 'rm -f "\$REMOTE_SCRIPT"' EXIT

    cat > "\$REMOTE_SCRIPT" <<'PYTHON'
import sys, os, json, runpy, shutil

def get_arch(model_dir):
    try:
        with open(os.path.join(model_dir, 'config.json')) as f:
            c = json.load(f)
        # Check architectures list or architectura field
        a = c.get('architectures', [''])[0].lower()
        if not a: a = c.get('architecture', '').lower()

        if 'qwen' in a: return 'qwen'
        if 'mistral' in a: return 'llama' # Mistral often uses Llama script structure
        if 'mixtral' in a: return 'mixtral' # Or llama/mistral depending on version
        if 'gemma' in a: return 'gemma'
        if 'phi' in a: return 'phi'
        if 'nemotron' in a: return 'llama' # Fallback for Nemotron
        return 'llama' # Default
    except:
        return 'llama'

def find_script(arch):
    # Search strategies
    # 1. Direct mapped check
    mapping = {
        "llama": ["llama"],
        "mistral": ["llama", "mistral"],
        "qwen": ["qwen"],
        "gemma": ["gemma"],
        "mixtral": ["mixtral", "llama"],
        "phi": ["phi"]
    }
    targets = mapping.get(arch, [arch])

    # Common base paths in TRT-LLM containers
    bases = ["/app/tensorrt_llm/examples", "/app/examples", "/usr/local/lib/python3.10/dist-packages/tensorrt_llm/examples", "/usr/local/lib/python3.12/dist-packages/tensorrt_llm/examples"]

    candidates = []

    # Heuristic 1: Known paths
    for base in bases:
        if not os.path.exists(base): continue
        for target in targets:
             p = os.path.join(base, target, "convert_checkpoint.py")
             if os.path.exists(p): return p

    # Heuristic 2: Recursive search if not found
    print(f"[INFO] Standard paths failed. Searching recursively for convert_checkpoint.py...", file=sys.stderr)
    for base in ["/app", "/usr/local"]:
        for root, dirs, files in os.walk(base):
            if "convert_checkpoint.py" in files:
                full_path = os.path.join(root, "convert_checkpoint.py")
                # Check if parent dir matches arch
                parent = os.path.basename(root).lower()
                if parent in targets:
                    return full_path
                candidates.append(full_path)

    # Fallback to llama if available
    for c in candidates:
        if "llama" in c: return c

    return candidates[0] if candidates else None

try:
    # Attempt standard command (Unified Workflow)
    # Note: run_module handles sys.argv but we need to ensure the module is importable
    import tensorrt_llm.commands.convert_checkpoint
    runpy.run_module("tensorrt_llm.commands.convert_checkpoint", run_name="__main__", alter_sys=True)
except (ImportError, ModuleNotFoundError):
    print("[WARN] Standard convert_checkpoint module not found. Attempting fallback...", file=sys.stderr)

    # Extract model_dir from args
    model_dir = "."
    if "--model_dir" in sys.argv:
        try:
            model_dir = sys.argv[sys.argv.index("--model_dir") + 1]
        except ValueError:
            pass

    arch = get_arch(model_dir)
    script = find_script(arch)

    if script:
        print(f"[INFO] Using fallback script: {script}", file=sys.stderr)
        runpy.run_path(script, run_name="__main__")
    else:
        print(f"[ERROR] No conversion script found for {arch}.", file=sys.stderr)
        sys.exit(1)
PYTHON

    docker run --rm --gpus all \\
        -v "\$REMOTE_SCRIPT":/tmp/convert_script.py \\
        -v "\$HMB":'$ctr_model_base' \\
        -v "\$HEB":'$ctr_engine_base' \\
        '$IMAGE' \\
        bash -c "
# Fix pynvml warning
pip uninstall -y pynvml >/dev/null 2>&1 || true
pip install -q nvidia-ml-py >/dev/null 2>&1 || true

# Execute Python Conversion Logic
python3 /tmp/convert_script.py \\
  --model_dir '$ctr_model_path' \\
  --output_dir '$ckpt_dir' \\
  --tp_size '$TP_SIZE' \\
  --pp_size '$PP_SIZE' && \\
trtllm-build \\
  --checkpoint_dir '$ckpt_dir' \\
  --output_dir '$ctr_engine_path' \\
  --workers '$TP_SIZE' \\
  --max_batch_size '$BATCH_SIZE' \\
  --max_seq_len '$MAX_SEQ_LEN' \\
  $quant_flags && \\
rm -rf '$ckpt_dir'
"
EOF
  then
      log_error "TensorRT Engine Compilation Failed on $ip."
      exit 1
  fi
  log_info "Compilation complete."
}

# Internal: Sync Engine to Worker
# Arguments: $1 source_ip, $2 target_ip, $3 host_engine_path
function sync_engine_to_worker() {
  local src_ip="$1"
  local tgt_ip="$2"
  local path="$3"

  _remote_mkdir "$tgt_ip" "$path"
  ssh "${SSH_OPTS[@]}" "$src_ip" "tar -cf - -C $path . | pigz -1" | \
      ssh "${SSH_OPTS[@]}" "$tgt_ip" "pigz -d | tar -xf - -C $path"
}

# Internal: Orchestrate TRT Engine Build
# Arguments:
#   $1: use_trt_llm (0/1)
#   $2: hf_model_id
#   $3: ip1
#   $4: ip2
#   $5: image
#   $6: dry_run (0/1)
#   $7: trt_engine_dir
#   $8: trt_model_dir
function ensure_trt_engine() {
  local use_trt_llm="$1"
  local hf_model_id="$2"
  local ip1="$3"
  local ip2="$4"
  local image="$5"
  local dry_run="$6"
  local trt_engine_dir="$7"
  local trt_model_dir="$8"

  if [[ "$use_trt_llm" -eq 0 ]]; then return; fi
  _check_hf_token

  if [[ "$dry_run" -eq 1 ]]; then
      log_info "DRY RUN: Checking/Building TRT Engine..."
      return
  fi
  set -x
  local safe_model_id
  safe_model_id=$(printf "%s" "$hf_model_id" | tr '/' '--')

  local host_engine_base="${trt_engine_dir:-~/engines}"
  local host_model_base="${trt_model_dir:-~/models}"
  local host_engine_path="$host_engine_base/$safe_model_id"
  local host_model_path="$host_model_base/$safe_model_id"

  local ctr_model_base="/models"
  local ctr_engine_base="/engines"
  local ctr_model_path="$ctr_model_base/$safe_model_id"
  local ctr_engine_path="$ctr_engine_base/$safe_model_id"

  log_info "Checking for TRT-LLM Engine at $host_engine_path (on Head Node)..."

  if ssh "${SSH_OPTS[@]}" "$ip1" "[ -f $host_engine_path/config.json ]"; then
      log_info "Engine found. Skipping build."
  else
      log_info "Engine not found. Initiating Build Process on Head Node..."
      log_info "Downloading model $hf_model_id from Hugging Face..."
      _remote_mkdir "$ip1" "$host_model_path $host_engine_path"

      download_hf_model "$ip1" "$hf_model_id" "$ctr_model_path" "$host_model_base" "$ctr_model_base"

      log_info "Building Engine (TP=$TP_SIZE)..."
      compile_trt_engine "$ip1" "$ctr_engine_path" "$ctr_model_path" "$host_engine_base" "$host_model_base" "$ctr_engine_base" "$ctr_model_base" "$host_engine_path"

      # FIXED: Post-build verification
      if ssh "${SSH_OPTS[@]}" "$ip1" "[ -f $host_engine_path/config.json ]"; then
         log_info "Verification successful: Engine config found."
      else
         log_error "Engine build reported success but config.json is missing."
         exit 1
      fi
      log_info "Engine build complete."
  fi

  log_info "Syncing engine to Worker Node..."
  sync_engine_to_worker "$ip1" "$ip2" "$host_engine_path"
  log_info "Engine synced."

  if [[ "$dry_run" -eq 0 ]]; then set +x; fi
}

# ==============================================================================
# 5. Runtime & Orchestration Module
# ==============================================================================

# Internal: Cleanup existing containers
function _cleanup_existing_containers() {
  local ip
  log_step "[3/5] Cleaning up..."
  for ip in "$IP1" "$IP2"; do
    ssh "${SSH_OPTS[@]}" "$ip" "docker rm -f nim-distributed trt-llm-distributed >/dev/null 2>&1 || true"
  done
  log_info "Cleanup complete."
}

# Internal: Get NCCL Options
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

# Internal: Setup MPI SSH Keys
function setup_mpi_ssh_keys() {
  local ip1="$1"
  local ip2="$2"
  if [[ "$DRY_RUN" -eq 0 ]]; then
      log_info "Generating SSH keys for MPI..."
      _remote_mkdir "$ip1" "~/.ssh-trt"
      ssh "${SSH_OPTS[@]}" "$ip1" "ssh-keygen -t rsa -f ~/.ssh-trt/id_rsa -N '' && cat ~/.ssh-trt/id_rsa.pub > ~/.ssh-trt/authorized_keys"
      _remote_mkdir "$ip2" "~/.ssh-trt"
      ssh "${SSH_OPTS[@]}" "$ip1" "cat ~/.ssh-trt/id_rsa" | ssh "${SSH_OPTS[@]}" "$ip2" "cat > ~/.ssh-trt/id_rsa && chmod 600 ~/.ssh-trt/id_rsa"
      ssh "${SSH_OPTS[@]}" "$ip1" "cat ~/.ssh-trt/id_rsa.pub" | ssh "${SSH_OPTS[@]}" "$ip2" "cat > ~/.ssh-trt/id_rsa.pub"
      ssh "${SSH_OPTS[@]}" "$ip1" "cat ~/.ssh-trt/authorized_keys" | ssh "${SSH_OPTS[@]}" "$ip2" "cat > ~/.ssh-trt/authorized_keys"
  fi
}

# Internal: Generate TRT-LLM Run Command
function generate_trt_run_command() {
  local role="$1" # worker or head
  local container_name="$2"
  local net_args="$3"
  local mounts="$4"
  local image="$5"
  local tp_size="$6"
  local ip1="$7"
  local ip2="$8"
  local ifaces1="$9"
  local ifaces2="${10}"
  local hf_token="${11:-}"
  local hf_model_id="${12:-}"

  local safe_model_id=$(printf "%s" "$hf_model_id" | tr '/' '--')
  local engine_path="/engines/$safe_model_id"
  local hf_env=""
  if [[ -n "$hf_token" ]]; then hf_env="-e HF_TOKEN=$hf_token"; fi

  if [[ "$role" == "worker" ]]; then
      local ssh_start_cmd="(service ssh start || /usr/sbin/sshd) && sleep infinity"
      local net_opts=$(_get_nccl_opts "$ifaces2")
      printf "docker run -d --name %s %s %s %s --gpus all %s %s bash -c '%s'" \
        "$container_name" "$net_args" "$net_opts" "$hf_env" "$mounts" "$image" "$ssh_start_cmd"
  else
      local serve_cmd="mpirun --allow-run-as-root -n $tp_size -H $ip1:1,$ip2:1 python3 -m tensorrt_llm.serve --model_repo $engine_path --port 8000 --host 0.0.0.0"
      local ssh_start_head="(service ssh start || /usr/sbin/sshd) && $serve_cmd"
      local net_opts=$(_get_nccl_opts "$ifaces1")
      printf "docker run -d --name %s %s %s %s --gpus all %s %s bash -c '%s'" \
        "$container_name" "$net_args" "$net_opts" "$hf_env" "$mounts" "$image" "$ssh_start_head"
  fi
}

# Internal: Generate NIM Run Command
function generate_nim_run_command() {
  local role="$1" # worker or head
  local container_name="$2"
  local net_args="$3"
  local mounts="$4"
  local image="$5"
  local tp_size="$6"
  local ip1="$7"
  local ip2="$8"
  local ifaces1="$9"
  local ifaces2="${10}"
  local ngc_api_key="${11}"
  local model_arg="${12}"
  local extra_nim_env="${13}"
  local hf_token="${14:-}"

  local nim_env="-e NGC_API_KEY=$ngc_api_key -e NIM_SERVED_MODEL_NAME=$model_arg -e NIM_MULTI_NODE=1 -e NIM_TENSOR_PARALLEL_SIZE=$tp_size -e NIM_NUM_WORKERS=2 -e MASTER_ADDR=$ip1 -e MASTER_PORT=12345 -e NIM_HTTP_API_PORT=8000"
  nim_env="$nim_env -e UVICORN_HOST=0.0.0.0 -e HOST=0.0.0.0 -e NIM_SERVER_HTTP_HOST=0.0.0.0"
  if [[ -n "$hf_token" ]]; then nim_env="$nim_env -e HF_TOKEN=$hf_token"; fi
  nim_env="$nim_env $extra_nim_env"

  local node_rank=0
  local net_opts=""
  if [[ "$role" == "worker" ]]; then
      node_rank=1
      net_opts=$(_get_nccl_opts "$ifaces2")
  else
      net_opts=$(_get_nccl_opts "$ifaces1")
  fi

  printf "docker run -d --name %s %s %s --gpus all %s %s -e NIM_NODE_RANK=%d %s" \
      "$container_name" "$net_args" "$net_opts" "$mounts" "$nim_env" "$node_rank" "$image"
}

# Internal: Launch Distributed Service
function launch_distributed_service() {
  local ip1="$1"
  local ip2="$2"
  local use_trt_llm="$3"
  local trt_engine_dir="$4"
  local trt_model_dir="$5"
  local platform_arg="$6"
  local ifaces1="$7"
  local ifaces2="$8"
  local ngc_api_key="$9"
  local model_arg="${10}"
  local tp_size="${11}"
  local extra_nim_env="${12}"
  local image="${13}"
  local hf_token="${14:-}"
  local hf_model_id="${15:-}"
  local dry_run="${16:-0}"

  log_step "[4/5] Launching Service..."

  local host_engine_base="${trt_engine_dir:-~/engines}"
  local host_model_base="${trt_model_dir:-~/models}"
  local mounts="-v ~/.cache:/root/.cache -v $host_model_base:/models -v $host_engine_base:/engines"
  local net_args="$platform_arg --runtime=nvidia --network host --ipc=host --shm-size=16g --ulimit memlock=-1"
  local container_name="nim-distributed"

  local worker_cmd=""
  local head_cmd=""

  if [[ "$use_trt_llm" -eq 1 ]]; then
      container_name="trt-llm-distributed"
      setup_mpi_ssh_keys "$ip1" "$ip2"
      mounts="$mounts -v ~/.ssh-trt:/root/.ssh"

      worker_cmd=$(generate_trt_run_command "worker" "$container_name" "$net_args" "$mounts" "$image" "$tp_size" "$ip1" "$ip2" "$ifaces1" "$ifaces2" "$hf_token" "$hf_model_id")
      head_cmd=$(generate_trt_run_command "head" "$container_name" "$net_args" "$mounts" "$image" "$tp_size" "$ip1" "$ip2" "$ifaces1" "$ifaces2" "$hf_token" "$hf_model_id")
  else
      worker_cmd=$(generate_nim_run_command "worker" "$container_name" "$net_args" "$mounts" "$image" "$tp_size" "$ip1" "$ip2" "$ifaces1" "$ifaces2" "$ngc_api_key" "$model_arg" "$extra_nim_env" "$hf_token")
      head_cmd=$(generate_nim_run_command "head" "$container_name" "$net_args" "$mounts" "$image" "$tp_size" "$ip1" "$ip2" "$ifaces1" "$ifaces2" "$ngc_api_key" "$model_arg" "$extra_nim_env" "$hf_token")
  fi

  if [[ "$dry_run" -eq 1 ]]; then
      log_info "Worker: $worker_cmd"
      log_info "Head: $head_cmd"
      return
  fi

  ssh "${SSH_OPTS[@]}" "$ip2" "$worker_cmd"
  sleep 5
  ssh "${SSH_OPTS[@]}" "$ip1" "$head_cmd"

  ssh "${SSH_OPTS[@]}" "$ip1" "docker logs -f $container_name" &
  log_info "Service launch command issued."
}

# Internal: Wait for service
function _wait_for_service() {
  local ip="$1"
  local use_trt_llm="$2"
  local dry_run="$3"
  local container_name="nim-distributed"
  local i

  if [[ "$use_trt_llm" -eq 1 ]]; then container_name="trt-llm-distributed"; fi

  if [[ "$dry_run" -eq 1 ]]; then return 0; fi

  log_step "[5/5] Waiting for service (http://$ip:8000)..."
  for ((i = 1; i <= 60; i++)); do
    local state
    state=$(ssh "${SSH_OPTS[@]}" "$ip" "docker inspect -f '{{.State.Running}}' $container_name" 2>/dev/null || printf "false\n")
    if [[ "$state" != "true" ]]; then
       log_error "Container '$container_name' crashed or stopped!"
       ssh "${SSH_OPTS[@]}" "$ip" "docker logs --tail 20 $container_name" || true
       return 1
    fi
    if ssh "${SSH_OPTS[@]}" "$ip" "curl -s -m 5 http://localhost:8000/v1/health/ready | grep -q 'ready' 2>/dev/null"; then
      log_info "Service is ready!"
      return 0
    fi
    printf "."
    sleep 10
  done
  return 1
}

# Internal: Parse arguments
function _parse_arguments() {
  log_info "Parsing arguments..."
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --dry-run) DRY_RUN=1; shift ;;
      --force) FORCE=1; shift ;;
      --quant)
        if [[ -z "${2:-}" ]]; then log_error "--quant requires argument"; exit 1; fi
        QUANT_OVERRIDE="$2"; shift 2 ;;
      --engine)
        if [[ -z "${2:-}" ]]; then log_error "--engine requires argument"; exit 1; fi
        ENGINE_OVERRIDE="$2"; shift 2 ;;
      --image)
        if [[ -z "${2:-}" ]]; then log_error "--image requires argument"; exit 1; fi
        IMAGE_OVERRIDE="$2"; shift 2 ;;
      --batch-size) BATCH_SIZE="$2"; shift 2 ;;
      --max-seq-len) MAX_SEQ_LEN="$2"; shift 2 ;;
      --wandb-key) WANDB_KEY="$2"; shift 2 ;;
      --speculative) SPECULATIVE_MODE=1; shift ;;
      -*) log_error "Unknown option $1"; exit 1 ;;
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
    log_info "Usage:"
    log_info "  $0 [OPTIONS] <IP1> <IP2> [<MODEL_NAME|HF_URL>]  (First run / Setup)"
    log_info "  $0 [OPTIONS] start                              (Start using saved config)"
    log_info "  $0 [OPTIONS] stop                               (Stop using saved config)"
    log_info ""
    log_info "Options:"
    log_info "  --dry-run             Print commands without executing"
    log_info "  --force               Bypass safety checks"
    log_info "  --quant <fmt>         Force quantization (fp4, fp8, int8)"
    log_info "  --engine <name>       Backend engine (vllm, trt-llm)"
    log_info "  --image <name>        Custom Docker image override"
    log_info "  --batch-size <n>      Max batch size (default: 128)"
    log_info "  --max-seq-len <n>     Max sequence length (default: 2048)"
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
    _write_config
  fi
  log_info "Arguments parsed."
}

# ==============================================================================
# Main
# ==============================================================================
function main() {
  local ip
  _check_dependencies
  _parse_arguments "$@"

  if [[ "$MODE" == "stop" ]]; then
    _cleanup_existing_containers
    exit 0
  fi

  _validate_ip "$IP1"
  _validate_ip "$IP2"
  _check_api_key

  # Connectivity check reused from previous logic? It was inline. Let's add it back.
  log_step "[2/5] Verifying connectivity..."
  for ip in "$IP1" "$IP2"; do
    if ! ssh "${SSH_OPTS[@]}" "$ip" "nvidia-smi > /dev/null"; then
      log_error "Connectivity failed to $ip."
      exit 1
    fi
  done
  log_info "Connectivity verified."

  _check_remote_sudo

  parse_model_config
  check_vram_requirements "$PARAMS" "$IP1" "$IP2" "$FORCE" "$QUANT_OVERRIDE" "$EXTRA_NIM_ENV"
  PLATFORM_ARG=$(_detect_architecture "$IP1")
  detect_network_config

  ensure_image_present "$IP1" "$IP2" "$IMAGE" "$IFACES2"
  _align_platform_with_image "$IP1" "$IMAGE" "$PLATFORM_ARG"

  ensure_trt_engine "$USE_TRT_LLM" "$HF_MODEL_ID" "$IP1" "$IP2" "$IMAGE" "$DRY_RUN" "$TRT_ENGINE_DIR" "$TRT_MODEL_DIR"
  _cleanup_existing_containers
  launch_distributed_service "$IP1" "$IP2" "$USE_TRT_LLM" "$TRT_ENGINE_DIR" "$TRT_MODEL_DIR" "$PLATFORM_ARG" "$IFACES1" "$IFACES2" "$NGC_API_KEY" "$MODEL_ARG" "$TP_SIZE" "$EXTRA_NIM_ENV" "$IMAGE" "${HF_TOKEN:-}" "${HF_MODEL_ID:-}" "$DRY_RUN"
  _wait_for_service "$IP1" "$USE_TRT_LLM" "$DRY_RUN"
}

main "$@"
