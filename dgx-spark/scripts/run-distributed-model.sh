#!/bin/bash

# NVIDIA DGX Spark - Distributed NIM Launcher
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
#
# Context-Heavy Models:
# 11. nvidia/nemotron-3-nano-30b-a3b
# 12. meta/llama-4-scout
# 13. deepseek-ai/deepseek-v3.1
# 14. alibaba/qwen3-30b-a3b-thinking

# Check arguments
if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
    echo "Usage: $0 <IP1> <IP2> [<MODEL_NAME>]"
    echo "Example: $0 192.168.1.10 192.168.1.11 meta/llama-3.1-405b-instruct"
    exit 1
fi

IP1=$1
IP2=$2
MODEL_ARG=${3:-"meta/llama-3.1-70b-instruct"}

# Check for NGC_API_KEY
if [ -z "${NGC_API_KEY:-}" ]; then
    echo "Error: NGC_API_KEY environment variable is not set."
    echo "Please export your NGC API Key: export NGC_API_KEY='nvapi-...'"
    exit 1
fi

# SSH options
SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=10"

# === Model Configuration ===
declare -A MODEL_IMAGES
declare -A MODEL_PARAMS # In Billions
declare -A MODEL_CONTEXT # In K (thousands)
declare -A MODEL_TYPE # 'chat' or 'vision'

# Defaults
TP_SIZE=2
IS_VISION=0

# Mapping Logic
case "$MODEL_ARG" in
    "meta/llama-3.1-405b-instruct")
        IMAGE="nvcr.io/nim/meta/llama-3.1-405b-instruct:latest"
        PARAMS=405; CONTEXT=128
        ;;
    "nvidia/nemotron-4-340b-instruct")
        IMAGE="nvcr.io/nim/nvidia/nemotron-4-340b-instruct:latest"
        PARAMS=340; CONTEXT=128
        ;;
    "mistralai/mixtral-8x22b-instruct-v0.1")
        IMAGE="nvcr.io/nim/mistralai/mixtral-8x22b-instruct-v0.1:latest"
        PARAMS=141; CONTEXT=64
        ;;
    "meta/llama-3.1-70b-instruct")
        IMAGE="nvcr.io/nim/meta/llama-3.1-70b-instruct:latest"
        PARAMS=70; CONTEXT=128
        ;;
    "nvidia/llama-3.1-nemotron-70b-instruct")
        IMAGE="nvcr.io/nim/nvidia/llama-3.1-nemotron-70b-instruct:latest"
        PARAMS=70; CONTEXT=128
        ;;
    "alibaba/qwen2.5-72b-instruct")
        IMAGE="nvcr.io/nim/alibaba/qwen2.5-72b-instruct:latest"
        PARAMS=72; CONTEXT=128
        ;;
    "mistralai/mistral-large-instruct-2407")
        IMAGE="nvcr.io/nim/mistralai/mistral-large-instruct-2407:latest"
        PARAMS=123; CONTEXT=128
        ;;
    "deepseek-ai/deepseek-v3")
        IMAGE="nvcr.io/nim/deepseek-ai/deepseek-v3:latest"
        PARAMS=230; CONTEXT=128
        ;;
    "stabilityai/stable-diffusion-3.5-large")
        IMAGE="nvcr.io/nim/stabilityai/stable-diffusion-3.5-large:latest"
        PARAMS=8; CONTEXT=4 # Small context for vision usually
        IS_VISION=1
        ;;
    "nvidia/nemotron-nano-12b-v2-vl")
        IMAGE="nvcr.io/nim/nvidia/nemotron-nano-12b-v2-vl:latest"
        PARAMS=12; CONTEXT=32
        IS_VISION=1
        ;;
    "nvidia/nemotron-3-nano-30b-a3b")
        IMAGE="nvcr.io/nim/nvidia/nemotron-3-nano-30b-a3b:latest"
        PARAMS=30; CONTEXT=1000
        ;;
    "meta/llama-4-scout")
        IMAGE="nvcr.io/nim/meta/llama-4-scout:latest"
        PARAMS=109; CONTEXT=10000
        ;;
    "deepseek-ai/deepseek-v3.1")
        IMAGE="nvcr.io/nim/deepseek-ai/deepseek-v3.1:latest"
        PARAMS=671; CONTEXT=128
        ;;
    "alibaba/qwen3-30b-a3b-thinking")
        IMAGE="nvcr.io/nim/alibaba/qwen3-30b-a3b-thinking:latest"
        PARAMS=30; CONTEXT=1000
        ;;
    *)
        echo "Unknown model: $MODEL_ARG"
        echo "Using provided name as image name suffix or custom mapping not found."
        echo "Defaulting to generic configuration."
        IMAGE="nvcr.io/nim/$MODEL_ARG:latest"
        PARAMS=10; CONTEXT=4 # Safe defaults to avoid warning
        ;;
