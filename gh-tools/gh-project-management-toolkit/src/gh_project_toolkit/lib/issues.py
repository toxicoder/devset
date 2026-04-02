"""
Issue processing and JSON handling functions for GitHub Project Management Toolkit.

This module provides functions for processing issues from JSON files,
including comment stripping, validation, and GitHub issue creation with
proper project integration.

Example:
    >>> from gh_project_toolkit.lib.issues import clean_json_file, process_issue
    >>> clean_json_file("issues.json", "issues_cleaned.json")
    >>> issue_url = process_issue("owner", "repo", issue_json)
"""

import json
import os
import re
from typing import Any, Optional

# =============================================================================
# Configuration
# =============================================================================
# Define fallback values at module level before try block (avoids mypy "already defined" errors)
TMP_DIR = "/tmp"
DRY_RUN = False
VERBOSE = False

def log_verbose(message: str, *args: Any, **kwargs: Any) -> None:
    """Verbose logging fallback."""
    pass

def log_error(message: str, *args: Any, **kwargs: Any) -> None:
    """Error logging fallback."""
    pass

def log(message: str, *args: Any, **kwargs: Any) -> None:
    """Info logging fallback."""
    pass

def log_warning(message: str, *args: Any, **kwargs: Any) -> None:
    """Warning logging fallback."""
    pass

def log_success(message: str, *args: Any, **kwargs: Any) -> None:
    """Success logging fallback."""
    pass

def log_dry_run(message: str, *args: Any, **kwargs: Any) -> None:
    """Dry-run logging fallback."""
    pass

def require_file(file_path: str) -> bool:
    """Require file fallback."""
    return False

def validate_json(file_path: str) -> bool:
    """Validate JSON fallback."""
    return False

def create_issue(owner: str, repo: str, title: str, body: str, labels: str = "", milestone: str = "", assignees: str = "") -> Optional[str]:
    """Create issue fallback."""
    return None

def get_issue_node_id(owner: str, repo: str, number: int) -> Optional[str]:
    """Get issue node ID fallback."""
    return None

def add_issue_to_project(project_id: str, content_id: str) -> Optional[str]:
    """Add issue to project fallback."""
    return None

def wait_rate_limit(seconds: int = 1) -> None:
    """Rate limit wait fallback."""
    pass

# Try to import from the actual package
try:
    from gh_project_toolkit.config.defaults import (
        TMP_DIR as _tmp_dir,
        DRY_RUN as _dry_run,
        VERBOSE as _verbose,
    )
    from gh_project_toolkit.lib.logging import (
        log_verbose as _log_verbose,
        log_error as _log_error,
        log as _log,
        log_warning as _log_warning,
        log_success as _log_success,
        log_dry_run as _log_dry_run,
    )
    from gh_project_toolkit.lib.validation import (
        require_file as _require_file,
        validate_json as _validate_json,
    )
    from gh_project_toolkit.lib.github_api import (
        create_issue as _create_issue,
        get_issue_node_id as _get_issue_node_id,
        add_issue_to_project as _add_issue_to_project,
        wait_rate_limit as _wait_rate_limit,
    )
    # Use imported values - assign to lowercase variables to avoid mypy constant redefinition errors
    _tmp_dir_imported = _tmp_dir
    _dry_run_imported = _dry_run
    _verbose_imported = _verbose
    log_verbose = _log_verbose
    log_error = _log_error
    log = _log
    log_warning = _log_warning
    log_success = _log_success
    log_dry_run = _log_dry_run
    require_file = _require_file
    validate_json = _validate_json
    create_issue = _create_issue
    get_issue_node_id = _get_issue_node_id
    add_issue_to_project = _add_issue_to_project
    wait_rate_limit = _wait_rate_limit
except ImportError:
    # Use fallback values defined above
    _tmp_dir_imported = "/tmp"
    _dry_run_imported = False
    _verbose_imported = False
    pass


# =============================================================================
# Temporary File Management
# =============================================================================
def create_temp_file(base: str) -> str:
    """
    Create a temporary file with a predictable name for JSON cleanup.

    Args:
        base: Base filename.

    Returns:
        Path to temporary file.

    Example:
        >>> temp_file = create_temp_file("issues_cleaned")
        >>> assert "issues_cleaned" in temp_file
    """
    return os.path.join(TMP_DIR, f"{base}.{os.getpid()}.json")


