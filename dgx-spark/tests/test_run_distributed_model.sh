#!/bin/bash
# Test script for run-distributed-model.sh

export TEST_DIR=$(mktemp -d)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ORIGINAL_SCRIPT="$SCRIPT_DIR/../scripts/run-distributed-model.sh"

# Copy script to temp dir to avoid polluting source with config files
cp "$ORIGINAL_SCRIPT" "$TEST_DIR/run-distributed-model.sh"
# Copy models.db if it exists
if [ -f "$SCRIPT_DIR/../scripts/models.db" ]; then
    cp "$SCRIPT_DIR/../scripts/models.db" "$TEST_DIR/models.db"
fi
TARGET_SCRIPT="$TEST_DIR/run-distributed-model.sh"
chmod +x "$TARGET_SCRIPT"

# Mock utilities
setup_mocks() {
    export PATH="$TEST_DIR:$PATH"

    # Mock ssh
    cat << 'EOF' > "$TEST_DIR/ssh"
#!/bin/bash
ARGS="$*"

# Handle bash -s (Heredoc) execution
if [[ "$ARGS" == *"bash -s"* ]]; then
    SCRIPT_CONTENT=$(cat -)

    # Check for docker login / pull failures in the script
    if [[ "$SCRIPT_CONTENT" == *"docker login"* ]] || [[ "$SCRIPT_CONTENT" == *"docker pull"* ]]; then
        if [[ -n "${MOCK_SSH_FAIL_PULL_IP:-}" ]] && [[ "$ARGS" == *"${MOCK_SSH_FAIL_PULL_IP}"* ]]; then
            echo "Mocking pull failure on $MOCK_SSH_FAIL_PULL_IP (Heredoc)"
            exit 1
        fi
        if [[ -n "${MOCK_SSH_DELAY_PULL_IP:-}" ]] && [[ "$ARGS" == *"${MOCK_SSH_DELAY_PULL_IP}"* ]]; then
            sleep 2
        fi
    fi

    # Check for TRT compilation script
    if [[ "$SCRIPT_CONTENT" == *"trtllm-convert-checkpoint"* ]]; then
         # We can simulate failure if needed, but default success
         exit 0
    fi

    exit 0
fi

if [[ "$ARGS" == *"uname -m"* ]]; then
    if [[ -n "${MOCK_ARCH}" ]]; then
        echo "${MOCK_ARCH}"
    else
        echo "x86_64"
    fi
    exit 0
elif [[ "$ARGS" == *"docker inspect -f '{{.Architecture}}'"* ]]; then
    if [[ -n "${MOCK_IMG_ARCH:-}" ]]; then
        echo "${MOCK_IMG_ARCH}"
    fi
    exit 0
elif [[ "$ARGS" == *"nvidia-smi --query-gpu=memory.total"* ]]; then
    if [[ -n "${MOCK_VRAM_MB}" ]]; then
        echo "${MOCK_VRAM_MB}"
    else
        # Default: 80GB (81920 MB)
        echo "81920"
    fi
    exit 0
elif [[ "$ARGS" == *"nvidia-smi"* ]]; then
    exit 0
elif [[ "$ARGS" == *"docker login"* ]]; then
    if [[ -n "${MOCK_SSH_FAIL_PULL_IP:-}" ]] && [[ "$ARGS" == *"${MOCK_SSH_FAIL_PULL_IP}"* ]]; then
        echo "Mocking pull failure on $MOCK_SSH_FAIL_PULL_IP"
        exit 1
    fi
    if [[ -n "${MOCK_SSH_DELAY_PULL_IP:-}" ]] && [[ "$ARGS" == *"${MOCK_SSH_DELAY_PULL_IP}"* ]]; then
        sleep 2
    fi
    exit 0
elif [[ "$ARGS" == *"docker pull"* ]]; then
    exit 0
elif [[ "$ARGS" == *"docker inspect -f '{{.State.Running}}'"* ]]; then
    if [[ -n "${MOCK_CONTAINER_CRASH}" ]]; then
        echo "false"
    else
        echo "true"
    fi
    exit 0
elif [[ "$ARGS" == *"docker inspect"* ]]; then
    if [[ -n "${MOCK_IMAGE_MISSING}" ]]; then
        exit 1
    fi
    exit 0
elif [[ "$ARGS" == *"nc -l"* ]] || [[ "$ARGS" == *"nc -N"* ]] || [[ "$ARGS" == *"nc "* ]]; then
    if [[ -n "${MOCK_TRANSFER_FAIL}" ]]; then
        exit 1
    fi
    exit 0
elif [[ "$ARGS" == *"vtysh"* ]]; then
    echo "Neighbor ID     Pri State           Dead Time Address         Interface            RXmtL RqstL DBsmL"
    echo "10.0.0.2          1 Full/Backup       34.123s 10.0.0.2        eth0:100               0     0     0"
    exit 0
elif [[ "$*" == *"ibdev2netdev"* ]]; then
    echo "mlx5_0 port 1 ==> ib0 (Up)"
    exit 0
elif [[ "$*" == *"docker rm"* ]]; then
    echo "docker rm called" >> "$TEST_DIR/docker_rm.log"
    exit 0
elif [[ "$*" == *"docker run"* ]]; then
    echo "docker run called with args: $*" >> "$TEST_DIR/docker_run.log"
    echo "container_id"
    exit 0
elif [[ "$*" == *"docker logs"* ]]; then
    echo "Mock logs"
    exit 0
elif [[ "$ARGS" == *"ip -4 addr show"* ]]; then
    echo "inet 10.0.0.2"
    exit 0
else
    exit 0
fi
EOF
    chmod +x "$TEST_DIR/ssh"

    # Mock bc
    cat << 'EOF' > "$TEST_DIR/bc"
#!/bin/bash
read -r input
if [[ "$input" == *"*"* ]]; then
   echo 10
else
   echo 0
fi
EOF
    chmod +x "$TEST_DIR/bc"

    # Mock docker
    cat << 'EOF' > "$TEST_DIR/docker"
#!/bin/bash
exit 0
EOF
    chmod +x "$TEST_DIR/docker"

    # Mock nc
    cat << 'EOF' > "$TEST_DIR/nc"
#!/bin/bash
exit 0
EOF
    chmod +x "$TEST_DIR/nc"

    # Mock curl
    cat << 'EOF' > "$TEST_DIR/curl"
#!/bin/bash
exit 0
EOF
    chmod +x "$TEST_DIR/curl"
}

