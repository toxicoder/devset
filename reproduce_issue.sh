#!/bin/bash

# Simulate the quoting issue
IP1="localhost"
HF_MODEL_ID="meta/llama-3.3-70b-instruct"
HF_TOKEN="test_token"
host_model_base="/tmp/models"
ctr_model_base="/models"
IMAGE="ubuntu:latest"
ctr_model_path="/models/meta-llama-3.3-70b-instruct"

# The problematic line from the script
# local dl_cmd="if ! command -v huggingface-cli &>/dev/null; then pip install -U 'huggingface_hub[cli]'; fi; huggingface-cli download $HF_MODEL_ID --local-dir $ctr_model_path --local-dir-use-symlinks False"

# Constructing it as in the script
dl_cmd="if ! command -v huggingface-cli &>/dev/null; then pip install -U 'huggingface_hub[cli]'; fi; echo huggingface-cli download $HF_MODEL_ID --local-dir $ctr_model_path --local-dir-use-symlinks False"

echo "Command to run:"
echo "ssh $IP1 \"docker run --rm $IMAGE bash -c '$dl_cmd'\""

# Let's inspect what happens when we print it (simulating what ssh receives)
echo "--- SSH Payload ---"
echo "docker run --rm $IMAGE bash -c '$dl_cmd'"
echo "-------------------"

# If I try to run this locally with bash -c to simulate SSH receiving it:
# bash -c "docker run ... bash -c '$dl_cmd'"

# The issue is '$dl_cmd' contains single quotes: 'huggingface_hub[cli]'
# So the outer single quote for bash -c '$dl_cmd' gets closed by the inner single quote.

# Let's try to verify if this is invalid syntax in bash
echo "--- syntax check ---"
bash -n -c "bash -c '$dl_cmd'" 2>&1
if [ $? -ne 0 ]; then
    echo "Syntax Error detected!"
else
    echo "Syntax OK (Unexpected)"
fi