def cleanup_temp(file_path: str) -> bool:
    """
    Clean up a temporary file.

    Args:
        file_path: File path to remove.

    Returns:
        True if successful, False otherwise.

    Example:
        >>> cleanup_temp(temp_file)
        True
    """
    try:
        if os.path.isfile(file_path):
            os.remove(file_path)
            log_verbose(f"Cleaned up temporary file: {file_path}")
            return True
        return True  # File doesn't exist, consider it cleaned
    except OSError as e:
        log_error(f"Failed to clean up temporary file {file_path}: {e}")
        return False


# =============================================================================
# JSON Comment Stripping
# =============================================================================
def strip_comments(content: str) -> str:
    """
    Remove /* */ style comments from text content.

    This function uses a non-greedy regex to match comment blocks and
    removes them while preserving the rest of the content.

    Args:
        content: The text content potentially containing comments.

    Returns:
        The content with comments removed.

    Example:
        >>> stripped = strip_comments("/* comment */ text")
        >>> assert "comment" not in stripped
    """
    # Remove /* */ style comments (non-greedy, handles multiline)
    content = re.sub(r'/\*[^*]*\*+(?:[^/*][^*]*\*+)*/', '', content, flags=re.DOTALL)
    return content


def normalize_whitespace(content: str) -> str:
    """
    Normalize whitespace by removing trailing whitespace from lines.

    Args:
        content: The text content.

    Returns:
        The content with normalized whitespace.

    Example:
        >>> normalized = normalize_whitespace("line   \\n  another   ")
        >>> assert "line" in normalized
    """
    lines = content.split('\n')
    return '\n'.join(line.rstrip() for line in lines)


def clean_json_file(input_path: str, output_path: str) -> bool:
    """
    Clean a JSON file by removing comments.

    Args:
        input_path: Path to the input JSON file.
        output_path: Path to the output cleaned JSON file.

    Returns:
        True if successful, False otherwise.

    Example:
        >>> success = clean_json_file("issues.json", "issues_cleaned.json")
        >>> assert success
    """
    log("Stripping comments from JSON...")

    try:
        # Read input file
        with open(input_path, 'r', encoding='utf-8') as f:
            content = f.read()

        # Strip comments
        content = strip_comments(content)

        # Normalize whitespace
        content = normalize_whitespace(content)

        # Write output file
        with open(output_path, 'w', encoding='utf-8') as f:
            f.write(content)

        log_verbose(f"Cleaned JSON written to: {output_path}")
        return True

    except FileNotFoundError:
        log_error(f"Input file not found: {input_path}")
        return False
    except IOError as e:
        log_error(f"IO error: {e}")
        return False
    except Exception as e:
        log_error(f"Unexpected error: {e}")
        return False


# =============================================================================
# JSON Validation
# =============================================================================
def validate_and_count_issues(json_file: str) -> Optional[int]:
    """
    Validate JSON file and check for issues array.

    Args:
        json_file: JSON file path.

    Returns:
        Number of issues in the array, or None on failure.

    Example:
        >>> count = validate_and_count_issues("issues.json")
        >>> assert count > 0
    """
    # Check file exists
    if not require_file(json_file):
        return None

    # Validate JSON structure
    if not validate_json(json_file):
        log_error(f"JSON file is not valid: {json_file}")
        return None

    # Check it's an array
    try:
        with open(json_file, 'r', encoding='utf-8') as f:
            data = json.load(f)

        if not isinstance(data, list):
            log_error(f"JSON file must contain an array, got: {type(data).__name__}")
            return None

        # Count issues
        count = len(data)

        if count == 0:
            log_warning("JSON array is empty")
            return None

        log_verbose(f"Validated JSON with {count} issue(s)")
        return count

    except json.JSONDecodeError as e:
        log_error(f"JSON decode error: {e}")
        return None


# =============================================================================
# Issue Data Extraction
# =============================================================================
def extract_title(issue_json: str) -> str:
    """
    Extract issue title from JSON object.

    Args:
        issue_json: JSON string representing an issue.

    Returns:
        Issue title.

    Example:
        >>> title = extract_title('{"title": "Bug", "body": "..."}')
        >>> assert title == "Bug"
    """
    try:
        data = json.loads(issue_json)
        return data.get("title", "Untitled")
    except json.JSONDecodeError:
        return "Untitled"


