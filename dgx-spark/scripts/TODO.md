# Refactoring Plan: DGX Spark Distributed Launcher

This checklist guides the refactoring of `dgx-spark/scripts/run-distributed-model.sh` to improve robustness, security, and maintainability.

## Phase 1: Immediate Fixes & Safety (High Priority)
- [x] **Fix Config Typo**: Update `dgx-spark/scripts/dgx-spark-distributed-model-config.json` changing `"Firworks"` to `"Fireworks"` in the model URL.
- [x] **Harden VRAM Detection**:
    - Refactor `_get_node_vram` to avoid parsing raw text output from `nvidia-smi`.
    - Use `nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits` to get clean numbers.
    - Add error handling to return `0` safely if the command fails, rather than crashing the script logic.
- [x] **Add Pre-flight Sudo Check**:
    - Add a function to verify passwordless `sudo` access on remote nodes early in execution.
    - Fail fast with a clear error message if privileges are missing (required for `mkdir`, `vtysh`, etc.).

## Phase 2: Configuration & Registry Architecture
- [x] **Refactor Config Parser**:
    - Remove the fragile pipe-delimited Python one-liner in `_read_config`.
    - Implement a safe `json_get` utility function (using Python `json` module or `jq`) to extract single keys reliably.
    - Example pattern:
      ```bash
      function json_get() {
          python3 -c "import sys, json; print(json.load(open('$CONFIG_FILE')).get('$1', ''))"
      }
      ```
- [x] **Externalize Model Registry**:
    - Extract the hardcoded Heredoc data in `get_model_registry_data` into a separate file (e.g., `dgx-spark/scripts/models.json` or `.csv`).
    - Update `parse_model_config` to read from this external file, making updates easier without modifying script logic.

## Phase 3: Remote Execution Reliability
- [ ] **Implement SSH Heredoc Pattern**:
    - Identify complex remote commands (especially `download_hf_model` and `pull_image`).
    - Refactor them to pass scripts via standard input to avoid "SSH Quote Hell".
    - Example pattern:
      ```bash
      ssh "$IP" "bash -s" <<'EOF'
      # Complex commands here without escaping nightmare
      EOF
      ```
- [ ] **Secure Image Transfer**:
    - Replace the `nc` (netcat) P2P transfer logic in `transfer_docker_image_p2p`.
    - **Option A (Preferred)**: Use `skopeo copy` if available.
    - **Option B (Fallback)**: If using `nc`, implement a handshake (listener confirms readiness) before sender starts, and verify checksums. Remove the arbitrary `sleep 5`.

## Phase 4: TensorRT-LLM Modernization
- [ ] **Deprecate Heuristic Converter Script**:
    - Delete `generate_trt_converter_script` and the logic that recursively searches for `convert_checkpoint.py`.
- [ ] **Implement CLI-based Build**:
    - Refactor `compile_trt_engine` to use the standardized `trtllm-build` and `trtllm-convert-checkpoint` CLI tools found in modern TRT-LLM images.
    - Fallback to hardcoded, pinned paths only if the CLI tools are missing (do not search dynamically).

## Phase 5: Code Hygiene & Cleanup
- [ ] **Reduce Global Variable Usage**:
    - Refactor helper functions (like `detect_high_speed_iface`) to accept arguments instead of modifying global variables like `NET_CONF_1`.
    - Use `local` variables within functions to prevent namespace pollution.
- [ ] **Standardize Logging**:
    - Ensure all error messages print to `stderr` (`>&2`).
    - Standardize status output format (e.g., `[INFO]`, `[WARN]`, `[ERROR]`).
