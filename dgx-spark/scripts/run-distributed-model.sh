#!/usr/bin/env bash

# NVIDIA DGX Spark - Distributed NIM Launcher
#
# Installation:
#   curl -O https://raw.githubusercontent.com/toxicoder/devset/main/dgx-spark/scripts/run-distributed-model.sh && chmod +x run-distributed-model.sh
#
# This script spins up a distributed NVIDIA NIM across two DGX Spark nodes.
# It supports various high-parameter LLMs and Multimodal models, optimizing for
# high-speed interconnects (OSPF/IB) and distributed tensor parallelism.
#
# Assumes:
# 1. Passwordless SSH is configured between the runner and both nodes.
# 2. NGC_API_KEY is exported in the environment.
# 3. Docker and NVIDIA Container Toolkit are installed on both nodes.
# 4. The nodes are connected via a high-speed interconnect (400Gbps+ aggregate).

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
    printf "  --dry-run         Print commands without executing\n"
    printf "  --force           Bypass safety checks (Registry, VRAM)\n"
    printf "  --quant <fmt>     Force quantization (fp4, fp8, etc.)\n"
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
#   Format: ModelID|ImageTag|TP|PP|DefaultQuant|Params(B)|IsVision|ExtraEnv
#
# Returns:
#   String (Heredoc)
function _get_model_registry() {
  cat <<EOF
mega-1|meta/llama-3.1-405b-instruct|2|1|fp4|405|0|
mega-2|nvidia/nemotron-4-340b-instruct|2|1|fp4|340|0|
mega-3|deepseek-ai/deepseek-v2.5|2|1|fp8|236|0|
mega-4|mistralai/mistral-large-instruct-2407|2|1|fp8|123|0|
large-1|mistralai/mixtral-8x22b-instruct-v0.1|2|1|fp8|141|0|
large-2|cohere/command-r-plus-08-2024|2|1|fp16|104|0|
large-3|meta/llama-3.2-90b-vision-instruct|2|1|fp16|90|1|
large-4|alibaba/qwen2-vl-72b-instruct|2|1|fp16|72|1|
workhorse-1|meta/llama-3.1-70b-instruct|2|1|fp16|70|0|
workhorse-2|nvidia/llama-3.1-nemotron-70b-instruct|2|1|fp16|70|0|
workhorse-3|alibaba/qwen2.5-72b-instruct|2|1|fp16|72|0|
workhorse-4|deepseek-ai/deepseek-coder-v2-instruct|2|1|fp16|16|0|
workhorse-5|mistralai/pixtral-large-2411|2|1|fp8|124|1|
efficient-1|google/gemma-2-27b-it|2|1|fp16|27|0|
efficient-2|nvidia/nemotron-3-nano-30b-a3b|1|2|fp16|30|0|-e VLLM_ATTENTION_BACKEND=FLASHINFER -e NIM_TAGS_SELECTOR=precision=bf16
efficient-3|bigcode/starcoder2-15b|2|1|fp16|15|0|
efficient-4|microsoft/phi-3.5-moe-instruct|2|1|fp16|42|0|
special-1|allenai/molmo-72b-0924|2|1|fp16|72|1|
special-2|nvidia/nemotron-4-reward|2|1|fp16|340|0|
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
#   None (Uses globals: MODEL_ARG, QUANT_OVERRIDE, FORCE)
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
  # We match either the ID (e.g., mega-1) or the Image Tag (e.g., meta/llama-3.1-405b-instruct)
  local model_data
  model_data=$(_get_model_registry | grep -F "$MODEL_ARG" | head -n 1 || true)

  if [[ -n "$model_data" ]]; then
    # Parse pipe-delimited data
    # format: id|image|tp|pp|quant|params|is_vision|extra
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
    if [[ "$FORCE" -eq 1 ]]; then
      printf "Warning: Model '%s' not found in Top 20 registry.\n" "$MODEL_ARG"
      printf "Force enabled: Attempting generic configuration...\n"
      IMAGE="nvcr.io/nim/$MODEL_ARG:latest"
      # Basic defaults
    else
      printf "Error: Model '%s' not found in the strictly supported Top 20 registry.\n" \
        "$MODEL_ARG" >&2
      printf "Use --force to bypass this restriction (not recommended).\n" >&2
      exit 1
    fi
  fi

  # Quantization Injection
  local quant_to_use="$default_quant"
  if [[ -n "$QUANT_OVERRIDE" ]]; then
    quant_to_use="$QUANT_OVERRIDE"
    printf "Quantization override: %s\n" "$quant_to_use"
  fi

  # Inject Quantization if not fp16/bf16 default, or if it's a "Mega" model constraint
  # NIM usually uses NIM_QUANTIZATION or NIM_MODEL_PROFILE.
  if [[ "$quant_to_use" != "fp16" && "$quant_to_use" != "bf16" ]]; then
    EXTRA_NIM_ENV="$EXTRA_NIM_ENV -e NIM_QUANTIZATION=$quant_to_use"
  fi

  printf "=== NVIDIA DGX Spark Distributed NIM Launcher ===\n"
  printf "Nodes: %s (Head), %s (Worker)\n" "$IP1" "$IP2"
  printf "Model: %s\n" "$MODEL_ARG"
  printf "Image: %s\n" "$IMAGE"
  printf "TP: %s, PP: %s, Quant: %s\n" "$TP_SIZE" "$PP_SIZE" "$quant_to_use"
  if [[ "$IS_VISION" -eq 1 ]]; then
    printf "Type: Vision/Multimodal\n"
  else
    printf "Type: LLM\n"
  fi
  printf "%s\n" "================================================"
}