def extract_body(issue_json: str) -> str:
    """
    Extract issue body from JSON object.

    Args:
        issue_json: JSON string representing an issue.

    Returns:
        Issue body.

    Example:
        >>> body = extract_body('{"title": "Bug", "body": "..."}')
        >>> assert body == "..."
    """
    try:
        data = json.loads(issue_json)
        return data.get("body", "")
    except json.JSONDecodeError:
        return ""


def extract_labels(issue_json: str) -> str:
    """
    Extract issue labels from JSON object.

    Args:
        issue_json: JSON string representing an issue.

    Returns:
        Comma-separated labels.

    Example:
        >>> labels = extract_labels('{"labels": ["bug", "high-priority"]}')
        >>> assert labels == "bug,high-priority"
    """
    try:
        data = json.loads(issue_json)
        labels = data.get("labels", [])
        return ",".join(labels)
    except json.JSONDecodeError:
        return ""


def extract_milestone(issue_json: str) -> Optional[str]:
    """
    Extract issue milestone from JSON object.

    Args:
        issue_json: JSON string representing an issue.

    Returns:
        Milestone title or None if not found.

    Example:
        >>> milestone = extract_milestone('{"title": "Bug", "milestone": "v1.0"}')
        >>> assert milestone == "v1.0"
    """
    try:
        data = json.loads(issue_json)
        milestone = data.get("milestone")
        if milestone is None:
            return None
        return str(milestone)
    except json.JSONDecodeError:
        return None


def extract_assignees(issue_json: str) -> str:
    """
    Extract issue assignees from JSON object.

    Args:
        issue_json: JSON string representing an issue.

    Returns:
        Comma-separated assignees.

    Example:
        >>> assignees = extract_assignees('{"assignees": ["user1", "user2"]}')
        >>> assert assignees == "user1,user2"
    """
    try:
        data = json.loads(issue_json)
        assignees = data.get("assignees", [])
        return ",".join(assignees)
    except json.JSONDecodeError:
        return ""


# =============================================================================
# Issue Processing
# =============================================================================
def process_issue(owner: str, repo: str, issue_json: str) -> Optional[str]:
    """
    Process a single issue from JSON and create it on GitHub.

    Args:
        owner: Repository owner.
        repo: Repository name.
        issue_json: JSON string representing an issue.

    Returns:
        Issue URL or None on failure.

    Example:
        >>> issue_url = process_issue("owner", "repo", '{"title": "Bug", "body": "..."}')
        >>> print(issue_url)
    """
    # Extract issue data
    title = extract_title(issue_json)
    _body = extract_body(issue_json)  # type: ignore[unused-variable]
    labels = extract_labels(issue_json)
    milestone = extract_milestone(issue_json) or ""
    assignees = extract_assignees(issue_json)

    # Log the issue being created
    log(f"Creating issue: {title}")

    # Create the issue (using _body variable)
    issue_url = create_issue(owner, repo, title, _body, labels, milestone, assignees)
    if not issue_url:
        log_error(f"Failed to create issue: {title}")
        return None

    if DRY_RUN:
        log_dry_run(f"Issue created (dry-run): {title}")
        return issue_url

    # Extract issue number from URL
    issue_number = issue_url.split("/")[-1]
    log_success(f"Created issue: {title} (#{issue_number})")

    # Return the issue URL for further processing
    return issue_url


