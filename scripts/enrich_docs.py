import os
import re
import json

DOCS_DIR = 'docs'
MAPPING_FILE = 'docs_mapping.json'

# Common external resources
RESOURCES = {
    'python': 'https://docs.python.org/3/',
    'java': 'https://docs.oracle.com/en/java/',
    'go': 'https://go.dev/doc/',
    'golang': 'https://go.dev/doc/',
    'c++': 'https://en.cppreference.com/w/',
    'cpp': 'https://en.cppreference.com/w/',
    'rust': 'https://www.rust-lang.org/learn',
    'javascript': 'https://developer.mozilla.org/en-US/docs/Web/JavaScript',
    'typescript': 'https://www.typescriptlang.org/docs/',
    'kotlin': 'https://kotlinlang.org/docs/home.html',
    'sql': 'https://www.postgresql.org/docs/', # Defaulting to Postgres as generic SQL
    'bash': 'https://www.gnu.org/software/bash/manual/',
    'zsh': 'https://zsh.sourceforge.io/Doc/',
    'css': 'https://developer.mozilla.org/en-US/docs/Web/CSS',
    'html': 'https://developer.mozilla.org/en-US/docs/Web/HTML',
    'json': 'https://www.json.org/json-en.html',
    'yaml': 'https://yaml.org/spec/',
    'protocol buffers': 'https://protobuf.dev/',
    'protobuf': 'https://protobuf.dev/',
    'starlark': 'https://bazel.build/rules/lib/globals',
    'aws': 'https://docs.aws.amazon.com/',
    'docker': 'https://docs.docker.com/',
    'kubernetes': 'https://kubernetes.io/docs/home/',
    'terraform': 'https://developer.hashicorp.com/terraform/docs',
    'react': 'https://react.dev/',
    'kafka': 'https://kafka.apache.org/documentation/',
    'spark': 'https://spark.apache.org/docs/latest/',
}

def load_mapping():
    if os.path.exists(MAPPING_FILE):
        with open(MAPPING_FILE, 'r') as f:
            return json.load(f)
    return {}

def find_file_in_mapping(mapping, keyword):
    """Find a file path in the mapping that matches the keyword."""
    # This is a heuristic.
    # We want to find "docs/style_guides/python/python_style_guide.md" given "python"

    keyword = keyword.lower()
    matches = []

    for old_path, new_path in mapping.items():
        if keyword in new_path.lower():
            matches.append(new_path)

    # filter for specific types
    return matches

def get_style_guide_path(mapping, topic):
    # topic: python -> docs/style_guides/python/python_style_guide.md

    # Let's search specifically in style_guides dir
    for new_path in mapping.values():
        if 'style_guides' in new_path and f"/{topic}" in new_path and new_path.endswith('.md'):
             # Handle "python/python_style_guide.md" or just "python.md" if it existed
             return new_path

        # Also check just filename match
        if 'style_guides' in new_path and f"{topic}_style_guide.md" in os.path.basename(new_path):
            return new_path

    return None

def get_interview_path(mapping, topic):
    # topic: python -> docs/interview_questions/python.md

    for new_path in mapping.values():
        if 'interview_questions' in new_path and f"{topic}.md" == os.path.basename(new_path):
            return new_path
    return None

