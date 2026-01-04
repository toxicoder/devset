import os
import re
import json
import shutil
import subprocess

DOCS_DIR = 'docs'
MAPPING_FILE = 'docs_mapping.json'

def get_new_name(name, is_dir=False):
    # Special cases
    if name == 'JOB_ROLE_ORGANIZATION':
        return 'job_roles'
    if name == 'interview-questions':
        return 'interview_questions'
    if name == 'style-guides':
        return 'style_guides'

    # Remove numbers like "3.0 " or "4. "
    name = re.sub(r'^\d+(\.\d+)?\s+', '', name)

    # Lowercase
    name = name.lower()

    # Replace spaces and hyphens with underscores
    name = re.sub(r'[\s\-]+', '_', name)

    # Remove special characters (like parens)
    name = re.sub(r'[^\w\._]', '', name)

    return name

def generate_mapping():
    mapping = {} # old_rel_path -> new_rel_path

    # Walk top-down to handle directories first?
    # Actually, we need to compute full paths.
    # Let's collect all paths first.

    # We need to simulate the rename process to generate the mapping correctly
    # because renaming a parent changes the path of the child.

    # So we will store mapping of individual components,
    # but we need full path mapping for link updates.

    # Let's do a two-pass approach.
    # Pass 1: Build a tree of renaming operations.

    abs_docs_dir = os.path.abspath(DOCS_DIR)

    # List of (old_path, new_path) tuples.
    # We must process depth-first (bottom-up) for renaming files,
    # but for calculating the 'new path' of a file, we need to know the new path of its parent.

    # Let's just compute the new path for every file/folder relative to docs root

    for root, dirs, files in os.walk(DOCS_DIR, topdown=True):
        for name in dirs + files:
            old_path = os.path.join(root, name)
            rel_path = os.path.relpath(old_path, DOCS_DIR)

            parts = rel_path.split(os.sep)
            new_parts = [get_new_name(p) for p in parts]
            new_rel_path = os.path.join(*new_parts)

            mapping[rel_path] = new_rel_path

    return mapping

def perform_renaming(mapping):
    # Sort mapping keys by depth (deepest first) to avoid renaming parent before child
    # Wait, if we use git mv, we should probably rename files first?
    # Actually, if I rename "A/B" to "a/b", and I rename "A" to "a" first, "A/B" no longer exists.
    # So I must rename deeper items first?
    # If I rename "A/B" -> "A/b", then "A" -> "a", the final result is "a/b".
    # But if I rename "A" -> "a", then "A/B" is now "a/B", so I'd need to rename "a/B" -> "a/b".

    # Strategy:
    # 1. Rename all files first (deepest first).
    # 2. Rename all directories (deepest first).

    # But wait, if I rename "docs/A/file.md" to "docs/A/file_new.md",
    # and then rename "docs/A" to "docs/a", it works.

    # We need to act on the original paths.

    sorted_paths = sorted(mapping.keys(), key=lambda x: x.count(os.sep), reverse=True)

    # We need to handle moving.
    # If new directory structure doesn't exist, git mv might complain?
    # git mv A/B.md C/b.md -> C must exist?

    # Let's keep it simple.
    # We are renaming in place.
    # "docs/Folder/File.md" -> "docs/Folder/file.md"
    # "docs/Folder" -> "docs/folder"

    # Let's split into files and directories
    files_to_rename = []
    dirs_to_rename = []

    for old_rel in sorted_paths:
        if os.path.isfile(os.path.join(DOCS_DIR, old_rel)):
            files_to_rename.append(old_rel)
        else:
            dirs_to_rename.append(old_rel)

    # Rename files
    for old_rel in files_to_rename:
        new_rel = mapping[old_rel]
        # The parent directory of new_rel might be named differently in the mapping,
        # but on disk it is still the old name (because we haven't renamed dirs yet).
        # Wait, new_rel is "new_dir/new_file.md".
        # But "new_dir" doesn't exist yet! "old_dir" exists.

        # So we should only rename the BASENAME of the file first.
        old_full = os.path.join(DOCS_DIR, old_rel)
        dirname = os.path.dirname(old_full)
        basename = os.path.basename(old_full)
        new_basename = os.path.basename(new_rel)

        if basename != new_basename:
            new_full_temp = os.path.join(dirname, new_basename)
            print(f"Renaming file: {old_full} -> {new_full_temp}")
            subprocess.run(['git', 'mv', old_full, new_full_temp], check=True)

    # Rename directories
    for old_rel in dirs_to_rename:
        new_rel = mapping[old_rel]
        old_full = os.path.join(DOCS_DIR, old_rel)

        # We need to construct the path where the directory SHOULD be.
        # Since we are processing deepest first, the children are already processed (renamed in place).
        # Now we rename the directory itself.
        # old_rel = "A/B". new_rel = "a/b".
        # We are at "docs/A/B". We want to rename it to "docs/A/b".
        # Parent "docs/A" still exists as "docs/A".

        dirname = os.path.dirname(old_full)
        new_basename = os.path.basename(new_rel)

        if os.path.basename(old_full) != new_basename:
            new_full_temp = os.path.join(dirname, new_basename)
            print(f"Renaming dir: {old_full} -> {new_full_temp}")
            subprocess.run(['git', 'mv', old_full, new_full_temp], check=True)

