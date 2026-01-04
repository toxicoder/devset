#!/bin/bash

# NVIDIA DGX Spark - Distributed NIM Launcher
#
# This script spins up a distributed Llama 3.1 70B Instruct NIM across two DGX Spark nodes.
# It assumes:
# 1. Passwordless SSH is configured between the runner and both nodes.
# 2. NGC_API_KEY is exported in the environment.
# 3. Docker and NVIDIA Container Toolkit are installed on both nodes.
# 4. The nodes are connected via a high-speed interconnect (200Gbps OPSF).

set -euo pipefail

# Check arguments
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <IP1> <IP2>"
    echo "Example: $0 192.168.1.10 192.168.1.11"
    exit 1
fi

IP1=$1
IP2=$2

# Check for NGC_API_KEY
if [ -z "${NGC_API_KEY:-}" ]; then
    echo "Error: NGC_API_KEY environment variable is not set."
    echo "Please export your NGC API Key: export NGC_API_KEY='nvapi-...'"
    exit 1
fi

# Define the model and image
# Targeting Llama 3.1 70B as the largest model feasible on 2x DGX Spark (2x128GB = 256GB RAM)
# 70B FP16 requires ~140GB, which exceeds single node capacity but fits in two.
MODEL_NAME="meta/llama-3.1-70b-instruct"
IMAGE_NAME="nvcr.io/nim/meta/llama-3.1-70b-instruct:latest"

# SSH options
SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=10"

echo "=== NVIDIA DGX Spark Distributed NIM Launcher ==="
echo "Nodes: $IP1 (Head), $IP2 (Worker)"
echo "Model: $MODEL_NAME"
echo "================================================"

# Function to get high-speed interface name on a remote host
get_high_speed_interface() {
    local ip=$1
    # Try to find the interface that is UP using ibdev2netdev (common on DGX)
    # or fallback to detecting an interface with high speed or specific naming (enp*).
    # DGX Spark docs mention `ibdev2netdev` showing "enP2p1s0f1np1 (Up)"
    local iface
    iface=$(ssh $SSH_OPTS "$ip" "ibdev2netdev 2>/dev/null | grep 'Up' | awk -F'==> ' '{print \$2}' | awk '{print \$1}' | head -n 1")

    if [ -z "$iface" ]; then
        # Fallback: try to find an interface that is not the management one (assuming provided IP is management)
        # This is risky, so if detection fails, we might rely on NCCL auto-detection.
        echo ""
    else
        echo "$iface"
    fi
}

# 1. Verify Connectivity and setup
echo "[1/4] Verifying connectivity and pulling image..."

for IP in "$IP1" "$IP2"; do
    echo "Connecting to $IP..."
    if ! ssh $SSH_OPTS "$IP" "nvidia-smi > /dev/null"; then
        echo "Error: Unable to connect to $IP or nvidia-smi failed."
        exit 1
    fi

    # Authenticate Docker with NGC
    echo "Logging into NGC registry on $IP..."
    ssh $SSH_OPTS "$IP" "echo '$NGC_API_KEY' | docker login nvcr.io -u \$oauthtoken --password-stdin"

    # Pull image
    echo "Pulling image $IMAGE_NAME on $IP..."
    ssh $SSH_OPTS "$IP" "docker pull $IMAGE_NAME" &
done
wait

# 2. Detect Network Interfaces for NCCL
# We need the interface name for the high-speed interconnect (200Gbps).
echo "[2/4] Detecting high-speed network interfaces..."
IFACE1=$(get_high_speed_interface "$IP1")
IFACE2=$(get_high_speed_interface "$IP2")

# If we found interfaces, we use them. If not, we omit the var and let NCCL decide (though manual is safer for Docker).
NCCL_ENV_VARS=""
if [ -n "$IFACE1" ] && [ -n "$IFACE2" ]; then
    echo "Node 1 ($IP1) High-Speed Interface: $IFACE1"
    echo "Node 2 ($IP2) High-Speed Interface: $IFACE2"
    # We assume symmetric naming often, but we pass specific iface to each node command.
else
    echo "Warning: Could not auto-detect high-speed interface via ibdev2netdev."
    echo "NCCL will attempt to auto-detect the best interface."
fi

# 3. Generate Random Secret for vLLM/NIM coordination if needed
# For NIM/vLLM multi-node, we often need a shared ID or port.
PORT=8000
NIM_PORT=8000
# Ensure ports are free
echo "[3/4] Cleaning up previous containers..."
for IP in "$IP1" "$IP2"; do
    ssh $SSH_OPTS "$IP" "docker rm -f nim-distributed || true"
done

# 4. Launch Distributed Containers
# We use vLLM backend configuration which NIM supports.
# Head Node (IP1)
echo "[4/4] Launching NIM containers..."

# Shared Environment Variables
# NCCL_P2P_DISABLE=0 is default, but ensuring it.
# NIM_SERVED_MODEL_NAME must match
# NIM_MULTI_NODE=1 tells NIM to expect multi-node setup
# MASTER_ADDR and MASTER_PORT are crucial for coordination.

# Launch Worker (Node 2)
echo "Starting Worker on $IP2..."
CMD_OPTS="-e NCCL_SOCKET_IFNAME=$IFACE2 -e GLOO_SOCKET_IFNAME=$IFACE2"
if [ -z "$IFACE2" ]; then CMD_OPTS=""; fi

ssh $SSH_OPTS "$IP2" "docker run -d --rm \
    --gpus all \
    --network host \
    --ipc=host \
    --name nim-distributed \
    --shm-size=16g \
    -e NGC_API_KEY=$NGC_API_KEY \
    -e NIM_SERVED_MODEL_NAME=$MODEL_NAME \
    -e NIM_MULTI_NODE=1 \
    -e NIM_TENSOR_PARALLEL_SIZE=2 \
    -e NIM_NODE_RANK=1 \
    -e NIM_NUM_WORKERS=2 \
    -e MASTER_ADDR=$IP1 \
    -e MASTER_PORT=12345 \
    $CMD_OPTS \
    -v ~/.cache/nim:/opt/nim/.cache \
    $IMAGE_NAME" &

# Wait a moment for worker to initialize networking
sleep 10

# Launch Head (Node 1)
echo "Starting Head on $IP1..."
CMD_OPTS="-e NCCL_SOCKET_IFNAME=$IFACE1 -e GLOO_SOCKET_IFNAME=$IFACE1"
if [ -z "$IFACE1" ]; then CMD_OPTS=""; fi

ssh $SSH_OPTS "$IP1" "docker run -d --rm \
    --gpus all \
    --network host \
    --ipc=host \
    --name nim-distributed \
    --shm-size=16g \
    -e NGC_API_KEY=$NGC_API_KEY \
    -e NIM_SERVED_MODEL_NAME=$MODEL_NAME \
    -e NIM_MULTI_NODE=1 \
    -e NIM_TENSOR_PARALLEL_SIZE=2 \
    -e NIM_NODE_RANK=0 \
    -e NIM_NUM_WORKERS=2 \
    -e MASTER_ADDR=$IP1 \
    -e MASTER_PORT=12345 \
    $CMD_OPTS \
    -v ~/.cache/nim:/opt/nim/.cache \
    $IMAGE_NAME" &

wait

echo "---------------------------------------------------"
echo "Distributed NIM launched."
echo "Head Node: http://$IP1:$NIM_PORT/v1/chat/completions"
echo "Logs Node 1: ssh $IP1 'docker logs -f nim-distributed'"
echo "Logs Node 2: ssh $IP2 'docker logs -f nim-distributed'"
echo "---------------------------------------------------"
