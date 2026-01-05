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

# Dependency check
for cmd in ssh awk grep sed nc curl; do
  if ! command -v "$cmd" &>/dev/null; then
    printf "Error: Required command '%s' not found.\n" "$cmd" >&2
    exit 1
  fi
done

# === Supported Models List ===
# 1. meta/llama-3.1-405b-instruct
# 2. nvidia/nemotron-4-340b-instruct
# 3. mistralai/mixtral-8x22b-instruct-v0.1
# 4. meta/llama-3.1-70b-instruct (Default)
# 5. nvidia/llama-3.1-nemotron-70b-instruct
# 6. alibaba/qwen2.5-72b-instruct
# 7. mistralai/mistral-large-instruct-2407
# 8. deepseek-ai/deepseek-v3
# 9. stabilityai/stable-diffusion-3.5-large
# 10. nvidia/nemotron-nano-12b-v2-vl
# 11. nvidia/nemotron-3-nano
#
# Context-Heavy Models:
# 12. nvidia/nemotron-3-nano-30b-a3b
# 13. meta/llama-4-scout
# 14. deepseek-ai/deepseek-v3.1
# 14. alibaba/qwen3-30b-a3b-thinking

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly CONFIG_FILE="$SCRIPT_DIR/dgx-spark-distributed-model-config.json"