def update_mkdocs(mapping):
    with open('mkdocs.yml', 'r') as f:
        content = f.read()

    # Sort keys by length (longest first) to avoid partial replacements
    # e.g. replacing "folder/file.md" before "folder/"
    sorted_keys = sorted(mapping.keys(), key=len, reverse=True)

    new_content = content
    for old_path in sorted_keys:
        # mkdocs paths might not have 'docs/' prefix if they are relative to docs_dir
        # but standard mkdocs structure usually assumes 'docs' is the root docs_dir.
        # The 'nav' in mkdocs.yml usually refers to files relative to 'docs/'.
        # Let's check mkdocs.yml content again.
        # "JOB_ROLE_ORGANIZATION/JOB_ROLE_ORGANIZATION.md"
        # So it matches our mapping keys.

        new_path = mapping[old_path]

        # We need to replace strict matches to avoid false positives.
        # But simplistic replace should work if paths are unique enough.
        new_content = new_content.replace(old_path, new_path)

    with open('mkdocs.yml', 'w') as f:
        f.write(new_content)

def update_links(mapping):
    # Iterate over NEW file paths
    # We can reconstruct the new full path from the mapping values.

    new_files = [v for v in mapping.values() if not os.path.isdir(os.path.join(DOCS_DIR, v.split('/')[0]))]
    # Wait, the mapping contains both files and dirs.
    # And we executed renaming, so the files are now at their new locations (relative to docs root).

    # Let's walk the docs dir again to find all markdown files.
    for root, dirs, files in os.walk(DOCS_DIR):
        for filename in files:
            if not filename.endswith('.md'):
                continue

            filepath = os.path.join(root, filename)
            with open(filepath, 'r') as f:
                content = f.read()

            # Regex to find links: [text](link)
            # We also need to handle relative links.
            # ../some/file.md

            def replace_link(match):
                text = match.group(1)
                link = match.group(2)

                # Ignore external links or anchors
                if link.startswith('http') or link.startswith('#') or link.startswith('mailto:'):
                    return match.group(0)

                # Resolve link to absolute path (relative to docs root)
                # Current file path relative to docs:
                curr_rel = os.path.relpath(filepath, DOCS_DIR)
                curr_dir = os.path.dirname(curr_rel)

                # Resolve the linked path
                # e.g. link = "../foo.md", curr_dir = "bar" -> "foo.md"
                # We need to normalize.

                try:
                    # Construct what the OLD path would have been?
                    # No, the file content still has OLD links.
                    # We need to map OLD target -> NEW target.

                    # Problem: We don't easily know if the link is relative to the file
                    # or if it's correct. Assuming valid links.

                    # We need to find what file 'link' pointed to in the OLD structure.
                    # But we are in the NEW structure.
                    # This is tricky because "curr_dir" is a NEW directory name.

                    # Easier approach:
                    # The mapping has "old_rel_path -> new_rel_path".
                    # We can invert it? No, we need to know what the old link pointed to.

                    # Let's guess the old absolute path of the current file?
                    # We can iterate the mapping to find which key produces 'curr_rel'.
                    # This is slow O(N).

                    pass
                except:
                    pass

                return match.group(0)

            # Re-thinking link updates.
            # Since we renamed everything, the old links are broken.
            # We need to update them to point to the new locations.
            # BUT, the link text in the file is relative to the OLD location of the file.

            # Example:
            # Old File: docs/A/old_file.md
            # Content: [Link](../B/other.md)
            # New File: docs/a/new_file.md
            #
            # We need to calculate:
            # 1. Old absolute path of reference: join(docs/A, ../B/other.md) -> docs/B/other.md
            # 2. Look up "docs/B/other.md" in mapping -> "docs/b/new_other.md"
            # 3. Calculate new relative link from "docs/a/new_file.md" to "docs/b/new_other.md" -> ../b/new_other.md

            # So we need a reverse mapping: new_path -> old_path to find out who we are.
            pass

    # Let's restructure update_links to pre-calculate the reverse mapping
    reverse_mapping = {v: k for k, v in mapping.items()}

    for root, dirs, files in os.walk(DOCS_DIR):
        for filename in files:
            if not filename.endswith('.md'):
                continue

            filepath = os.path.join(root, filename)
            curr_new_rel = os.path.relpath(filepath, DOCS_DIR)

            if curr_new_rel not in reverse_mapping:
                # Maybe it wasn't renamed or is new? Skip.
                continue

            old_rel_path_of_file = reverse_mapping[curr_new_rel]
            old_dir_of_file = os.path.dirname(old_rel_path_of_file)

            with open(filepath, 'r') as f:
                content = f.read()

            def replace_link_logic(match):
                text = match.group(1)
                link = match.group(2)

                if link.startswith('http') or link.startswith('#') or link.startswith('mailto:') or link.startswith('javascript:'):
                    return match.group(0)

                # Split anchor if present
                anchor = ""
                if '#' in link:
                    link, anchor = link.split('#', 1)
                    anchor = '#' + anchor

                # Resolve old target
                # link is relative to old_dir_of_file
                # We simply join them.
                # Handling "job_roles/..." style links?
                # If link starts with /, it's relative to root? MkDocs usually relative.

                try:
                    # Assume relative
                    old_target_abs = os.path.normpath(os.path.join(old_dir_of_file, link))
                    # On windows separators might be issue, forcing forward slashes for mapping lookup
                    old_target_rel = old_target_abs.replace('\\', '/')

                    if old_target_rel.startswith('../'):
                         # This implies it went above docs root? Unlikely for valid docs.
                         pass

                    # Look up in mapping
                    if old_target_rel in mapping:
                        new_target_rel = mapping[old_target_rel]

                        # Calculate new relative link
                        # From curr_new_rel (dir) to new_target_rel
                        new_dir = os.path.dirname(curr_new_rel)
                        new_link = os.path.relpath(new_target_rel, new_dir)

                        return f"[{text}]({new_link}{anchor})"
                    else:
                        # Link might point to a file that wasn't renamed?
                        # Or it's a broken link.
                        # Or it's an image?
                        # Let's check if the file exists in new structure as is?
                        # No, if it's not in mapping, maybe we failed to map it.
                        return match.group(0)

                except Exception as e:
                    print(f"Error processing link {link} in {filepath}: {e}")
                    return match.group(0)

            new_content = re.sub(r'\[(.*?)\]\((.*?)\)', replace_link_logic, content)

            if new_content != content:
                with open(filepath, 'w') as f:
                    f.write(new_content)

if __name__ == "__main__":
    mapping = generate_mapping()

    # Save mapping
    with open(MAPPING_FILE, 'w') as f:
        json.dump(mapping, f, indent=2)

    print("Mapping generated.")

    perform_renaming(mapping)
    print("Renaming complete.")

    update_mkdocs(mapping)
    print("MkDocs updated.")

    update_links(mapping)
    print("Links updated.")