run_test() {
    local desc="$1"
    shift
    echo "Running test: $desc"

    (
        export NGC_API_KEY="test-key"
        # Default to 'n' for interactive prompt in tests
        echo "n" | "$@"
    )
    local status=$?
    if [ $status -eq 0 ]; then
        echo "PASS"
    else
        echo "FAIL"
    fi
}

setup_mocks

echo "Target Script: $TARGET_SCRIPT"

# Test 1: Basic execution with arguments
run_test "Basic execution" "$TARGET_SCRIPT" "10.0.0.1" "10.0.0.2" "meta/llama-3.3-70b-instruct"

# Test 2: Missing arguments
echo "Running test: Missing arguments"
( "$TARGET_SCRIPT" 2>/dev/null )
if [ $? -eq 1 ]; then
    echo "PASS"
else
    echo "FAIL: Script should exit 1 on missing args"
fi

# Test 3: Image pull failure on one node
echo "Running test: Image pull failure on one node (with transfer failure)"
(
    export MOCK_SSH_FAIL_PULL_IP="10.0.0.2"
    export MOCK_SSH_DELAY_PULL_IP="10.0.0.1"
    export MOCK_IMAGE_MISSING=1
    export MOCK_TRANSFER_FAIL=1
    export NGC_API_KEY="test-key"
    OUTPUT=$("$TARGET_SCRIPT" "10.0.0.1" "10.0.0.2" "meta/llama-3.3-70b-instruct" 2>&1)
    EXIT_CODE=$?

    if [ $EXIT_CODE -eq 1 ]; then
        if echo "$OUTPUT" | grep -q "Failed to pull image on 10.0.0.2"; then
            echo "PASS"
        else
             echo "FAIL: Expected error message not found. Output:"
             echo "$OUTPUT"
             exit 1
        fi
    else
        echo "FAIL: Script should exit 1 on image pull failure. Exit code: $EXIT_CODE"
        exit 1
    fi
)
if [ $? -ne 0 ]; then exit 1; fi

