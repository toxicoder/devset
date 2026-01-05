#!/bin/bash
# Test script for run-distributed-model.sh

export TEST_DIR=$(mktemp -d)
# Resolving absolute path to the script properly
# The test is in dgx-spark/tests/
# The script is in dgx-spark/scripts/
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_SCRIPT="$SCRIPT_DIR/../scripts/run-distributed-model.sh"

# Mock utilities
setup_mocks() {
    export PATH="$TEST_DIR:$PATH"

    # Mock ssh
    cat << 'EOF' > "$TEST_DIR/ssh"
#!/bin/bash
# echo "Mock ssh called with: $@" >> "$TEST_DIR/ssh.log"
ARGS="$*"

if [[ "$ARGS" == *"uname -m"* ]]; then
    if [[ -n "${MOCK_ARCH}" ]]; then
        echo "${MOCK_ARCH}"
    else
        echo "x86_64"
    fi
    exit 0
elif [[ "$ARGS" == *"nvidia-smi"* ]]; then
    exit 0
elif [[ "$ARGS" == *"docker login"* ]]; then
    # Image pull simulation
    if [[ -n "${MOCK_SSH_FAIL_PULL_IP:-}" ]] && [[ "$ARGS" == *"${MOCK_SSH_FAIL_PULL_IP}"* ]]; then
        echo "Mocking pull failure on $MOCK_SSH_FAIL_PULL_IP"
        exit 1
    fi
    if [[ -n "${MOCK_SSH_DELAY_PULL_IP:-}" ]] && [[ "$ARGS" == *"${MOCK_SSH_DELAY_PULL_IP}"* ]]; then
        sleep 2
    fi
    exit 0
elif [[ "$ARGS" == *"docker pull"* ]]; then
    # Note: script usually chains login and pull, so 'docker login' block catches it.
    exit 0
elif [[ "$ARGS" == *"docker image inspect"* ]]; then
    if [[ -n "${MOCK_IMAGE_MISSING}" ]]; then
        exit 1
    fi
    # Default: image exists (exit 0)
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
    # Default success
    exit 0
fi
EOF
    chmod +x "$TEST_DIR/ssh"

    # Mock bc (legacy, we might remove usage but keep mock for now)
    cat << 'EOF' > "$TEST_DIR/bc"
#!/bin/bash
read -r input
if [[ "$input" == *"*"* ]]; then
   # Return a safe dummy value for calculation
   echo 10
else
   echo 0
fi
EOF
    chmod +x "$TEST_DIR/bc"

    # Mock docker (if called locally, though script calls it via ssh usually)
    # The script calls docker via ssh, but if it checked for local docker, we'd mock it.
    # We will mock it just in case.
    cat << 'EOF' > "$TEST_DIR/docker"
#!/bin/bash
exit 0
EOF
    chmod +x "$TEST_DIR/docker"

    # Mock nc (netcat) - for dependency check
    cat << 'EOF' > "$TEST_DIR/nc"
#!/bin/bash
exit 0
EOF
    chmod +x "$TEST_DIR/nc"

    # Mock curl
    cat << 'EOF' > "$TEST_DIR/curl"
#!/bin/bash
# Mock successful health check
exit 0
EOF
    chmod +x "$TEST_DIR/curl"
}