# SSH options
readonly SSH_OPTS=(-o StrictHostKeyChecking=no -o ConnectTimeout=10)

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
#   None (Sets global variables)
function _read_config() {
  if [[ ! -f "$CONFIG_FILE" ]]; then
    printf "Error: Config file not found at %s\n" "$CONFIG_FILE" >&2
    exit 1
  fi
  # We need to assign to globals here as this reads into the script scope
  IP1=$(grep '"ip1":' "$CONFIG_FILE" | head -n1 | awk -F'"' '{print $4}')
  IP2=$(grep '"ip2":' "$CONFIG_FILE" | head -n1 | awk -F'"' '{print $4}')
  MODEL_ARG=$(grep '"model":' "$CONFIG_FILE" | head -n1 | awk -F'"' '{print $4}')

  if [[ -z "$IP1" || -z "$IP2" || -z "$MODEL_ARG" ]]; then
    printf "Error: Failed to parse config file.\n" >&2
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
#   None (Reads global IP1, IP2, MODEL_ARG)
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

# Check arguments
MODE="setup"
if [[ "$#" -eq 1 && "$1" == "stop" ]]; then
  MODE="stop"
elif [[ "$#" -eq 1 && "$1" == "start" ]]; then
  MODE="start"
elif [[ "$#" -ge 2 && "$#" -le 3 ]]; then
  MODE="setup"
else
  printf "Usage:\n"
  printf "  %s <IP1> <IP2> [<MODEL_NAME>]  (First run / Setup)\n" "$0"
  printf "  %s start                       (Start using saved config)\n" "$0"
  printf "  %s stop                        (Stop using saved config)\n" "$0"
  exit 1
fi

if [[ "$MODE" == "stop" ]]; then
  _read_config
  printf "Stopping distributed model on %s and %s...\n" "$IP1" "$IP2"
  for ip in "$IP1" "$IP2"; do
    ssh "${SSH_OPTS[@]}" "$ip" "docker rm -f nim-distributed >/dev/null 2>&1 || true"
  done
  printf "Stopped.\n"
  exit 0
elif [[ "$MODE" == "start" ]]; then
  _read_config
elif [[ "$MODE" == "setup" ]]; then
  IP1="$1"
  IP2="$2"
  MODEL_ARG="${3:-"meta/llama-3.1-70b-instruct"}"
  _write_config
fi

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
_validate_ip "$IP1"
_validate_ip "$IP2"

# Check for NGC_API_KEY
if [[ -z "${NGC_API_KEY:-}" ]]; then
  printf "Error: NGC_API_KEY environment variable is not set.\n" >&2
  printf "Please export your NGC API Key: export NGC_API_KEY='nvapi-...'\n" >&2
  exit 1
fi

# === Model Configuration ===

# Defaults
TP_SIZE=2
PP_SIZE=1
IS_VISION=0
EXTRA_NIM_ENV=""

# Mapping Logic
case "$MODEL_ARG" in
  "meta/llama-3.1-405b-instruct")
    IMAGE="nvcr.io/nim/meta/llama-3.1-405b-instruct:latest"
    PARAMS=405
    CONTEXT=128
    ;;
  "nvidia/nemotron-4-340b-instruct")
    IMAGE="nvcr.io/nim/nvidia/nemotron-4-340b-instruct:latest"
    PARAMS=340
    CONTEXT=128
    ;;
  "mistralai/mixtral-8x22b-instruct-v0.1")
    IMAGE="nvcr.io/nim/mistralai/mixtral-8x22b-instruct-v0.1:latest"
    PARAMS=141
    CONTEXT=64
    ;;
  "meta/llama-3.1-70b-instruct")
    IMAGE="nvcr.io/nim/meta/llama-3.1-70b-instruct:latest"
    PARAMS=70
    CONTEXT=128
    ;;
  "nvidia/llama-3.1-nemotron-70b-instruct")
    IMAGE="nvcr.io/nim/nvidia/llama-3.1-nemotron-70b-instruct:latest"
    PARAMS=70
    CONTEXT=128
    ;;
  "alibaba/qwen2.5-72b-instruct")
    IMAGE="nvcr.io/nim/alibaba/qwen2.5-72b-instruct:latest"
    PARAMS=72
    CONTEXT=128
    ;;
  "mistralai/mistral-large-instruct-2407")
    IMAGE="nvcr.io/nim/mistralai/mistral-large-instruct-2407:latest"
    PARAMS=123
    CONTEXT=128
    ;;
  "deepseek-ai/deepseek-v3")
    IMAGE="nvcr.io/nim/deepseek-ai/deepseek-v3:latest"
    PARAMS=230
    CONTEXT=128
    ;;
  "stabilityai/stable-diffusion-3.5-large")
    IMAGE="nvcr.io/nim/stabilityai/stable-diffusion-3.5-large:latest"
    PARAMS=8
    CONTEXT=4 # Small context for vision usually
    IS_VISION=1
    ;;
  "nvidia/nemotron-nano-12b-v2-vl")
    IMAGE="nvcr.io/nim/nvidia/nemotron-nano-12b-v2-vl:latest"
    PARAMS=12
    CONTEXT=32
    IS_VISION=1
    ;;
  "nvidia/nemotron-3-nano")
    IMAGE="nvcr.io/nim/nvidia/nemotron-3-nano:latest"
    PARAMS=30
    CONTEXT=32 # Mamba arch (low memory footprint), supports 1M
    TP_SIZE=1
    PP_SIZE=2 # Mamba / Small model prefer PP or Single over TP
    EXTRA_NIM_ENV="-e NIM_GPU_MEMORY_UTILIZATION=0.40"
    ;;
  "nvidia/nemotron-3-nano-30b-a3b")
    IMAGE="nvcr.io/nim/nvidia/nemotron-3-nano-30b-a3b:latest"
    PARAMS=30
    CONTEXT=32 # Mamba arch (low memory footprint), supports 1M
    TP_SIZE=1
    PP_SIZE=2 # Mamba / Small model prefer PP or Single over TP
    EXTRA_NIM_ENV="-e NIM_GPU_MEMORY_UTILIZATION=0.40"
    ;;
  "meta/llama-4-scout")
    IMAGE="nvcr.io/nim/meta/llama-4-scout:latest"
    PARAMS=109
    CONTEXT=10000
    ;;
  "deepseek-ai/deepseek-v3.1")
    IMAGE="nvcr.io/nim/deepseek-ai/deepseek-v3.1:latest"
    PARAMS=671
    CONTEXT=128
    ;;
  "alibaba/qwen3-30b-a3b-thinking" | "alibaba/qwen3-30b-a3b-thinking-2507")
    IMAGE="nvcr.io/nim/alibaba/qwen3-30b-a3b-thinking-2507:latest"
    PARAMS=30
    CONTEXT=1000
    ;;
  *)
    printf "Unknown model: %s\n" "$MODEL_ARG"
    printf "Using provided name as image name suffix or custom mapping not found.\n"
    printf "Defaulting to generic configuration.\n"
    IMAGE="nvcr.io/nim/$MODEL_ARG:latest"
    PARAMS=10
    CONTEXT=4 # Safe defaults to avoid warning
    ;;
esac

printf "=== NVIDIA DGX Spark Distributed NIM Launcher ===\n"
printf "Nodes: %s (Head), %s (Worker)\n" "$IP1" "$IP2"
printf "Model: %s\n" "$MODEL_ARG"
printf "Image: %s\n" "$IMAGE"
TYPE_STR="LLM"
if [[ "$IS_VISION" -eq 1 ]]; then
  TYPE_STR="Vision/Multimodal"
