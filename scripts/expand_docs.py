#!/usr/bin/env python3
import os
import sys
import re

def read_file(filepath):
    with open(filepath, 'r') as f:
        return f.read()

def write_file(filepath, content):
    with open(filepath, 'w') as f:
        f.write(content)

def extract_front_matter(content):
    match = re.match(r'^---\n(.*?)\n---\n', content, re.DOTALL)
    if match:
        return match.group(0), content[len(match.group(0)):]
    return "", content

def get_title(front_matter, content):
    match = re.search(r'title:\s*(.*)', front_matter)
    if match:
        return match.group(1).strip()
    match = re.search(r'^#\s+(.*)', content, re.MULTILINE)
    if match:
        return match.group(1).strip()
    return "Untitled Document"

def clean_original_content(content):
    # Remove the first H1 if it exists
    content = re.sub(r'^#\s+.*?\n', '', content, flags=re.MULTILINE)
    return content.strip()

def has_header(content, header_name):
    # Match "## Purpose", "## 1. Purpose", "### Purpose", etc.
    pattern = r'^#+\s+(?:\d+\.?\s*)?' + re.escape(header_name)
    return re.search(pattern, content, re.MULTILINE | re.IGNORECASE) is not None

def generate_faq_section():
    return """
## FAQ

**Q: How strictly must this be followed?**
A: This document outlines mandatory standards. Deviations require formal approval.

**Q: Who is the point of contact?**
A: Refer to the "Owner" listed in the header or the relevant Slack channel.

**Q: How often is this updated?**
A: Reviews are conducted quarterly.
"""

def generate_policy_content(title, original_content):
    cleaned_content = clean_original_content(original_content)

    header = f"# {title}\n\n"

    # Check for Purpose
    if not has_header(cleaned_content, "Purpose"):
        header += "## Purpose\nThe purpose of this policy is to establish a framework for compliance and integrity.\n\n"

    # Check for Scope
    if not has_header(cleaned_content, "Scope"):
        header += "## Scope\nThis policy applies to all employees and contractors.\n\n"

    body = f"{cleaned_content}\n\n"

    footer = ""
    if not has_header(cleaned_content, "Roles and Responsibilities"):
        footer += "## Roles and Responsibilities\n*   **Employees:** Must adhere to the policy.\n*   **Managers:** Must enforce the policy.\n"

    if not has_header(cleaned_content, "Compliance"):
        footer += "## Compliance\nViolations of this policy may result in disciplinary action.\n"

    if not has_header(cleaned_content, "FAQ"):
        footer += generate_faq_section()

    footer += """
## Version History
| Version | Date | Author | Changes |
| :--- | :--- | :--- | :--- |
| 1.0 | Current | Policy Team | Initial Release |
"""
    return header + body + footer

def generate_training_soft_skills(title, original_content):
    cleaned_content = clean_original_content(original_content)
    return f"""
# {title}

## Course Overview
**Course Title:** {title}
**Level:** Intermediate
**Format:** Workshop & Role-playing

## Learning Objectives
*   Master the art of {title}.
*   Build stronger relationships with your team.
*   Navigate complex interpersonal situations.

## Core Curriculum
{cleaned_content}

## Practical Exercises
1.  **Role Play:** Pair up with a partner and simulate a scenario related to {title}.
2.  **Reflection:** Write a short journal entry about a past experience.
3.  **Feedback:** Request specific feedback from your manager this week.

## Assessment
*   Participation in the workshop.
*   Self-assessment survey.

## Resources
*   Internal Leadership Wiki
*   Recommended Reading List
"""

def generate_training_technical(title, original_content):
    cleaned_content = clean_original_content(original_content)
    return f"""
# {title}

## Course Overview
**Course Title:** {title}
**Level:** Intermediate/Advanced
**Format:** Self-paced Reading & Hands-on Labs

## Learning Objectives
*   Articulate the core principles of {title}.
*   Apply best practices to real-world engineering scenarios.
*   Troubleshoot common issues and optimize performance.

## Core Curriculum
{cleaned_content}

## Hands-on Exercises
1.  **Review:** Read the core curriculum carefully.
2.  **Apply:** Identify one area in your current project where this applies.
3.  **Prototype:** Create a small proof-of-concept in your sandbox environment.

## Assessment
*   Complete the knowledge check in the Learning Management System (LMS).

## Resources
*   Internal Wiki
*   Official Documentation
"""