# Test 18b: Image Override
echo "Running test: Image Override"
(
    rm -f "$TEST_DIR/docker_run.log"
    export NGC_API_KEY="test-key"
    echo "n" | "$TARGET_SCRIPT" --image my-custom-image:latest "10.0.0.1" "10.0.0.2" "meta/llama-3.3-70b-instruct" >/dev/null

    LOG_CONTENT=$(cat "$TEST_DIR/docker_run.log")

    # The script should try to run my-custom-image:latest
    if echo "$LOG_CONTENT" | grep -q "my-custom-image:latest"; then
        echo "PASS"
    else
        echo "FAIL: Did not find usage of my-custom-image:latest. Log:"
        echo "$LOG_CONTENT"
        exit 1
    fi
)
if [ $? -ne 0 ]; then exit 1; fi

# Test 18c: Custom HF Model Default to TRT-LLM
echo "Running test: Custom HF Model Default to TRT-LLM"
(
    rm -f "$TEST_DIR/docker_run.log"
    export NGC_API_KEY="test-key"
    export HF_TOKEN="test-token"
    # Using dry-run to skip actual build logic which requires mocks for trtllm-build
    OUTPUT=$(echo "n" | "$TARGET_SCRIPT" --dry-run "10.0.0.1" "10.0.0.2" "https://huggingface.co/MyOrg/MyModel" 2>&1)

    if echo "$OUTPUT" | grep -q "Defaulting to TensorRT-LLM Engine Build"; then
        if echo "$OUTPUT" | grep -q "Container: nvcr.io/nvidia/tensorrt-llm:25.12-py3"; then
            if echo "$OUTPUT" | grep -q "HF_TOKEN=test-token"; then
                echo "PASS"
            else
                echo "FAIL: HF_TOKEN not passed to container in TRT-LLM mode. Output:"
                echo "$OUTPUT"
                exit 1
            fi
        else
             echo "FAIL: Expected TRT-LLM release image. Output:"
             echo "$OUTPUT"
             exit 1
        fi
    else
        echo "FAIL: Did not default to TRT-LLM for custom HF model. Output:"
        echo "$OUTPUT"
        exit 1
    fi
)
if [ $? -ne 0 ]; then exit 1; fi

# Test 23: Verify HF_TOKEN passed in NIM/VLLM mode
echo "Running test: Verify HF_TOKEN passed in NIM/VLLM mode"
(
    rm -f "$TEST_DIR/docker_run.log"
    export NGC_API_KEY="test-key"
    export HF_TOKEN="test-token"
    echo "n" | "$TARGET_SCRIPT" "10.0.0.1" "10.0.0.2" "meta/llama-3.3-70b-instruct" >/dev/null

    LOG_CONTENT=$(cat "$TEST_DIR/docker_run.log")

    if echo "$LOG_CONTENT" | grep -q "HF_TOKEN=test-token"; then
        echo "PASS"
    else
        echo "FAIL: HF_TOKEN not found in docker run command for NIM. Log:"
        echo "$LOG_CONTENT"
        exit 1
    fi
)
if [ $? -ne 0 ]; then exit 1; fi

# Test 22: Platform Mismatch (ARM64 Host, AMD64 Image) - Should Fail
echo "Running test: Platform Mismatch Failure"
(
    export NGC_API_KEY="test-key"
    export MOCK_ARCH="aarch64"
    export MOCK_IMG_ARCH="amd64"

    OUTPUT=$(echo "n" | "$TARGET_SCRIPT" "10.0.0.1" "10.0.0.2" "meta/llama-3.3-70b-instruct" 2>&1)
    EXIT_CODE=$?

    if [ $EXIT_CODE -eq 1 ]; then
        if echo "$OUTPUT" | grep -q "Image architecture (amd64) is incompatible with Host architecture (arm64)"; then
            echo "PASS"
        else
            echo "FAIL: Expected mismatch error not found. Output:"
            echo "$OUTPUT"
            exit 1
        fi
    else
        echo "FAIL: Script should have failed on platform mismatch. Exit code: $EXIT_CODE"
        exit 1
    fi
)
if [ $? -ne 0 ]; then exit 1; fi