fi
printf "Type: %s\n" "$TYPE_STR"
printf "%s\n" "================================================"

# === VRAM Estimation Check ===

# Internal: Check VRAM requirements
#
# Description:
#   Estimates the required VRAM for the selected model based on parameter count and context size.
#   Warns the user if the estimated usage exceeds the capacity of a dual DGX Spark cluster (256GB).
#
# Arguments:
#   $1: Model parameters in billions.
#   $2: Context window size in thousands of tokens.
#
# Returns:
#   None (Prints status/warnings)
function _check_vram_requirements() {
  local p_b="$1"
  local c_k="$2"

  # FP16 Weights: params * 2 bytes
  local weights_gb
  weights_gb=$(awk -v p="$p_b" 'BEGIN {print p * 2}')

  local total_est="$weights_gb"
  # Add buffer for KV
  if [[ "$c_k" -gt 128 ]]; then
    # Huge context adds significant memory
    # Factor: 0.3 GB per k context.
    local kv_add
    kv_add=$(awk -v c="$c_k" 'BEGIN {print c * 0.3}')
    total_est=$(awk -v t="$total_est" -v k="$kv_add" 'BEGIN {print t + k}')
  else
    # Standard context, assume +20% overhead
    total_est=$(awk -v t="$total_est" 'BEGIN {print t * 1.2}')
  fi

  # Round to integer
  total_est=$(awk -v t="$total_est" 'BEGIN {print int(t)}')

  printf "Estimated VRAM Requirement: ~%sGB (Weights + Context)\n" "$total_est"

  if [[ "$total_est" -gt 256 ]]; then
    printf "WARNING: Estimated VRAM usage (%s GB) exceeds the 256GB total capacity of a dual DGX Spark cluster.\n" "$total_est"
    printf "         Performance may be degraded (swapping) or initialization may fail.\n"
    printf "         Ensure your cluster supports this model size (e.g., FP8/FP4 quantization).\n"
  else
    printf "VRAM Check: OK (<256GB)\n"
  fi
}

_check_vram_requirements "$PARAMS" "$CONTEXT"

# === Architecture Detection ===
# Detects architecture on the head node to determine if platform override is needed.
ARCH=$(ssh "${SSH_OPTS[@]}" "$IP1" "uname -m" 2>/dev/null)
# Trim whitespace
ARCH=$(printf "%s" "$ARCH" | xargs)
printf "Detected architecture on %s: %s\n" "$IP1" "$ARCH"

PLATFORM_ARG=""
if [[ "$ARCH" == "x86_64" ]]; then
  PLATFORM_ARG="--platform linux/amd64"
elif [[ "$ARCH" == "aarch64" ]]; then
  printf "ARM64 detected. Using native architecture (no platform override).\n"
  PLATFORM_ARG=""
else
  # Fallback/Unknown - stick to legacy behavior
  printf "Unknown architecture: %s. Defaulting to linux/amd64.\n" "$ARCH"
  PLATFORM_ARG="--platform linux/amd64"
fi

# === Network Detection ===

# Internal: Detect high-speed network interfaces
#
# Description:
#   Attempts to detect available high-speed network interfaces (e.g., InfiniBand, Ethernet) on a remote node.
#   First tries OSPF neighbor detection via 'vtysh'.
#   Falls back to 'ibdev2netdev' if OSPF data is unavailable.
#
# Arguments:
#   $1: The IP address of the node to check.
#
# Returns:
#   A formatted string: "DETECTED_MULTI:<ifaces>", "DETECTED_SINGLE:<iface>", or "DETECTED_NONE"
function _get_network_config() {
  local ip="$1"
  # NEW: OSPF Autodetection
  # 1. Try to detect OSPF neighbors via vtysh
  local ospf_neighbors
  if ospf_neighbors=$(ssh "${SSH_OPTS[@]}" "$ip" "sudo vtysh -c 'show ip ospf neighbor' 2>/dev/null"); then
    # Parse for 'Full' state and get interface (col 6)
    local ifaces
    ifaces=$(echo "$ospf_neighbors" | grep "Full" | awk '{print $6}' | sort | uniq | tr '\n' ',' | sed 's/,$//')

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
  iface=$(ssh "${SSH_OPTS[@]}" "$ip" "ibdev2netdev 2>/dev/null | grep 'Up' | awk -F'==> ' '{print \$2}' | awk '{print \$1}' | head -n 1")

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
  local type="${conf%%:*}"
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
  ssh "${SSH_OPTS[@]}" "$ip_host" "ip -4 addr show $iface | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n 1"
}