# Internal: Check VRAM requirements
#
# Description:
#   Checks if the cluster has enough VRAM for the selected model.
#   Queries actual VRAM from nodes via nvidia-smi.
#
# Arguments:
#   $1: Model parameters in billions (approx).
#   $2: Context length (unused/reserved).
#   Uses globals: IP1, IP2, SSH_OPTS, FORCE.
#
# Returns:
#   None
function _check_vram_requirements() {
  local params="$1"
  # Unused context arg
  shift

  printf "[Check] verifying VRAM capacity...\n"

  # Query VRAM on both nodes
  local vram1
  vram1=$(ssh "${SSH_OPTS[@]}" "$IP1" \
    "nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits" 2>/dev/null |
    awk '{s+=$1} END {print s}')
  local vram2
  vram2=$(ssh "${SSH_OPTS[@]}" "$IP2" \
    "nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits" 2>/dev/null |
    awk '{s+=$1} END {print s}')

  # Default to 0 if failed
  vram1=${vram1:-0}
  vram2=${vram2:-0}

  # Convert MB to GB
  local total_gb
  total_gb=$(awk -v v1="$vram1" -v v2="$vram2" 'BEGIN {print (v1 + v2) / 1024}')

  printf "Total Cluster VRAM Detected: %.2f GB\n" "$total_gb"

  # Simple heuristic: If model > 200B params and total < 230GB, abort
  local params_num="${params:-0}"
  if awk -v p="$params_num" 'BEGIN {exit !(p > 200)}'; then
    if awk -v t="$total_gb" 'BEGIN {exit !(t < 230)}'; then
      printf "CRITICAL WARNING: Model size (~%sB) is large for detected VRAM (%.2f GB).\n" \
        "$params_num" "$total_gb"
      printf "Ensure you are using Quantization (FP8/FP4) via --quant.\n"
      if [[ "$FORCE" -eq 1 ]]; then
        printf "Force enabled. Proceeding despite memory risks...\n"
      else
        printf "Aborting to prevent potential crash. Use --force to override.\n" >&2
        exit 1
      fi
    fi
  fi
}

# Internal: Detect architecture
#
# Description:
#   Detects the CPU architecture on the head node to determine if a platform override
#   is needed for Docker commands (e.g., forcing linux/amd64 on non-native environments
#   if required).
#
# Arguments:
#   None (Uses globals: IP1, SSH_OPTS)
#
# Returns:
#   None (Sets global PLATFORM_ARG)
function _detect_architecture() {
  local arch
  arch=$(ssh "${SSH_OPTS[@]}" "$IP1" "uname -m" 2>/dev/null)
  # Trim whitespace
  arch=$(printf "%s" "$arch" | xargs)
  printf "Detected architecture on %s: %s\n" "$IP1" "$arch"

  PLATFORM_ARG=""
  if [[ "$arch" == "x86_64" ]]; then
    PLATFORM_ARG="--platform linux/amd64"
  elif [[ "$arch" == "aarch64" ]]; then
    printf "ARM64 detected. Using native architecture (no platform override).\n"
    PLATFORM_ARG=""
  else
    # Fallback/Unknown - stick to legacy behavior
    printf "Unknown architecture: %s. Defaulting to linux/amd64.\n" "$arch"
    PLATFORM_ARG="--platform linux/amd64"
  fi
}