# Test 11b: VRAM Detection Failure (0 GB)
echo "Running test: VRAM Detection Failure (0 GB)"
(
    export NGC_API_KEY="test-key"
    export MOCK_VRAM_MB="0" # Simulating 0 VRAM

    OUTPUT=$(echo "n" | "$TARGET_SCRIPT" "10.0.0.1" "10.0.0.2" "meta/llama-3.3-70b-instruct" 2>&1)
    EXIT_CODE=$?

    if [ $EXIT_CODE -eq 1 ]; then
        if echo "$OUTPUT" | grep -q "VRAM detection failed or total is 0 GB"; then
             echo "PASS"
        else
            echo "FAIL: Expected VRAM failure message not found. Output:"
            echo "$OUTPUT"
            exit 1
        fi
    else
        echo "FAIL: Script should fail when VRAM is 0. Exit code: $EXIT_CODE"
        exit 1
    fi
)
if [ $? -ne 0 ]; then exit 1; fi

# Test 11c: VRAM Detection Failure (0 GB) with --force
echo "Running test: VRAM Detection Failure (0 GB) with --force"
(
    export NGC_API_KEY="test-key"
    export MOCK_VRAM_MB="0" # Simulating 0 VRAM

    OUTPUT=$(echo "n" | "$TARGET_SCRIPT" --force "10.0.0.1" "10.0.0.2" "meta/llama-3.3-70b-instruct" 2>&1)
    EXIT_CODE=$?

    if [ $EXIT_CODE -eq 0 ]; then
        if echo "$OUTPUT" | grep -q "Force enabled, proceeding..."; then
             echo "PASS"
        else
             echo "FAIL: Expected force warning not found. Output:"
             echo "$OUTPUT"
             exit 1
        fi
    else
        echo "FAIL: Script should succeed with --force even if VRAM is 0. Exit code: $EXIT_CODE"
        echo "$OUTPUT"
        exit 1
    fi
)
if [ $? -ne 0 ]; then exit 1; fi

# Test 4: Static Analysis for Correct Escaping
echo "Running test: Static Analysis for Correct Escaping"
if grep -F "'\\\$oauthtoken'" "$TARGET_SCRIPT" >/dev/null; then
    echo "PASS"
else
    if grep -F "'\$oauthtoken'" "$TARGET_SCRIPT" >/dev/null; then
        echo "PASS"
    else
        echo "FAIL: Could not find correct escaping for oauthtoken"
        exit 1
    fi
fi

# Test 4b: Static Analysis for ZSH Safe huggingface_hub[cli] escaping
echo "Running test: Static Analysis for huggingface_hub[cli] escaping"
if grep -qF 'pip install -U "huggingface_hub[cli]"' "$TARGET_SCRIPT"; then
    echo "PASS"
elif grep -qF 'pip install -U \"huggingface_hub[cli]\"' "$TARGET_SCRIPT"; then
    echo "PASS"
else
    echo "FAIL: huggingface_hub[cli] not correctly escaped with double quotes"
    exit 1
fi

# Test 4c: Verify removal of deprecated --local-dir-use-symlinks argument
echo "Running test: Verify absence of deprecated --local-dir-use-symlinks"
if grep -F -- "--local-dir-use-symlinks" "$TARGET_SCRIPT"; then
    echo "FAIL: Found deprecated argument --local-dir-use-symlinks in script"
    exit 1
else
    echo "PASS"
fi

# Test 5: Verify Network and Port Configuration
echo "Running test: Verify Network and Port Configuration"
(
    rm -f "$TEST_DIR/docker_run.log"
    export NGC_API_KEY="test-key"
    echo "n" | "$TARGET_SCRIPT" "10.0.0.1" "10.0.0.2" "meta/llama-3.3-70b-instruct" >/dev/null

    LOG_CONTENT=$(cat "$TEST_DIR/docker_run.log")

    FAILED=0
    if ! echo "$LOG_CONTENT" | grep -q "\-\-network host"; then
        echo "Check --network host: FAIL"
        FAILED=1
    fi
    if ! echo "$LOG_CONTENT" | grep -q "UVICORN_HOST=0.0.0.0"; then
        echo "Check UVICORN_HOST: FAIL"
        FAILED=1
    fi
    if ! echo "$LOG_CONTENT" | grep -q "HOST=0.0.0.0"; then
        echo "Check HOST: FAIL"
        FAILED=1
    fi
    if ! echo "$LOG_CONTENT" | grep -q "NIM_HTTP_API_PORT=8000"; then
        echo "Check NIM_HTTP_API_PORT: FAIL"
        FAILED=1
    fi
    if ! echo "$LOG_CONTENT" | grep -q "\-\-runtime=nvidia"; then
        echo "Check --runtime=nvidia: FAIL"
        FAILED=1
    fi

    if [ $FAILED -eq 0 ]; then
        echo "PASS"
    else
        echo "FAIL: One or more checks failed"
        exit 1
    fi
)
if [ $? -ne 0 ]; then exit 1; fi