# 1. Detect Network
printf "[1/4] Detecting high-speed network interfaces...\n"
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

# 2. Verify Connectivity and Pull Image
printf "[2/4] Verifying connectivity and pulling image...\n"
# Verify connectivity
for ip in "$IP1" "$IP2"; do
  printf "Connecting to %s...\n" "$ip"
  if ! ssh "${SSH_OPTS[@]}" "$ip" "nvidia-smi > /dev/null"; then
    printf "Error: Unable to connect to %s or nvidia-smi failed.\n" "$ip" >&2
    exit 1
  fi
done

# Pull Image Logic
# 1. Pull on Head Node (IP1)
printf "Pulling image %s on Head Node (%s)...\n" "$IMAGE" "$IP1"
if ! ssh "${SSH_OPTS[@]}" "$IP1" "echo '$NGC_API_KEY' | docker login nvcr.io -u '\$oauthtoken' --password-stdin >/dev/null 2>&1 && docker pull $PLATFORM_ARG $IMAGE"; then
  printf "Error: Failed to pull image on %s\n" "$IP1" >&2
  exit 1
fi

# 2. Check Worker Node (IP2)
printf "Checking image on Worker Node (%s)...\n" "$IP2"
if ssh "${SSH_OPTS[@]}" "$IP2" "docker image inspect $IMAGE > /dev/null 2>&1"; then
  printf "Image already exists on %s.\n" "$IP2"
else
  printf "Image missing on %s.\n" "$IP2"
  TRANSFER_SUCCESS=0

  # Try High Speed Transfer
  if [[ -n "$IFACES2" ]]; then
    FAST_IP2=$(_get_ip_from_iface "$IP2" "$IFACES2")
    if [[ -n "$FAST_IP2" ]] &&
      ssh "${SSH_OPTS[@]}" "$IP1" "command -v nc >/dev/null" &&
      ssh "${SSH_OPTS[@]}" "$IP2" "command -v nc >/dev/null"; then

      printf "Detected High-Speed IP for %s: %s\n" "$IP2" "$FAST_IP2"
      TRANSFER_PORT=12346

      # Determine nc options for auto-close
      NC_OPTS=""
      if ssh "${SSH_OPTS[@]}" "$IP1" "nc -h 2>&1 | grep -q -- -N"; then
        NC_OPTS="-N"
      elif ssh "${SSH_OPTS[@]}" "$IP1" "nc -h 2>&1 | grep -q -- -q"; then
        NC_OPTS="-q 0"
      fi
      # If no options found, we proceed without (could hang if strict, but timeout is not easily available via ssh without 'timeout' cmd)

      printf "Starting P2P transfer from %s to %s...\n" "$IP1" "$IP2"

      # Start Listener on IP2
      (
        ssh "${SSH_OPTS[@]}" "$IP2" "nc -l -p $TRANSFER_PORT | docker load"
      ) &
      LISTENER_PID=$!

      sleep 5

      # Start Sender on IP1
      if ssh "${SSH_OPTS[@]}" "$IP1" "docker save $IMAGE | nc $NC_OPTS $FAST_IP2 $TRANSFER_PORT"; then
        printf "Transfer command finished.\n"
      else
        printf "Transfer command failed.\n"
      fi

      # Wait for listener
      if wait $LISTENER_PID; then
        printf "Image transfer successful.\n"
        TRANSFER_SUCCESS=1
      else
        printf "Image transfer failed (Listener exit code).\n"
      fi
    else
      printf "Could not resolve IP for interface %s on %s or 'nc' missing.\n" "$IFACES2" "$IP2"
    fi
  else
    printf "No high-speed interface detected on %s.\n" "$IP2"
  fi

  # Fallback
  if [[ "$TRANSFER_SUCCESS" -eq 0 ]]; then
    printf "Falling back to downloading image on %s...\n" "$IP2"
    if ! ssh "${SSH_OPTS[@]}" "$IP2" "echo '$NGC_API_KEY' | docker login nvcr.io -u '\$oauthtoken' --password-stdin >/dev/null 2>&1 && docker pull $PLATFORM_ARG $IMAGE"; then
      printf "Error: Failed to pull image on %s\n" "$IP2" >&2
      exit 1
    fi
  fi
fi

# 3. Cleanup
printf "[3/4] Cleaning up previous containers...\n"
for ip in "$IP1" "$IP2"; do
  ssh "${SSH_OPTS[@]}" "$ip" "docker rm -f nim-distributed >/dev/null 2>&1 || true"