# Internal: Detect high-speed network interfaces
#
# Description:
#   Attempts to detect available high-speed network interfaces (e.g., InfiniBand, Ethernet) on a remote node.
#   First tries OSPF neighbor detection via 'vtysh'.
#   Falls back to 'ibdev2netdev' if OSPF data is unavailable.
#
# Arguments:
#   $1: The IP address of the node to check.
#   Uses globals: SSH_OPTS.
#
# Returns:
#   A formatted string: "DETECTED_MULTI:<ifaces>", "DETECTED_SINGLE:<iface>", or "DETECTED_NONE"
function _get_network_config() {
  local ip="$1"
  # NEW: OSPF Autodetection
  # 1. Try to detect OSPF neighbors via vtysh
  local ospf_neighbors
  if ospf_neighbors=$(ssh "${SSH_OPTS[@]}" "$ip" \
    "sudo vtysh -c 'show ip ospf neighbor' 2>/dev/null"); then
    # Parse for 'Full' state and get interface (col 6)
    local ifaces
    ifaces=$(echo "$ospf_neighbors" |
      grep "Full" |
      awk '{print $6}' |
      sort |
      uniq |
      tr '\n' ',' |
      sed 's/,$//' || true)

    if [[ -n "$ifaces" ]]; then
      # Check if we have multiple
      if [[ "$ifaces" == *","* ]]; then
        printf "DETECTED_MULTI: %s" "$ifaces"
        return
      else
        printf "DETECTED_SINGLE: %s" "$ifaces"
        return
      fi
    fi
  fi

  # 2. Fallback to ibdev2netdev
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
#   Strips the prefix (e.g., "DETECTED_SINGLE:") and whitespace.
#
# Arguments:
#   $1: The raw detection string.
#
# Returns:
#   The clean interface name(s).
function _parse_net_conf() {
  local conf="$1"
  local val="${conf#*:}"
  # Trim leading/trailing whitespace
  val=$(printf "%s" "$val" | xargs)
  printf "%s" "$val"
}

# Internal: Get IP from interface
#
# Description:
#   Resolves the IPv4 address associated with a specific network interface on a remote node.
#   Uses 'ip addr show' via SSH.
#
# Arguments:
#   $1: The remote host IP/hostname.
#   $2: The interface name (or comma-separated list, first one is used).
#   Uses globals: SSH_OPTS.
#
# Returns:
#   The detected IP address, or error if not found.
function _get_ip_from_iface() {
  local ip_host="$1"
  local iface_list="$2"
  # Take the first interface if multiple
  local iface
  iface=$(echo "$iface_list" | cut -d',' -f1)

  if [[ -z "$iface" ]]; then
    return 1
  fi

  # Get IP
  ssh "${SSH_OPTS[@]}" "$ip_host" \
    "ip -4 addr show $iface | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n 1"
}

# Internal: Detect network
#
# Description:
#   Orchestrates the detection of high-speed network interfaces for both nodes.
#   Performs pre-flight checks for IB tools.
#   Sets global variables NET_CONF_1, NET_CONF_2, IFACES1, and IFACES2.
#
# Arguments:
#   None (Uses globals: IP1, IP2, SSH_OPTS)
#
# Returns:
#   None (Sets globals: NET_CONF_1, NET_CONF_2, IFACES1, IFACES2)
function _detect_network() {
  printf "[1/4] Detecting high-speed network interfaces...\n"

  # Pre-flight check for IB tools and Link State
  if ssh "${SSH_OPTS[@]}" "$IP1" "command -v ib_write_bw >/dev/null"; then
    printf "  [+] ib_write_bw detected.\n"
  else
    printf "  [-] ib_write_bw not found.\n"
  fi

  # Check /sys/class/infiniband for active links
  if ssh "${SSH_OPTS[@]}" "$IP1" \
    "find /sys/class/infiniband -name 'state' -print0 2>/dev/null | xargs -0 grep -l 'ACTIVE' >/dev/null"; then
    printf "  [+] Active InfiniBand links detected via sysfs.\n"
  else
    printf "  [-] No ACTIVE InfiniBand links found in /sys/class/infiniband.\n"
  fi

  NET_CONF_1=$(_get_network_config "$IP1")
  NET_CONF_2=$(_get_network_config "$IP2")

  IFACES1=$(_parse_net_conf "$NET_CONF_1")
  IFACES2=$(_parse_net_conf "$NET_CONF_2")

  printf "Node 1 Interfaces: %s\n" "$IFACES1"
  printf "Node 2 Interfaces: %s\n" "$IFACES2"

  if [[ -z "$IFACES1" || -z "$IFACES2" || "$NET_CONF_1" == *"DETECTED_NONE"* || "$NET_CONF_2" == *"DETECTED_NONE"* ]]; then
    printf "Warning: Failed to detect high-speed network interfaces on one or both nodes.\n" >&2
    printf "Ensure IB or OSPF is configured correctly. Proceeding with potential performance degradation...\n" >&2
  fi
}

# Internal: Verify connectivity
#
# Description:
#   Checks SSH connectivity and NVIDIA driver status (nvidia-smi) on both nodes.
#
# Arguments:
#   None (Uses globals: IP1, IP2, SSH_OPTS)
#
# Returns:
#   None (Exits on failure)
function _verify_connectivity() {
  printf "[2/4] Verifying connectivity and pulling image...\n"
  for ip in "$IP1" "$IP2"; do
    printf "Connecting to %s...\n" "$ip"
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
#   Pulls the image on the head node first.
#   Checks the worker node for existence AND digest match.
#   Attempts a high-performance P2P transfer (pigz + mbuffer/nc) from the head node if missing.
#
# Arguments:
#   None (Uses globals: IP1, IP2, IMAGE, IFACES2, PLATFORM_ARG, NGC_API_KEY, SSH_OPTS)
#
# Returns:
#   None (Exits on failure)
function _ensure_image_present() {
  # 1. Pull on Head Node (IP1)
  printf "Pulling image %s on Head Node (%s)...\n" "$IMAGE" "$IP1"
  if ! ssh "${SSH_OPTS[@]}" "$IP1" \
    "echo '$NGC_API_KEY' | docker login nvcr.io -u '\$oauthtoken' --password-stdin >/dev/null 2>&1 && docker pull $PLATFORM_ARG $IMAGE"; then
    printf "Error: Failed to pull image on %s\n" "$IP1" >&2
    exit 1
  fi

  # Get Image ID from Head Node
  local id_head
  id_head=$(ssh "${SSH_OPTS[@]}" "$IP1" \
    "docker inspect --format='{{.Id}}' $IMAGE 2>/dev/null" || true)

  # 2. Check Worker Node (IP2)
  printf "Checking image on Worker Node (%s)...\n" "$IP2"
  local id_worker
  id_worker=$(ssh "${SSH_OPTS[@]}" "$IP2" \
    "docker inspect --format='{{.Id}}' $IMAGE 2>/dev/null" || true)

  if [[ -n "$id_worker" && "$id_head" == "$id_worker" ]]; then
    printf "Image already exists and matches on %s.\n" "$IP2"
  else
    if [[ -z "$id_worker" ]]; then
      printf "Image missing on %s.\n" "$IP2"
    else
      printf "Image hash mismatch on %s. Updating...\n" "$IP2"
    fi

    local transfer_success=0

    # Try High Speed Transfer
    if [[ -n "$IFACES2" ]]; then
      local fast_ip2
      fast_ip2=$(_get_ip_from_iface "$IP2" "$IFACES2")
      if [[ -n "$fast_ip2" ]] &&
        ssh "${SSH_OPTS[@]}" "$IP1" "command -v nc >/dev/null && command -v pigz >/dev/null" &&
        ssh "${SSH_OPTS[@]}" "$IP2" "command -v nc >/dev/null && command -v pigz >/dev/null"; then

        printf "Detected High-Speed IP for %s: %s\n" "$IP2" "$fast_ip2"
        printf "Using pigz for parallel compression.\n"
        local transfer_port=12346

        # Determine nc options for auto-close
        local nc_opts=""
        if ssh "${SSH_OPTS[@]}" "$IP1" "nc -h 2>&1 | grep -q -- -N"; then
          nc_opts="-N"
        elif ssh "${SSH_OPTS[@]}" "$IP1" "nc -h 2>&1 | grep -q -- -q"; then
          nc_opts="-q 1"
        else
          nc_opts="-q 1"
        fi

        printf "Starting High-Performance P2P transfer from %s to %s...\n" "$IP1" "$IP2"

        # Check for mbuffer
        local use_mbuffer=0
        if ssh "${SSH_OPTS[@]}" "$IP1" "command -v mbuffer >/dev/null" && \
          ssh "${SSH_OPTS[@]}" "$IP2" "command -v mbuffer >/dev/null"; then
          use_mbuffer=1
          printf "Enabled mbuffer for buffer optimization.\n"
        fi

        # Start Listener on IP2
        # Command: nc -l -p PORT | pigz -d | docker load
        local recv_cmd="nc -l -p $transfer_port"
        if [[ "$use_mbuffer" -eq 1 ]]; then
          recv_cmd="nc -l -p $transfer_port | mbuffer -m 1G"
        fi
        (
          ssh "${SSH_OPTS[@]}" "$IP2" "$recv_cmd | pigz -d | docker load"
        ) &
        local listener_pid=$!

        sleep 5

        # Start Sender on IP1
        # Command: docker save IMG | pigz -c -1 | nc IP PORT
        local send_cmd="docker save $IMAGE | pigz -c -1"
        if [[ "$use_mbuffer" -eq 1 ]]; then
          send_cmd="docker save $IMAGE | pigz -c -1 | mbuffer -m 1G"
        fi

        if ssh "${SSH_OPTS[@]}" "$IP1" "$send_cmd | nc -w 60 $nc_opts $fast_ip2 $transfer_port"; then
          printf "Transfer command finished.\n"
        else
          printf "Transfer command failed.\n"
        fi

        # Wait for listener
        if wait "$listener_pid"; then
          printf "Image transfer successful.\n"
          transfer_success=1
        else
          printf "Image transfer failed (Listener exit code).\n"
        fi
      else
        printf "Could not resolve IP for interface %s on %s or 'nc'/'pigz' missing.\n" "$IFACES2" "$IP2"
      fi
    else
      printf "No high-speed interface detected on %s.\n" "$IP2"
    fi

    # Fallback
    if [[ "$transfer_success" -eq 0 ]]; then
      printf "Falling back to downloading image on %s...\n" "$IP2"
      if ! ssh "${SSH_OPTS[@]}" "$IP2" \
        "echo '$NGC_API_KEY' | docker login nvcr.io -u '\$oauthtoken' --password-stdin >/dev/null 2>&1 && docker pull $PLATFORM_ARG $IMAGE"; then
        printf "Error: Failed to pull image on %s\n" "$IP2" >&2
        exit 1
      fi
    fi
  fi
}

# Internal: Cleanup existing containers
#
# Description:
#   Removes any existing containers named 'nim-distributed' on both nodes.
#
# Arguments:
#   None (Uses globals: IP1, IP2, SSH_OPTS)
#
# Returns:
#   None
function _cleanup_existing_containers() {
  printf "[3/4] Cleaning up previous containers...\n"
  for ip in "$IP1" "$IP2"; do
    ssh "${SSH_OPTS[@]}" "$ip" \
      "docker rm -f nim-distributed >/dev/null 2>&1 || true"
  done
}

# Internal: Free system memory
#
# Description:
#   Prompts the user to free system RAM (drop caches) on both nodes.
#   This is useful for ensuring maximum available memory for model loading.
#
# Arguments:
#   None (Uses globals: IP1, IP2, SSH_OPTS)
#
# Returns:
#   None
function _free_system_memory() {
  # Skip if dry run
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf "Dry run: Skipping memory clear prompt.\n"
    return
  fi

  printf "\n[Memory Optimization]\n"
  printf "Do you want to clear system RAM (drop caches) on all nodes to free up memory? [y/N] "
  read -r response
  if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    printf "Clearing caches on %s and %s...\n" "$IP1" "$IP2"
    for ip in "$IP1" "$IP2"; do
      if ssh "${SSH_OPTS[@]}" "$ip" "sudo sh -c 'sync; echo 3 > /proc/sys/vm/drop_caches'"; then
        printf "  [+] Caches dropped on %s.\n" "$ip"
      else
        printf "  [-] Failed to drop caches on %s (check sudo permissions).\n" "$ip"
      fi
    done
  else
    printf "Skipping memory clear.\n"
  fi
}

# Prepare ENV vars for network
#
# Description:
#   Generates the necessary Docker environment arguments for NCCL/GLOO based on network interfaces.
#   Enables multi-rail optimizations if multiple interfaces are detected.
#   Exports high-performance NCCL/IB variables.
#
# Arguments:
#   $1: Comma-separated list of interface names.
#
# Returns:
#   A string containing Docker env vars (e.g., "-e NCCL_SOCKET_IFNAME=...").
function _get_nccl_opts() {
  local ifaces="$1"
  # Default NCCL optimizations for 400Gbps IB/RoCE
  local opts="-e NCCL_IB_DISABLE=0 -e NCCL_IB_GID_INDEX=${NCCL_IB_GID_INDEX:-3} -e NCCL_CROSS_NIC=1"

  if [[ -n "$ifaces" ]]; then
    opts="$opts -e NCCL_SOCKET_IFNAME=$ifaces -e GLOO_SOCKET_IFNAME=$ifaces"
    if [[ "$ifaces" == *","* ]]; then
      # Multi-rail detected
      # Assuming equal HCAs, e.g., mlx5_0, mlx5_1 corresponding to interfaces
      # Enabling multi-rail optimization
      opts="$opts -e NCCL_MULTI_RAIL=1"
    fi
  fi
  printf "%s" "$opts"
}

# Internal: Launch distributed service
#
# Description:
#   Launches the NIM containers on both nodes in parallel.
#   Configures environment variables, network settings, and volume mounts.
#   Supports --dry-run mode.
#
# Arguments:
#   None (Uses many globals: IP1, IP2, IMAGE, MODEL_ARG, TP_SIZE, PP_SIZE,
#         NGC_API_KEY, SSH_OPTS, DRY_RUN, PLATFORM_ARG, EXTRA_NIM_ENV,
#         IFACES1, IFACES2)
#
# Returns:
#   None (Exits on launch failure)
function _launch_distributed_service() {
  printf "[4/4] Launching NIM containers...\n"

  # Common Docker Args
  # Added -v $HOME/.nim_logs:/opt/nim/logs as requested
  local common_args
  common_args="$PLATFORM_ARG --runtime=nvidia --gpus all --network host"
  common_args="$common_args --ipc=host --name nim-distributed --shm-size=16g"
  common_args="$common_args -v ~/.cache/nim:/opt/nim/.cache"
  common_args="$common_args -v $HOME/.nim_logs:/opt/nim/logs"

  # Add NIM_SERVER_HTTP_HOST=0.0.0.0 for safety
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

  # Prepare commands
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

  # Launch in parallel
  local launch_pids=()

  # Worker
  printf "Starting Worker on %s...\n" "$IP2"
  (
    # Create logs dir
    ssh "${SSH_OPTS[@]}" "$IP2" "mkdir -p ~/.nim_logs"
    ssh "${SSH_OPTS[@]}" "$IP2" "$worker_cmd"
  ) &
  launch_pids+=("$!")

  sleep 10

  # Head
  printf "Starting Head on %s...\n" "$IP1"
  (
    # Create logs dir
    ssh "${SSH_OPTS[@]}" "$IP1" "mkdir -p ~/.nim_logs"
    ssh "${SSH_OPTS[@]}" "$IP1" "$head_cmd"
  ) &
  launch_pids+=("$!")

  for pid in "${launch_pids[@]}"; do
    if ! wait "$pid"; then
      printf "Error: Failed to launch container on one of the nodes.\n" >&2
      exit 1
    fi
  done

  # Verify containers are running
  sleep 5
  printf "Verifying containers are running...\n"
  for ip in "$IP1" "$IP2"; do
    if ! ssh "${SSH_OPTS[@]}" "$ip" "docker ps | grep -q nim-distributed"; then
       printf "Error: Container nim-distributed failed to start or crashed on %s.\n" "$ip" >&2
       ssh "${SSH_OPTS[@]}" "$ip" "docker logs --tail 20 nim-distributed"
       exit 1
    fi
  done

  # Start background tailing of logs on Head node
  printf "Tailing logs on Head node (%s) in background...\n" "$IP1"
  ssh "${SSH_OPTS[@]}" "$IP1" "docker logs -f nim-distributed" &
}

# Internal: Wait for service readiness
#
# Description:
#   Polls the service health endpoint to determine when the NIM is fully ready to accept requests.
#   Also monitors container status to fail fast if the container crashes.
#   Uses Python for robust JSON parsing.
#
# Arguments:
#   $1: IP address of the head node.
#   Uses globals: SSH_OPTS, DRY_RUN.
#
# Returns:
#   0 on success, 1 on failure/timeout.
function _wait_for_service() {
  local ip="$1"
  local port=8000
  local retries=90 # 90 * 10s = 15 minutes
  local wait_time=10

  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf "Dry run: Skipping health check.\n"
    return 0
  fi

  printf "Waiting for service to be ready at http://%s:%s...\n" "$ip" "$port"

  for ((i = 1; i <= retries; i++)); do
    # Check if container is still running
    if ! ssh "${SSH_OPTS[@]}" "$ip" "docker ps | grep -q nim-distributed"; then
      printf "\nError: Container nim-distributed is no longer running on %s.\n" "$ip" >&2
      printf "Fetching last 50 lines of logs:\n"
      ssh "${SSH_OPTS[@]}" "$ip" "docker logs --tail 50 nim-distributed"
      return 1
    fi

    # Try checking health endpoint with python parsing
    # We use curl to fetch JSON, then python to check .data.ready == true
    if ssh "${SSH_OPTS[@]}" "$ip" \
      "curl -s -m 5 http://localhost:$port/v1/health/ready \
      | python3 -c \"import sys, json; sys.exit(0 if json.load(sys.stdin).get('data', {}).get('ready') == True else 1)\" 2>/dev/null"; then
      printf "Service is ready!\n"
      return 0
    fi
    printf "."
    sleep $wait_time
  done

  printf "\nWarning: Service did not become ready after %s seconds.\n" "$((retries * wait_time))" >&2
  printf "It might still be loading, or it failed to start.\n" >&2
  printf "Check logs on the head node for details.\n" >&2
  return 1
}

# Main function
#
# Description:
#   Orchestrates the entire distributed model launch process.
#
# Arguments:
#   $@: Command-line arguments.
#
# Returns:
#   Exit code.
function main() {
  _check_dependencies
  _parse_arguments "$@"

  if [[ "$MODE" == "stop" ]]; then
    printf "Stopping distributed model on %s and %s...\n" "$IP1" "$IP2"
    for ip in "$IP1" "$IP2"; do
      ssh "${SSH_OPTS[@]}" "$ip" \
        "docker rm -f nim-distributed >/dev/null 2>&1 || true"
    done
    printf "Stopped.\n"
    exit 0
  fi

  _validate_ip "$IP1"
  _validate_ip "$IP2"
  _check_api_key

  _configure_model
  _check_vram_requirements "$PARAMS" "$CONTEXT"
  _detect_architecture

  _detect_network
  _verify_connectivity
  _ensure_image_present

  _cleanup_existing_containers
  _free_system_memory
  _launch_distributed_service

  _wait_for_service "$IP1"

  printf "%s\n" "---------------------------------------------------"
  printf "Distributed NIM launched.\n"
  if [[ "$IS_VISION" -eq 1 ]]; then
    printf "Endpoint: http://%s:8000/v1/images/generations (or model specific)\n" "$IP1"
  else
    printf "Endpoint: http://%s:8000/v1/chat/completions\n" "$IP1"
  fi
  printf "Logs Node 1: ssh %s 'docker logs -f nim-distributed'\n" "$IP1"
  printf "Logs Node 2: ssh %s 'docker logs -f nim-distributed'\n" "$IP2"
  printf "%s\n" "---------------------------------------------------"
}

main "$@"
