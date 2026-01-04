# DGX Spark - Distributed NIM

This directory contains scripts and configurations for running distributed AI models on a cluster of NVIDIA DGX Spark devices.

## Prerequisites

*   **Hardware:** Two NVIDIA DGX Spark devices.
*   **Interconnect:** Connected via 200Gbps OPSF cables (direct connect or switch).
*   **Networking:** Static IPs configured for the high-speed interface on both nodes.
*   **Access:**
    *   Passwordless SSH access from the runner machine to both DGX Spark nodes.
    *   The runner machine must be on the same LAN (management network).
*   **Software:**
    *   Docker installed on both nodes.
    *   NVIDIA Container Toolkit installed on both nodes.
    *   `NGC_API_KEY` available.

## Usage

### 1. Export NGC API Key

Ensure your NGC API Key is exported in your environment. This key is required to pull the NIM images.

```bash
export NGC_API_KEY="nvapi-..."
```

### 2. Run the Distributed Model Script

Use the `run-distributed-model.sh` script to launch the model. Provide the IP addresses of the two DGX Spark nodes.

**Note:** Use the IP addresses associated with the high-speed interconnect if possible, or ensure routing allows high bandwidth traffic.

```bash
./scripts/run-distributed-model.sh <HEAD_NODE_IP> <WORKER_NODE_IP>
```

Example:

```bash
./scripts/run-distributed-model.sh 192.168.100.10 192.168.100.11
```

### 3. Verification

The script will output the endpoint URL. You can test it using curl:

```bash
curl -X 'POST' \
  'http://<HEAD_NODE_IP>:8000/v1/chat/completions' \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{
  "model": "meta/llama-3.1-70b-instruct",
  "messages": [{"role":"user", "content":"Hello, how are you?"}],
  "max_tokens": 64
}'
```

## Configuration

The script defaults to using `meta/llama-3.1-70b-instruct` as it is the optimal "large" model that benefits from the 256GB combined memory of two DGX Spark nodes (70B FP16 ~140GB VRAM).