done

# 4. Launch
printf "[4/4] Launching NIM containers...\n"

# Prepare ENV vars for network
#
# Description:
#   Generates the necessary Docker environment arguments for NCCL/GLOO based on network interfaces.
#   Enables multi-rail optimizations if multiple interfaces are detected.
#
# Arguments:
#   $1: Comma-separated list of interface names.
#
# Returns:
#   A string containing Docker env vars (e.g., "-e NCCL_SOCKET_IFNAME=...").
function _get_nccl_opts() {
  local ifaces="$1"
  local opts=""
  if [[ -n "$ifaces" ]]; then
    opts="-e NCCL_SOCKET_IFNAME=$ifaces -e GLOO_SOCKET_IFNAME=$ifaces"
    if [[ "$ifaces" == *","* ]]; then
      # Multi-rail detected
      # Assuming equal HCAs, e.g., mlx5_0, mlx5_1 corresponding to interfaces
      # Enabling multi-rail optimization
      opts="$opts -e NCCL_MULTI_RAIL=1"
    fi
  fi
  printf "%s" "$opts"
}

# Common Docker Args
readonly COMMON_ARGS="$PLATFORM_ARG --runtime=nvidia --gpus all --network host --ipc=host --name nim-distributed --shm-size=16g -v ~/.cache/nim:/opt/nim/.cache"
# Add NIM_SERVER_HTTP_HOST=0.0.0.0 for safety
readonly NIM_ENV="-e NGC_API_KEY=$NGC_API_KEY -e NIM_SERVED_MODEL_NAME=$MODEL_ARG -e NIM_MULTI_NODE=1 -e NIM_TENSOR_PARALLEL_SIZE=$TP_SIZE -e NIM_PIPELINE_PARALLEL_SIZE=$PP_SIZE -e NIM_NUM_WORKERS=2 -e MASTER_ADDR=$IP1 -e MASTER_PORT=12345 -e UVICORN_HOST=0.0.0.0 -e HOST=0.0.0.0 -e NIM_HTTP_API_PORT=8000 -e NIM_SERVER_HTTP_HOST=0.0.0.0 $EXTRA_NIM_ENV"

# Launch in parallel
launch_pids=()

# Worker
printf "Starting Worker on %s...\n" "$IP2"
NET_OPTS_2=$(_get_nccl_opts "$IFACES2")
(
  # Removed --rm so logs persist
  ssh "${SSH_OPTS[@]}" "$IP2" "docker run -d $COMMON_ARGS $NIM_ENV -e NIM_NODE_RANK=1 $NET_OPTS_2 $IMAGE"
) &
launch_pids+=("$!")

sleep 10

# Head
printf "Starting Head on %s...\n" "$IP1"
NET_OPTS_1=$(_get_nccl_opts "$IFACES1")
(
  # Removed --rm so logs persist
  ssh "${SSH_OPTS[@]}" "$IP1" "docker run -d $COMMON_ARGS $NIM_ENV -e NIM_NODE_RANK=0 $NET_OPTS_1 $IMAGE"
) &
launch_pids+=("$!")

for pid in "${launch_pids[@]}"; do
  if ! wait "$pid"; then
    printf "Error: Failed to launch container on one of the nodes.\n" >&2
    exit 1
  fi
done

# === Health Check ===

# Internal: Wait for service readiness
#
# Description:
#   Polls the service health endpoint to determine when the NIM is fully ready to accept requests.
#   Also monitors container status to fail fast if the container crashes.
#
# Arguments:
#   $1: IP address of the head node.
#
# Returns:
#   0 on success, 1 on failure/timeout.
function _wait_for_service() {
  local ip="$1"
  local port=8000
  local retries=90 # 90 * 10s = 15 minutes
  local wait_time=10

  printf "Waiting for service to be ready at http://%s:%s...\n" "$ip" "$port"

  for ((i = 1; i <= retries; i++)); do
    # Check if container is still running
    if ! ssh "${SSH_OPTS[@]}" "$ip" "docker ps | grep -q nim-distributed"; then
      printf "\nError: Container nim-distributed is no longer running on %s.\n" "$ip" >&2
      printf "Fetching last 50 lines of logs:\n"
      ssh "${SSH_OPTS[@]}" "$ip" "docker logs --tail 50 nim-distributed"
      return 1
    fi

    # Try checking health endpoint
    if curl -s -o /dev/null -m 5 "http://$ip:$port/v1/health/ready"; then
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