# Test 6: ARM64 Architecture Detection
echo "Running test: ARM64 Architecture Detection"
(
    rm -f "$TEST_DIR/docker_run.log"
    export NGC_API_KEY="test-key"
    export MOCK_ARCH="aarch64"
    echo "n" | "$TARGET_SCRIPT" "10.0.0.1" "10.0.0.2" "meta/llama-3.3-70b-instruct" >/dev/null

    LOG_CONTENT=$(cat "$TEST_DIR/docker_run.log")
    if echo "$LOG_CONTENT" | grep -q "\-\-platform linux/arm64"; then
        echo "PASS"
    else
        echo "FAIL: Did not find --platform linux/arm64 on ARM64 host. Found: $LOG_CONTENT"
        exit 1
    fi
)
if [ $? -ne 0 ]; then exit 1; fi

# Test 7: P2P Transfer Success
echo "Running test: P2P Transfer Success"
(
    export MOCK_IMAGE_MISSING=1
    export NGC_API_KEY="test-key"
    OUTPUT=$(echo "n" | "$TARGET_SCRIPT" "10.0.0.1" "10.0.0.2" "meta/llama-3.3-70b-instruct" 2>&1)
    if echo "$OUTPUT" | grep -q "Using High-Speed P2P Transfer"; then
        echo "PASS"
    else
        echo "FAIL: P2P transfer message not found"
        exit 1
    fi
)
if [ $? -ne 0 ]; then exit 1; fi

# Test 8: Verify VLLM Backend for Nemotron Nano
echo "Running test: Verify VLLM Backend for Nemotron Nano"
(
    rm -f "$TEST_DIR/docker_run.log"
    export NGC_API_KEY="test-key"
    echo "n" | "$TARGET_SCRIPT" "10.0.0.1" "10.0.0.2" "nvidia/nemotron-3-nano-30b-a3b" >/dev/null
    LOG_CONTENT=$(cat "$TEST_DIR/docker_run.log")
    if echo "$LOG_CONTENT" | grep -q "VLLM_ATTENTION_BACKEND=FLASHINFER"; then
        echo "PASS"
    else
        echo "FAIL: Found: $LOG_CONTENT"
        exit 1
    fi
)
if [ $? -ne 0 ]; then exit 1; fi

# Test 10: Insufficient VRAM (Failure)
echo "Running test: Insufficient VRAM (Failure)"
(
    export NGC_API_KEY="test-key"
    # 110GB VRAM per node * 2 = 220GB total.
    # Model: meta/llama-3.1-405b-instruct (405B params) requires > 230GB (heuristic)
    export MOCK_VRAM_MB="112640" # 110 * 1024

    OUTPUT=$(echo "n" | "$TARGET_SCRIPT" "10.0.0.1" "10.0.0.2" "meta/llama-3.1-405b-instruct" 2>&1)
    EXIT_CODE=$?

    if [ $EXIT_CODE -eq 1 ]; then
        if echo "$OUTPUT" | grep -q "exceeds detected VRAM"; then
            echo "PASS"
        else
            echo "FAIL: Expected abort message not found. Output:"
            echo "$OUTPUT"
            exit 1
        fi
    else
        echo "FAIL: Script should have failed due to low VRAM. Exit code: $EXIT_CODE"
        exit 1
    fi
)
if [ $? -ne 0 ]; then exit 1; fi

# Test 11: Insufficient VRAM with --force (Success)
echo "Running test: Insufficient VRAM with --force (Success)"
(
    export NGC_API_KEY="test-key"
    export MOCK_VRAM_MB="40960"

    OUTPUT=$(echo "n" | "$TARGET_SCRIPT" --force "10.0.0.1" "10.0.0.2" "meta/llama-3.1-405b-instruct" 2>&1)
    EXIT_CODE=$?

    if [ $EXIT_CODE -eq 0 ]; then
        if echo "$OUTPUT" | grep -q "Force enabled. Proceeding"; then
            echo "PASS"
        else
            echo "FAIL: Expected force message not found. Output:"
            echo "$OUTPUT"
            exit 1
        fi
    else
        echo "FAIL: Script failed despite --force. Output:"
        echo "$OUTPUT"
        exit 1
    fi
)
if [ $? -ne 0 ]; then exit 1; fi