esac

echo "=== NVIDIA DGX Spark Distributed NIM Launcher ==="
echo "Nodes: $IP1 (Head), $IP2 (Worker)"
echo "Model: $MODEL_ARG"
echo "Image: $IMAGE"
echo "Type: $(if [ "$IS_VISION" -eq 1 ]; then echo "Vision/Multimodal"; else echo "LLM"; fi)"
echo "================================================"

# === VRAM Estimation Check ===
check_vram_requirements() {
    local p_b=$1
    local c_k=$2

    # FP16 Weights: params * 2 bytes
    local weights_gb=$(echo "$p_b * 2" | bc)

    # KV Cache Estimation (Rough Heuristic)
    # Assume: layers = p_b, hidden = 4096 (avg), GQA factor reduces by 4x?
    # KV = 2 * layers * hidden * context * 2 bytes
    # To keep it simple: Add 0.5 GB per 1B params per 10k context?
    # Let's use the prompt's formula guidance roughly:
    # layers approx p_b * 1.5 (for small) or less for huge.
    # Let's just use a simpler check:
    # If Params > 120 (240GB) -> Warn
    # If Context > 200k -> Warn

    local total_est=$weights_gb
    # Add buffer for KV
    if [ "$c_k" -gt 128 ]; then
        # Huge context adds significant memory
        local kv_est=$(echo "$c_k * 0.5" | bc) # Very rough: 0.5GB per 1k context? No.
        # 128k context on 70B is ~40GB. 1M context is ~300GB.
        # So 1M context (1000k) ~ 300GB.
        # Factor: 0.3 GB per k context.
        local kv_add=$(echo "$c_k * 0.3" | bc)
        total_est=$(echo "$total_est + $kv_add" | bc)
    else
        # Standard context, assume +20% overhead
        total_est=$(echo "$total_est * 1.2" | bc)
    fi

    # Round to integer
    total_est=${total_est%.*}

    echo "Estimated VRAM Requirement: ~${total_est}GB (Weights + Context)"

    if [ "$total_est" -gt 256 ]; then
        echo "WARNING: Estimated VRAM usage ($total_est GB) exceeds the 256GB total capacity of a dual DGX Spark cluster."
        echo "         Performance may be degraded (swapping) or initialization may fail."
        echo "         Ensure your cluster supports this model size (e.g., FP8/FP4 quantization)."
    else
        echo "VRAM Check: OK (<256GB)"
    fi
}

check_vram_requirements $PARAMS $CONTEXT

# === Network Detection ===
get_network_config() {
    local ip=$1
    # NEW: OSPF Autodetection
    # 1. Try to detect OSPF neighbors via vtysh
    local ospf_neighbors
    if ospf_neighbors=$(ssh $SSH_OPTS "$ip" "sudo vtysh -c 'show ip ospf neighbor' 2>/dev/null"); then
        # Parse for 'Full' state and get interface (col 6)
        local ifaces
        ifaces=$(echo "$ospf_neighbors" | grep "Full" | awk '{print $6}' | sort | uniq | tr '\n' ',' | sed 's/,$//')

        if [ -n "$ifaces" ]; then
            # Check if we have multiple
            if [[ "$ifaces" == *","* ]]; then
                echo "DETECTED_MULTI: $ifaces"
                return
            else
                echo "DETECTED_SINGLE: $ifaces"
                return
            fi
        fi
    fi

    # 2. Fallback to ibdev2netdev
    local iface
    iface=$(ssh $SSH_OPTS "$ip" "ibdev2netdev 2>/dev/null | grep 'Up' | awk -F'==> ' '{print \$2}' | awk '{print \$1}' | head -n 1")

    if [ -n "$iface" ]; then
        echo "DETECTED_SINGLE: $iface"
    else
        echo "DETECTED_NONE"
    fi
}