# =============================================================================
# Batch Issue Processing
# =============================================================================
def process_all_issues(owner: str, repo: str, json_file: str, project_id: Optional[str] = None) -> int:
    """
    Process all issues from a JSON file and create them on GitHub.

    Args:
        owner: Repository owner.
        repo: Repository name.
        json_file: JSON file path.
        project_id: Project ID (optional, for adding issues to Project V2).

    Returns:
        Number of issues created successfully.

    Example:
        >>> created = process_all_issues("owner", "repo", "issues.json", project_id)
        >>> assert created > 0
    """
    created = 0
    failed = 0
    skipped = 0

    log(f"Processing issues from: {json_file}")

    # Get total issue count
    total_issues = validate_and_count_issues(json_file)
    if total_issues is None:
        return 0

    log(f"Found {total_issues} issue(s) to process")

    # Process each issue
    try:
        with open(json_file, 'r', encoding='utf-8') as f:
            issues = json.load(f)

        for issue_data in issues:
            issue_json = json.dumps(issue_data)

            issue_url = process_issue(owner, repo, issue_json)
            if issue_url:
                created += 1

                # Add to Project V2 if specified
                if project_id:
                    issue_number = int(issue_url.split("/")[-1])
                    node_id = get_issue_node_id(owner, repo, issue_number)
                    if node_id:
                        add_issue_to_project(project_id, node_id)
                    else:
                        log_warning(f"Failed to get node ID for issue #{issue_number}")

            else:
                failed += 1

            # Rate limiting
            wait_rate_limit(1)

    except (json.JSONDecodeError, FileNotFoundError) as e:
        log_error(f"Error processing issues: {e}")
        return 0

    log(f"Processed {created} issues, {failed} failed, {skipped} skipped")
    return created


# =============================================================================
# Issue Template Functions
# =============================================================================
def generate_issue_json(
    title: str,
    body: str,
    labels: str = "",
    milestone: str = "",
    assignees: str = ""
) -> str:
    """
    Generate a sample issue JSON object.

    Args:
        title: Issue title.
        body: Issue body.
        labels: Comma-separated labels.
        milestone: Milestone title.
        assignees: Comma-separated assignees.

    Returns:
        JSON object string.

    Example:
        >>> json_str = generate_issue_json("Bug title", "Bug description", "bug,high-priority", "v1.0", "user1")
        >>> assert "Bug title" in json_str
    """
    # Build labels array
    labels_list: list[str] = []
    if labels:
        labels_list = [label.strip() for label in labels.split(",") if label.strip()]

    # Build assignees array
    assignees_list: list[str] = []
    if assignees:
        assignees_list = [assignee.strip() for assignee in assignees.split(",") if assignee.strip()]

    # Build milestone string (or null)
    milestone_value: Optional[str] = None
    if milestone:
        milestone_value = milestone

    # Construct the JSON object
    data = {
        "title": title,
        "body": body,
        "labels": labels_list,
        "milestone": milestone_value,
        "assignees": assignees_list,
    }

    return json.dumps(data, indent=2)


def generate_sample_issues(output_file: str) -> bool:
    """
    Generate a sample issues.json file.

    Args:
        output_file: Output file path.

    Returns:
        True if successful, False otherwise.

    Example:
        >>> success = generate_sample_issues("sample-issues.json")
        >>> assert success
    """
    sample_data = [
        {
            "title": "Sample Issue 1",
            "body": "This is a sample issue for testing purposes.\n\n- First task\n- Second task\n- Third task",
            "labels": ["bug", "good-first-issue"],
            "milestone": "v0.0 Foundations",
            "assignees": []
        },
        {
            "title": "Sample Issue 2",
            "body": "Another sample issue with different configuration.\n\nThis issue has no milestone or assignees.",
            "labels": ["enhancement"],
            "milestone": None,
            "assignees": ["user1", "user2"]
        }
    ]

    try:
        with open(output_file, 'w', encoding='utf-8') as f:
            json.dump(sample_data, f, indent=2)

        log_success(f"Sample issues file created: {output_file}")
        return True
    except IOError as e:
        log_error(f"Failed to create sample issues file: {e}")
        return False


# =============================================================================
# Issue Validation
# =============================================================================
def validate_issue(issue_json: str) -> bool:
    """
    Validate that an issue JSON object has required fields.

    Args:
        issue_json: JSON string representing an issue.

    Returns:
        True if valid, False otherwise.

    Example:
        >>> success = validate_issue('{"title": "Bug", "body": "..."}')
        >>> assert success
    """
    try:
        data = json.loads(issue_json)

        # Check title exists and is not empty
        title = data.get("title", "")
        if not title:
            log_error("Issue is missing required field: title")
            return False

        # Check body exists (can be empty string)
        body = data.get("body", "")

        log_verbose(f"Validated issue: {title}")
        return True

    except json.JSONDecodeError as e:
        log_error(f"Invalid JSON: {e}")
        return False


# =============================================================================
# Alias for cli.py compatibility
# =============================================================================
process_issues = process_all_issues


# Note: log_dry_run is imported from logging.py