# Test 12: Unknown Model (Failure)
echo "Running test: Unknown Model (Failure)"
(
    export NGC_API_KEY="test-key"
    OUTPUT=$(echo "n" | "$TARGET_SCRIPT" "10.0.0.1" "10.0.0.2" "unknown/model" 2>&1)
    EXIT_CODE=$?

    if [ $EXIT_CODE -eq 1 ]; then
        if echo "$OUTPUT" | grep -q "not found in the supported registry"; then
            echo "PASS"
        else
            echo "FAIL: Expected registry error not found. Output:"
            echo "$OUTPUT"
            exit 1
        fi
    else
        echo "FAIL: Script should have failed for unknown model"
        exit 1
    fi
)
if [ $? -ne 0 ]; then exit 1; fi

# Test 13: Unknown Model with --force (Success)
echo "Running test: Unknown Model with --force (Success)"
(
    export NGC_API_KEY="test-key"
    # Ensure VRAM check passes for unknown model (params=10 default in script)
    OUTPUT=$(echo "n" | "$TARGET_SCRIPT" --force "10.0.0.1" "10.0.0.2" "unknown/model" 2>&1)
    EXIT_CODE=$?

    if [ $EXIT_CODE -eq 0 ]; then
        if echo "$OUTPUT" | grep -q "Model 'unknown/model' not found in registry"; then
            echo "PASS"
        else
            echo "FAIL: Expected generic config message not found. Output:"
            echo "$OUTPUT"
            exit 1
        fi
    else
        echo "FAIL: Script failed despite --force for unknown model. Output:"
        echo "$OUTPUT"
        exit 1
    fi
)
if [ $? -ne 0 ]; then exit 1; fi

# Test 14: Quantization Override
echo "Running test: Quantization Override"
(
    rm -f "$TEST_DIR/docker_run.log"
    export NGC_API_KEY="test-key"
    echo "n" | "$TARGET_SCRIPT" --quant fp4 "10.0.0.1" "10.0.0.2" "meta/llama-3.3-70b-instruct" >/dev/null

    LOG_CONTENT=$(cat "$TEST_DIR/docker_run.log")

    if echo "$LOG_CONTENT" | grep -q "NIM_QUANTIZATION=fp4"; then
        echo "PASS"
    else
        echo "FAIL: Did not find NIM_QUANTIZATION=fp4. Log:"
        echo "$LOG_CONTENT"
        exit 1
    fi
)
if [ $? -ne 0 ]; then exit 1; fi

# Test 15: Start/Stop/Setup Mode Persistence
echo "Running test: Start/Stop/Setup Mode Persistence"
(
    export NGC_API_KEY="test-key"
    rm -f "$TEST_DIR/docker_run.log"
    rm -f "$TEST_DIR/docker_rm.log"

    # 1. Setup (already done implicitly by basic run, but let's do explicit setup run)
    echo "n" | "$TARGET_SCRIPT" "10.0.0.1" "10.0.0.2" "meta/llama-3.3-70b-instruct" >/dev/null

    CONFIG_FILE="$TEST_DIR/dgx-spark-distributed-model-config.json"
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "FAIL: Config file not created"
        exit 1
    fi

    # Check content
    if ! grep -q "10.0.0.1" "$CONFIG_FILE"; then
        echo "FAIL: Config file missing IP1"
        exit 1
    fi

    # 2. Stop
    "$TARGET_SCRIPT" stop >/dev/null
    if [ -f "$TEST_DIR/docker_rm.log" ]; then
        echo "Stop: PASS"
    else
        echo "FAIL: 'docker rm' not called during stop"
        exit 1
    fi

    # 3. Start
    rm -f "$TEST_DIR/docker_run.log"
    echo "n" | "$TARGET_SCRIPT" start >/dev/null
    if [ -f "$TEST_DIR/docker_run.log" ]; then
        echo "Start: PASS"
    else
        echo "FAIL: 'docker run' not called during start"
        exit 1
    fi
)
if [ $? -ne 0 ]; then exit 1; fi

