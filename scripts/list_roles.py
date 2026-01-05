
import os

role_dir = "docs/JOB_ROLE_ORGANIZATION"
roles = []

for root, dirs, files in os.walk(role_dir):
    for file in files:
        if file.endswith(".md") and file != "JOB_ROLE_ORGANIZATION.md":
            rel_path = os.path.relpath(os.path.join(root, file), role_dir)
            roles.append(rel_path)

roles.sort()
for r in roles:
    print(r)