def generate_support_general(title, original_content, category="General"):
    cleaned_content = clean_original_content(original_content)
    return f"""
# {title}

## Overview
This document provides detailed technical support information for **{title}**. It is intended for end-users and support staff.

## Configuration & Instructions
{cleaned_content}

## Troubleshooting Guide
1.  **Reproduce:** Try to reproduce the issue consistently.
2.  **Isolate:** Determine if the issue is with the hardware, software, or network.
3.  **Logs:** Check the logs for specific error codes.

## Getting Help
If the issue persists:
1.  Search the Knowledge Base.
2.  Ask in the `#{category.lower()}-support` Slack channel.
3.  Open a Jira ticket.
"""

def generate_playbook_content(title, original_content):
    cleaned_content = clean_original_content(original_content)
    header = f"""
# Playbook: {title}

## Incident Overview
**Playbook Name:** {title}
**Target Response Time:** < 15 Minutes
"""
    footer = f"""
## Incident Commander Responsibilities
*   **Assess:** Determine the severity and impact.
*   **Coordinate:** Assign roles (Ops Lead, Comms Lead).
*   **Communicate:** Update the status page and stakeholders every 30 minutes.

## Communication Templates
**Internal Update:**
> "We are investigating an issue with {title}. Impact is [Low/High]. Next update in 30 mins."

## Post-Incident Procedure
1.  Ensure all logs and artifacts are preserved.
2.  Schedule a Blameless Post-Mortem within 24 hours.
"""
    return header + cleaned_content + footer

def generate_standards_process(title, original_content):
    cleaned_content = clean_original_content(original_content)
    return f"""
# {title}

## Executive Summary
This document defines the process standard for **{title}**. Adherence is mandatory to ensure operational excellence.

## The Process
{cleaned_content}

## Roles and Responsibilities
*   **Process Owner:** Ensures the process is up-to-date.
*   **Practitioner:** Follows the process in daily work.
*   **Auditor:** Verifies compliance.

## Continuous Improvement
*   We review this process quarterly.
*   Please submit feedback via Jira.
"""

def generate_standards_code(title, original_content):
    cleaned_content = clean_original_content(original_content)
    return f"""
# {title}

## Executive Summary
This document defines the engineering standard for **{title}**. Adherence is mandatory to ensure quality and maintainability.

## Core Standard
{cleaned_content}

## Best Practices
*   **Simplicity:** Prefer simple solutions over complex ones.
*   **Readability:** Write code for humans first, computers second.
*   **Testing:** All changes must be verified with tests.

## Review Process
*   All changes related to this standard must be reviewed by a peer.
"""

def generate_onboarding_content(title, original_content):
    cleaned_content = clean_original_content(original_content)
    return f"""
# {title}

## Welcome!
Welcome to the team! This guide covers **{title}** as part of your onboarding journey.

## Key Information
{cleaned_content}

## Your Checklist
*   [ ] Read this document thoroughly.
*   [ ] Complete any setup steps listed above.
*   [ ] Discuss any questions with your onboarding buddy.
"""

def process_file(filepath):
    print(f"Processing {filepath}...")
    if filepath.endswith("index.md"):
        return

    content = read_file(filepath)
    front_matter, body = extract_front_matter(content)
    title = get_title(front_matter, body)

    new_body = ""

    if "policies/" in filepath:
        new_body = generate_policy_content(title, body)
    elif "training/" in filepath:
        if "soft_skills" in filepath or "leadership" in filepath or "product" in filepath:
            new_body = generate_training_soft_skills(title, body)
        else:
            new_body = generate_training_technical(title, body)
    elif "technical_support/" in filepath:
        category = "General"
        if "hardware" in filepath: category = "Hardware"
        if "software" in filepath: category = "Software"
        new_body = generate_support_general(title, body, category)
    elif "playbooks/" in filepath:
        new_body = generate_playbook_content(title, body)
    elif "onboarding/" in filepath:
        new_body = generate_onboarding_content(title, body)
    elif "engineering_standards/" in filepath:
        # Detect if it is a process doc
        process_docs = ["incident_management", "post_mortem", "release_process", "on_call"]
        if any(x in filepath for x in process_docs):
            new_body = generate_standards_process(title, body)
        else:
            new_body = generate_standards_code(title, body)
    else:
        return

    final_content = f"{front_matter}{new_body}"
    write_file(filepath, final_content)
    print(f"Updated {filepath}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 expand_docs.py <directory>")
        sys.exit(1)

    target_dir = sys.argv[1]
    for root, dirs, files in os.walk(target_dir):
        for file in files:
            if file.endswith(".md"):
                process_file(os.path.join(root, file))