# Test 18: Engine Override
echo "Running test: Engine Override"
(
    rm -f "$TEST_DIR/docker_run.log"
    export NGC_API_KEY="test-key"
    echo "n" | "$TARGET_SCRIPT" --engine vllm "10.0.0.1" "10.0.0.2" "meta/llama-3.3-70b-instruct" >/dev/null

    LOG_CONTENT=$(cat "$TEST_DIR/docker_run.log")

    if echo "$LOG_CONTENT" | grep -q "NIM_ENGINE=vllm"; then
        echo "PASS"
    else
        echo "FAIL: Did not find NIM_ENGINE=vllm"
        exit 1
    fi
)
if [ $? -ne 0 ]; then exit 1; fi

# Test 19: W&B Key
echo "Running test: W&B Key"
(
    rm -f "$TEST_DIR/docker_run.log"
    export NGC_API_KEY="test-key"
    echo "n" | "$TARGET_SCRIPT" --wandb-key my-key "10.0.0.1" "10.0.0.2" "meta/llama-3.3-70b-instruct" >/dev/null

    LOG_CONTENT=$(cat "$TEST_DIR/docker_run.log")

    if echo "$LOG_CONTENT" | grep -q "WANDB_API_KEY=my-key"; then
        echo "PASS"
    else
        echo "FAIL: Did not find WANDB_API_KEY=my-key"
        exit 1
    fi
)
if [ $? -ne 0 ]; then exit 1; fi

# Test 20: Speculative Decoding
echo "Running test: Speculative Decoding"
(
    rm -f "$TEST_DIR/docker_run.log"
    export NGC_API_KEY="test-key"
    echo "n" | "$TARGET_SCRIPT" --speculative "10.0.0.1" "10.0.0.2" "meta/llama-3.3-70b-instruct" >/dev/null

    LOG_CONTENT=$(cat "$TEST_DIR/docker_run.log")

    if echo "$LOG_CONTENT" | grep -q "NIM_SPECULATIVE_DECODING_MODE=EAGLE"; then
        echo "PASS"
    else
        echo "FAIL: Did not find Speculative Decoding mode"
        exit 1
    fi
)
if [ $? -ne 0 ]; then exit 1; fi

# Test 21: Fail Fast on Container Crash
echo "Running test: Fail Fast on Container Crash"
(
    export NGC_API_KEY="test-key"
    export MOCK_CONTAINER_CRASH=1

    OUTPUT=$(echo "n" | "$TARGET_SCRIPT" "10.0.0.1" "10.0.0.2" "meta/llama-3.3-70b-instruct" 2>&1)
    EXIT_CODE=$?

    if [ $EXIT_CODE -eq 1 ]; then
        if echo "$OUTPUT" | grep -q "Container 'nim-distributed' crashed or stopped"; then
            echo "PASS"
        else
            echo "FAIL: Crash message not found. Output:"
            echo "$OUTPUT"
            exit 1
        fi
    else
        echo "FAIL: Script did not fail on container crash. Exit code: $EXIT_CODE"
        echo "Output: $OUTPUT"
        exit 1
    fi
)
if [ $? -ne 0 ]; then exit 1; fi

# Test 22: Garbage VRAM Output (Graceful Failure)
echo "Running test: Garbage VRAM Output (Graceful Failure)"
(
    export NGC_API_KEY="test-key"
    export MOCK_VRAM_MB="CUDA_ERROR_UNKNOWN"

    OUTPUT=$(echo "n" | "$TARGET_SCRIPT" "10.0.0.1" "10.0.0.2" "meta/llama-3.3-70b-instruct" 2>&1)
    EXIT_CODE=$?

    if [ $EXIT_CODE -eq 1 ]; then
        if echo "$OUTPUT" | grep -q "VRAM detection failed or total is 0 GB"; then
            echo "PASS"
        else
            echo "FAIL: Expected VRAM failure message not found. Output:"
            echo "$OUTPUT"
            exit 1
        fi
    else
        echo "FAIL: Script should fail on garbage VRAM output. Exit code: $EXIT_CODE"
        exit 1
    fi
)
if [ $? -ne 0 ]; then exit 1; fi

# Cleanup
rm -rf "$TEST_DIR"