# 1. Verify Connectivity and Pull Image
echo "[1/4] Verifying connectivity and pulling image..."
for IP in "$IP1" "$IP2"; do
    echo "Connecting to $IP..."
    if ! ssh $SSH_OPTS "$IP" "nvidia-smi > /dev/null"; then
        echo "Error: Unable to connect to $IP or nvidia-smi failed."
        exit 1
    fi
    # Pull image
    echo "Pulling image $IMAGE on $IP..."
    ssh $SSH_OPTS "$IP" "echo '$NGC_API_KEY' | docker login nvcr.io -u \$oauthtoken --password-stdin >/dev/null 2>&1 && docker pull $IMAGE" &
done
wait

# 2. Detect Network
echo "[2/4] Detecting high-speed network interfaces..."
NET_CONF_1=$(get_network_config "$IP1")
NET_CONF_2=$(get_network_config "$IP2")

# Helper to parse the detection result
parse_net_conf() {
    local conf=$1
    local type=${conf%%:*}
    local val=${conf#*:}
    echo "$val"
}

IFACES1=$(parse_net_conf "$NET_CONF_1")
IFACES2=$(parse_net_conf "$NET_CONF_2")

echo "Node 1 Interfaces: $IFACES1"
echo "Node 2 Interfaces: $IFACES2"

# 3. Cleanup
echo "[3/4] Cleaning up previous containers..."
for IP in "$IP1" "$IP2"; do
    ssh $SSH_OPTS "$IP" "docker rm -f nim-distributed || true"
done

# 4. Launch
echo "[4/4] Launching NIM containers..."

# Prepare ENV vars for network
get_nccl_opts() {
    local ifaces=$1
    local opts=""
    if [ -n "$ifaces" ]; then
        opts="-e NCCL_SOCKET_IFNAME=$ifaces -e GLOO_SOCKET_IFNAME=$ifaces"
        if [[ "$ifaces" == *","* ]]; then
            # Multi-rail detected
            # Assuming equal HCAs, e.g., mlx5_0, mlx5_1 corresponding to interfaces
            # Enabling multi-rail optimization
            opts="$opts -e NCCL_MULTI_RAIL=1"
        fi
    fi
    echo "$opts"
}

# Common Docker Args
COMMON_ARGS="--gpus all --network host --ipc=host --name nim-distributed --shm-size=16g -v ~/.cache/nim:/opt/nim/.cache"
NIM_ENV="-e NGC_API_KEY=$NGC_API_KEY -e NIM_SERVED_MODEL_NAME=$MODEL_ARG -e NIM_MULTI_NODE=1 -e NIM_TENSOR_PARALLEL_SIZE=$TP_SIZE -e NIM_NUM_WORKERS=2 -e MASTER_ADDR=$IP1 -e MASTER_PORT=12345"

# Worker
echo "Starting Worker on $IP2..."
NET_OPTS_2=$(get_nccl_opts "$IFACES2")
ssh $SSH_OPTS "$IP2" "docker run -d --rm $COMMON_ARGS $NIM_ENV -e NIM_NODE_RANK=1 $NET_OPTS_2 $IMAGE" &

sleep 10

# Head
echo "Starting Head on $IP1..."
NET_OPTS_1=$(get_nccl_opts "$IFACES1")
ssh $SSH_OPTS "$IP1" "docker run -d --rm $COMMON_ARGS $NIM_ENV -e NIM_NODE_RANK=0 $NET_OPTS_1 $IMAGE" &

wait

echo "---------------------------------------------------"
echo "Distributed NIM launched."
if [ "$IS_VISION" -eq 1 ]; then
    echo "Endpoint: http://$IP1:8000/v1/images/generations (or model specific)"
else
    echo "Endpoint: http://$IP1:8000/v1/chat/completions"
fi
echo "Logs Node 1: ssh $IP1 'docker logs -f nim-distributed'"
echo "Logs Node 2: ssh $IP2 'docker logs -f nim-distributed'"
echo "---------------------------------------------------"