def enrich_interview_questions(mapping):
    # Iterate over interview questions
    iq_dir = os.path.join(DOCS_DIR, 'interview_questions')

    for root, dirs, files in os.walk(iq_dir):
        for filename in files:
            if not filename.endswith('.md'):
                continue

            filepath = os.path.join(root, filename)

            # Identify topic from filename
            # e.g. python.md -> python
            # e.g. backend_engineer.md -> backend engineer (maybe no direct resource)

            topic = filename.replace('.md', '').replace('_', ' ')

            # Check if we have resources
            links = []

            # 1. External Docs
            for key, url in RESOURCES.items():
                if key == topic or (key in topic.split()):
                    # simple matching
                    links.append(f"- **Official Documentation**: [{key.title()} Docs]({url})")

            # 2. Internal Style Guide
            # Need to find if a style guide exists for this topic
            # Try single word match
            words = topic.split()
            style_guide_path = None
            for word in words:
                sg = get_style_guide_path(mapping, word)
                if sg:
                    style_guide_path = sg
                    break

            if style_guide_path:
                # Calculate relative path
                rel_link = os.path.relpath(os.path.join(DOCS_DIR, style_guide_path), os.path.dirname(filepath))
                links.append(f"- **Internal Style Guide**: [{os.path.basename(style_guide_path).replace('.md', '').replace('_', ' ').title()}]({rel_link})")

            if links:
                with open(filepath, 'r') as f:
                    content = f.read()

                if "## Study Guide" not in content:
                    new_content = content + "\n\n## Study Guide\n\nTo deepen your understanding of these concepts, check out the following resources:\n\n" + "\n".join(links) + "\n"

                    with open(filepath, 'w') as f:
                        f.write(new_content)
                    print(f"Enriched {filepath}")

def enrich_job_roles(mapping):
    # Job roles might need links to interview questions or style guides
    jr_dir = os.path.join(DOCS_DIR, 'job_roles')

    for root, dirs, files in os.walk(jr_dir):
        for filename in files:
            if not filename.endswith('.md'):
                continue

            filepath = os.path.join(root, filename)
            topic = filename.replace('.md', '').replace('_', ' ')

            # Search for relevant interview questions
            # e.g. "Software Engineer" -> "software_engineer.md" in interview_questions

            # We can fuzzy match against interview question filenames
            iq_matches = []

            # List all interview question files
            all_iq_files = []
            for m_path in mapping.values():
                if 'interview_questions' in m_path and m_path.endswith('.md'):
                    all_iq_files.append(m_path)

            # Direct match?
            target_iq = None
            for iq in all_iq_files:
                iq_name = os.path.basename(iq).replace('.md', '')
                if iq_name == filename.replace('.md', ''):
                    target_iq = iq
                    break

            if target_iq:
                rel_link = os.path.relpath(os.path.join(DOCS_DIR, target_iq), os.path.dirname(filepath))

                with open(filepath, 'r') as f:
                    content = f.read()

                if "## Recommended Reading" not in content:
                    section = f"\n\n## Recommended Reading\n\n*   **[Interview Preparation Guide]({rel_link})**: Comprehensive questions and answers for this role.\n"

                    with open(filepath, 'w') as f:
                        f.write(content + section)
                    print(f"Enriched {filepath}")

def enrich_style_guides(mapping):
    sg_dir = os.path.join(DOCS_DIR, 'style_guides')

    for root, dirs, files in os.walk(sg_dir):
        for filename in files:
            if not filename.endswith('.md'):
                continue

            filepath = os.path.join(root, filename)
            # python_style_guide.md -> python
            topic = filename.replace('_style_guide.md', '').replace('_', ' ')

            # Find interview questions for this topic
            target_iq = get_interview_path(mapping, topic.replace(' ', '_'))

            if target_iq:
                 rel_link = os.path.relpath(os.path.join(DOCS_DIR, target_iq), os.path.dirname(filepath))

                 with open(filepath, 'r') as f:
                     content = f.read()

                 if "## Related Interview Questions" not in content:
                     section = f"\n\n## Related Interview Questions\n\n*   **[Practice Questions]({rel_link})**: Test your knowledge of {topic.title()} concepts.\n"

                     with open(filepath, 'w') as f:
                        f.write(content + section)
                     print(f"Enriched {filepath}")

if __name__ == "__main__":
    mapping = load_mapping()
    if not mapping:
        print("Mapping file not found or empty. Please run reorganize_docs.py first.")
        exit(1)

    enrich_interview_questions(mapping)
    enrich_job_roles(mapping)
    enrich_style_guides(mapping)
