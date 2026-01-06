# DGX Spark Distributed NIM Launcher - User Guide

## Overview
The `run-distributed-model.sh` script automates the deployment of distributed NVIDIA NIM (NVIDIA Inference Microservices) across two DGX Spark nodes. It handles network detection, image synchronization, parameter configuration, and service orchestration to ensure optimal performance for large language models (LLMs) and multimodal models.

## Prerequisites
Before running the script, ensure the following requirements are met:
*   **Hardware:** Two NVIDIA DGX Spark nodes connected via a high-speed interconnect (OSPF/InfiniBand/Ethernet).
*   **Software:**
    *   Docker and NVIDIA Container Toolkit installed on both nodes.
    *   `ssh`, `awk`, `grep`, `sed`, `nc`, `curl`, `pigz` available in the system PATH.
*   **Access:** Passwordless SSH configured from the runner machine to both nodes.
*   **Credentials:** `NGC_API_KEY` exported in the environment.

## Installation
You can download the script directly from the repository:

```bash
curl -O https://raw.githubusercontent.com/toxicoder/devset/main/dgx-spark/scripts/run-distributed-model.sh
chmod +x run-distributed-model.sh
```

## Usage

The script operates in three modes: **Setup**, **Start**, and **Stop**.

### 1. Setup (First Run)
To initialize the distributed cluster, provide the IP addresses of the Head Node (Node 1) and Worker Node (Node 2), and optionally a model name.

```bash
./run-distributed-model.sh [OPTIONS] <IP1> <IP2> [<MODEL_NAME>]
```

**Example:**
```bash
export NGC_API_KEY="nvapi-..."
./run-distributed-model.sh 192.168.1.10 192.168.1.11 meta/llama-3.1-70b-instruct
```
*   **IP1:** Address of the Head Node (Master).
*   **IP2:** Address of the Worker Node.
*   **MODEL_NAME:** (Optional) Model ID or Image Tag from the supported registry. Defaults to `meta/llama-3.1-70b-instruct`.

This command saves the configuration to `dgx-spark-distributed-model-config.json` for future use.

### 2. Start (Resume)
To restart the service using the previously saved configuration:

```bash
./run-distributed-model.sh start
```

### 3. Stop (Teardown)
To stop the running containers on both nodes:

```bash
./run-distributed-model.sh stop
```

## Command Reference

### Options
| Option | Description |
| :--- | :--- |
| `--dry-run` | Print the Docker commands and logic without executing them. Useful for debugging or generating deployment scripts. |
| `--force` | Bypass safety checks, such as the "Top 20" model registry validation and VRAM capacity checks. |
| `--quant <fmt>` | Force a specific quantization format (e.g., `fp8`, `fp4`, `int8`). Overrides the model's default. |

## Supported Models
The script includes a built-in registry of validated "Top 20" models optimized for DGX Spark.

| Category | Model ID | Description | Default Quant | Params (B) |
| :--- | :--- | :--- | :--- | :--- |
| **Mega** | `mega-1` | `meta/llama-3.1-405b-instruct` | fp4 | 405 |
| | `mega-2` | `nvidia/nemotron-4-340b-instruct` | fp4 | 340 |
| | `mega-3` | `deepseek-ai/deepseek-v2.5` | fp8 | 236 |
| **Large** | `large-3` | `meta/llama-3.2-90b-vision-instruct` (Vision) | fp16 | 90 |
| | `large-4` | `alibaba/qwen2-vl-72b-instruct` (Vision) | fp16 | 72 |
| **Workhorse** | `workhorse-1` | `meta/llama-3.1-70b-instruct` | fp16 | 70 |
| | `workhorse-2` | `nvidia/llama-3.1-nemotron-70b-instruct` | fp16 | 70 |
| **Efficient** | `efficient-1` | `google/gemma-2-27b-it` | fp16 | 27 |
| | `efficient-2` | `nvidia/nemotron-3-nano-30b-a3b` | fp16 | 30 |

*See the script source (`_get_model_registry`) for the full list.*

## Advanced Features

### Network Autodetection
The script automatically detects high-speed interfaces to optimize communication:
1.  **OSPF Detection:** Checks for OSPF neighbors via `vtysh` to find active links.
2.  **InfiniBand/RoCE:** Falls back to `ibdev2netdev` to identify active IB links.
3.  **Multi-Rail:** If multiple interfaces are detected, `NCCL_MULTI_RAIL` is enabled for maximum bandwidth.

### P2P Image Transfer
To avoid redundant downloads, the script checks if the Docker image exists on the Worker Node. If missing, it attempts a high-speed peer-to-peer transfer from the Head Node using `pigz` (parallel gzip) and `nc` (netcat) over the detected high-speed interface.

### VRAM Validation
Before deployment, the script queries the total VRAM of the cluster. If the requested model size exceeds available memory, it warns the user and may abort (unless `--force` is used).

### Architecture Detection
The script detects the CPU architecture (x86_64 vs aarch64) of the remote nodes and adjusts the Docker `--platform` flag accordingly, preventing QEMU emulation issues.

## Troubleshooting

*   **SSH Errors:** Ensure you can SSH into both nodes without a password (`ssh <IP> date`).
*   **"Model not found":** Use a supported model ID or use `--force` to try an arbitrary NIM image.
*   **VRAM Warnings:** If you receive a memory warning, try using `--quant fp8` or `--quant fp4` to reduce the model footprint.
*   **Network Issues:** If high-speed interfaces are not detected, the script will warn you. Ensure your OSPF or InfiniBand configuration is correct.