run_test() {
    local desc="$1"
    shift
    echo "Running test: $desc"

    # Run in subshell to avoid env pollution
    (
        export NGC_API_KEY="test-key"
        "$@"
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
run_test "Basic execution" "$TARGET_SCRIPT" "10.0.0.1" "10.0.0.2" "meta/llama-3.1-70b-instruct"

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
    # Capture output to check for error message
    OUTPUT=$("$TARGET_SCRIPT" "10.0.0.1" "10.0.0.2" "meta/llama-3.1-70b-instruct" 2>&1)
    EXIT_CODE=$?

    if [ $EXIT_CODE -eq 1 ]; then
        if echo "$OUTPUT" | grep -q "Error: Failed to pull image on 10.0.0.2"; then
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

# Test 7: P2P Transfer Success
echo "Running test: P2P Transfer Success"
(
    export MOCK_IMAGE_MISSING=1
    export NGC_API_KEY="test-key"
    OUTPUT=$("$TARGET_SCRIPT" "10.0.0.1" "10.0.0.2" "meta/llama-3.1-70b-instruct" 2>&1)
    EXIT_CODE=$?

    if [ $EXIT_CODE -eq 0 ]; then
        if echo "$OUTPUT" | grep -q "Image transfer successful"; then
            echo "PASS"
        else
            echo "FAIL: Did not find transfer success message. Output:"
            echo "$OUTPUT"
            exit 1
        fi
    else
        echo "FAIL: Script exited with error. Output:"
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
    # Try simpler match
    if grep -F "'\$oauthtoken'" "$TARGET_SCRIPT" >/dev/null; then
        echo "PASS"
    else
        echo "FAIL: Could not find correct escaping"
        exit 1
    fi
fi

# Test 6: ARM64 Architecture Detection
echo "Running test: ARM64 Architecture Detection"
(
    rm -f "$TEST_DIR/docker_run.log"
    export NGC_API_KEY="test-key"
    export MOCK_ARCH="aarch64"
    "$TARGET_SCRIPT" "10.0.0.1" "10.0.0.2" "meta/llama-3.1-70b-instruct" >/dev/null

    LOG_CONTENT=$(cat "$TEST_DIR/docker_run.log")
    # Verify we did NOT find --platform linux/amd64
    if echo "$LOG_CONTENT" | grep -q "\-\-platform linux/amd64"; then
        echo "FAIL: Found --platform linux/amd64 on ARM64 host"
        exit 1
    else
        echo "PASS"
    fi
)
if [ $? -ne 0 ]; then exit 1; fi

# Test 5: Verify Network and Port Configuration
echo "Running test: Verify Network and Port Configuration"
(
    # Clean previous logs
    rm -f "$TEST_DIR/docker_run.log"
    export NGC_API_KEY="test-key"
    "$TARGET_SCRIPT" "10.0.0.1" "10.0.0.2" "meta/llama-3.1-70b-instruct" >/dev/null

    # Check log
    LOG_CONTENT=$(cat "$TEST_DIR/docker_run.log")

    # Check for --network host
    if echo "$LOG_CONTENT" | grep -q "\-\-network host"; then
        echo "Check --network host: OK"
    else
        echo "Check --network host: FAIL"
        echo "$LOG_CONTENT"
        exit 1
    fi

    # Check for UVICORN_HOST=0.0.0.0
    if echo "$LOG_CONTENT" | grep -q "UVICORN_HOST=0.0.0.0"; then
        echo "Check UVICORN_HOST: OK"
    else
        echo "Check UVICORN_HOST: FAIL"
        exit 1
    fi

    # Check for HOST=0.0.0.0
    if echo "$LOG_CONTENT" | grep -q "HOST=0.0.0.0"; then
        echo "Check HOST: OK"
    else
        echo "Check HOST: FAIL"
        exit 1
    fi

    # Check for NIM_HTTP_API_PORT=8000
    if echo "$LOG_CONTENT" | grep -q "NIM_HTTP_API_PORT=8000"; then
        echo "Check NIM_HTTP_API_PORT: OK"
    else
        echo "Check NIM_HTTP_API_PORT: FAIL"
        exit 1
    fi

    # Check for --runtime=nvidia
    if echo "$LOG_CONTENT" | grep -q "\-\-runtime=nvidia"; then
        echo "Check --runtime=nvidia: OK"
    else
        echo "Check --runtime=nvidia: FAIL"
        exit 1
    fi
)

if [ $? -eq 0 ]; then
    echo "PASS"
else
    echo "FAIL"
fi

# Test 8: Verify Memory Constraints for Nemotron Nano
echo "Running test: Verify Memory Constraints for Nemotron Nano"
(
    rm -f "$TEST_DIR/docker_run.log"
    export NGC_API_KEY="test-key"
    "$TARGET_SCRIPT" "10.0.0.1" "10.0.0.2" "nvidia/nemotron-3-nano" >/dev/null

    LOG_CONTENT=$(cat "$TEST_DIR/docker_run.log")

    if echo "$LOG_CONTENT" | grep -q "NIM_GPU_MEMORY_UTILIZATION=0.40"; then
        echo "PASS"
    else
        echo "FAIL: Did not find NIM_GPU_MEMORY_UTILIZATION=0.40"
        echo "Log content:"
        echo "$LOG_CONTENT"
        exit 1
    fi
)
if [ $? -ne 0 ]; then exit 1; fi

# Cleanup
rm -rf "$TEST_DIR"
