import os
import sys

# Mock os.walk and os.path
class MockOS:
    def __init__(self, structure):
        self.structure = structure
        self.sep = "/"

    def walk(self, top):
        # structure is flat dict of dir -> list of files/dirs
        for d, contents in self.structure.items():
            if d.startswith(top):
                dirs = [x.replace("/", "") for x in contents if x.endswith("/")]
                files = [x for x in contents if not x.endswith("/")]
                yield d, dirs, files

    def path_join(self, *args):
        return "/".join(args)

    def path_basename(self, p):
        return p.split("/")[-1]

    def path_dirname(self, p):
        return "/".join(p.split("/")[:-1])

mock_structure = {
    "/examples": ["llama/", "models/"],
    "/examples/llama": ["convert_checkpoint.py", "readme.md"],
    "/examples/models": ["gpt/", "mamba/"],
    "/examples/models/gpt": ["convert_checkpoint.py"],
    "/examples/models/mamba": ["convert_checkpoint.py"],
}

# Implementation to test
def get_script_for_arch(arch, examples_dir, os_module):
    arch = arch.lower()
    mapping = {
        "llama": "llama", "mistral": "llama",
        "gpt": "gpt", "nemotron": "gpt",
        "nemotronh": "mamba", "mamba": "mamba"
    }
    target_subdir = mapping.get(arch, arch)

    candidates = []
    for root, dirs, files in os_module.walk(examples_dir):
        if "convert_checkpoint.py" in files:
            candidates.append(os_module.path_join(root, "convert_checkpoint.py"))

    # Strategy 1: Parent match
    for c in candidates:
        parent = os_module.path_basename(os_module.path_dirname(c)).lower()
        if parent == target_subdir:
            return c

    # Strategy 2: Fuzzy match
    for c in candidates:
        parent = os_module.path_basename(os_module.path_dirname(c)).lower()
        if arch in parent or parent in arch:
            return c

    # Strategy 3: Universal Fallback (Llama)
    for c in candidates:
        parent = os_module.path_basename(os_module.path_dirname(c)).lower()
        if parent == "llama":
            return c

    return None

# Tests
mock = MockOS(mock_structure)

# Test 1: Direct match (llama)
res = get_script_for_arch("llama", "/examples", mock)
print(f"Llama -> {res}")
assert res == "/examples/llama/convert_checkpoint.py"

# Test 2: Mapped match (nemotronh -> mamba)
res = get_script_for_arch("nemotronh", "/examples", mock)
print(f"NemotronH -> {res}")
assert res == "/examples/models/mamba/convert_checkpoint.py"

# Test 3: Fallback (Unknown -> Llama)
res = get_script_for_arch("unknown_arch", "/examples", mock)
print(f"Unknown -> {res}")
assert res == "/examples/llama/convert_checkpoint.py"

print("All Python tests passed.")
