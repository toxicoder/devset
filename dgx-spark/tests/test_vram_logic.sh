#!/bin/bash
set -euo pipefail

function parse_vram() {
    local input="$1"
    # Logic to be implemented:
    # grep -oE '[0-9]+' extracts all number sequences on separate lines
    # awk sums them up

    local numeric_out
    numeric_out=$(printf "%s" "$input" | grep -oE '[0-9]+' || true)

    if [[ -z "$numeric_out" ]]; then
       echo "0"
       return
    fi

    printf "%s\n" "$numeric_out" | awk '{s+=$1} END {print s+0}'
}

echo "Running VRAM Logic Tests..."

# Test 1: Standard output
input="81920
81920"
res=$(parse_vram "$input")
if [[ "$res" == "163840" ]]; then echo "PASS: Standard"; else echo "FAIL: Standard (Got $res)"; exit 1; fi

# Test 2: Warning on separate line (no numbers in warning)
input="Warning: Detected NVIDIA GB10 GPU
81920"
res=$(parse_vram "$input")
echo "Result 2: $res"
# Expect at least 81920. '10' from GB10 adds 10.
if [[ "$res" -ge "81920" ]]; then echo "PASS: Warning Separate"; else echo "FAIL: Warning Separate"; exit 1; fi

# Test 3: Warning mixed
input="Warning: Something 200 81920"
res=$(parse_vram "$input")
# 200 + 81920 = 82120
echo "Result 3: $res"
if [[ "$res" -ge "81920" ]]; then echo "PASS: Warning Mixed"; else echo "FAIL: Warning Mixed"; exit 1; fi

# Test 4: Polluted garbage
input="Garbage 123
Another 456
8000"
res=$(parse_vram "$input")
# 123 + 456 + 8000 = 8579
echo "Result 4: $res"
if [[ "$res" -ge "8000" ]]; then echo "PASS: Garbage"; else echo "FAIL: Garbage"; exit 1; fi

echo "All VRAM tests passed."
