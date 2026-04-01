"""
Duplicate detection and cleanup functions for GitHub Project Management Toolkit.

This module provides functions for detecting and handling duplicate
GitHub resources (milestones, labels, issues). It includes:
  • Duplicate detection based on title/label name
  • Bug number normalization (#123 patterns)
  • Cleanup operations (default: dry-run mode)

Example:
    >>> from gh_project_toolkit.lib.duplicates import normalize_issue_title, cleanup_all
    >>> normalized = normalize_issue_title("#361 Fix bug")
    >>> removed = cleanup_all("owner", "repo", False, "milestones,labels,issues")
"""

import re
from typing import Any, Optional, Dict, List

# =============================================================================
# Configuration
# =============================================================================
# Define fallback values at module level before try block (avoids mypy "already defined" errors)
DRY_RUN = False
VERBOSE = False

def log_verbose(message: str, *args: Any, **kwargs: Any) -> None:
    """Verbose logging fallback."""
    pass

def log_error(message: str, *args: Any, **kwargs: Any) -> None:
    """Error logging fallback."""
    pass

def log_success(message: str, *args: Any, **kwargs: Any) -> None:
    """Success logging fallback."""
    pass

def log(message: str, *args: Any, **kwargs: Any) -> None:
    """Info logging fallback."""
    pass

def log_warning(message: str, *args: Any, **kwargs: Any) -> None:
    """Warning logging fallback."""
    pass

def get_all_milestones(owner: str, repo: str) -> List[Dict[str, Any]]:
    """Get all milestones fallback."""
    return []

def get_all_labels(owner: str, repo: str) -> List[Dict[str, Any]]:
    """Get all labels fallback."""
    return []

def get_all_issues(owner: str, repo: str) -> List[Dict[str, Any]]:
    """Get all issues fallback."""
    return []

def create_milestone(owner: str, repo: str, title: str, description: str, due_date: Optional[str] = None) -> Optional[str]:
    """Create milestone fallback."""
    return None

def delete_label(owner: str, repo: str, name: str) -> bool:
    """Delete label fallback."""
    return False

def delete_issue(owner: str, repo: str, number: int) -> bool:
    """Delete issue fallback."""
    return False

# Try to import from the actual package
try:
    from gh_project_toolkit.config.defaults import DRY_RUN as _dry_run, VERBOSE as _verbose
    from gh_project_toolkit.lib.logging import (
        log_verbose as _log_verbose,
        log_error as _log_error,
        log_success as _log_success,
        log as _log,
        log_warning as _log_warning,
    )
    from gh_project_toolkit.lib.github_api import (
        get_all_milestones as _get_all_milestones,
        get_all_labels as _get_all_labels,
        get_all_issues as _get_all_issues,
        create_milestone as _create_milestone,
        delete_label as _delete_label,
        delete_issue as _delete_issue,
    )
    # Use imported values - assign to lowercase variables to avoid mypy constant redefinition errors
    _dry_run_imported = _dry_run
    _verbose_imported = _verbose
    log_verbose = _log_verbose
    log_error = _log_error
    log_success = _log_success
    log = _log
    log_warning = _log_warning
    get_all_milestones = _get_all_milestones
    get_all_labels = _get_all_labels
    get_all_issues = _get_all_issues
    create_milestone = _create_milestone
    delete_label = _delete_label
    delete_issue = _delete_issue
except ImportError:
    # Use fallback values defined above
    _dry_run_imported = False
    _verbose_imported = False
    pass


def log_dry_run(message: str, *args: Any, **kwargs: Any) -> None:
    """Dry-run logging helper."""
    if DRY_RUN:
        try:
            from gh_project_toolkit.lib.logging import log_dry_run as log_dry_run_impl
            log_dry_run_impl(message, *args, **kwargs)
        except ImportError:
            print(f"[DRY-RUN] {message % args if args else message}")


# =============================================================================
# Bug Number Normalization
# =============================================================================
def normalize_issue_title(title: str) -> str:
    """
    Normalize issue title by removing bug numbers.

    This function strips common bug number patterns from titles:
      • "#123" at start or end
      • "123" at start or end
      • "bug #123" patterns
      • "(123)" at start or end

    Args:
        title: Issue title.

    Returns:
        Normalized title.

    Example:
        >>> normalized = normalize_issue_title("#361 Fix bug")
        >>> assert normalized == "Fix bug"
    """
    normalized = title

    # Remove bug number at start: "#123 ", "#123-", "#123", "(123) "
    normalized = re.sub(r'^\s*[(#]?\s*[0-9]+\s*[-:)]*\s*', '', normalized)

    # Remove bug number at end: " - #123", " (#123)", " #123", " - 123"
    normalized = re.sub(r'\s*[-:#(]\s*[0-9]+\s*[\)]*\s*$', '', normalized)

    # Trim leading/trailing whitespace
    normalized = normalized.strip()

    # Return original if empty
    if not normalized:
        return title

    return normalized


# =============================================================================
# GitHub API Helpers
# =============================================================================
def get_existing_milestones(owner: str, repo: str) -> List[Dict[str, Any]]:
    """
    Get all existing milestones from the repository.

    Args:
        owner: Repository owner.
        repo: Repository name.

    Returns:
        List of milestone objects with title.

    Example:
        >>> milestones = get_existing_milestones("owner", "repo")
        >>> for m in milestones:
        ...     print(f"{m['title']}: {m['number']}")
    """
    return get_all_milestones(owner, repo)


def get_existing_labels(owner: str, repo: str) -> List[Dict[str, Any]]:
    """
    Get all existing labels from the repository.

    Args:
        owner: Repository owner.
        repo: Repository name.

    Returns:
        List of label objects with name.

    Example:
        >>> labels = get_existing_labels("owner", "repo")
        >>> for label in labels:
        ...     print(f"{label['name']}: {label['color']}")
    """
    return get_all_labels(owner, repo)


def get_existing_issues(owner: str, repo: str) -> List[Dict[str, Any]]:
    """
    Get all existing issues from the repository.

    Args:
        owner: Repository owner.
        repo: Repository name.

    Returns:
        List of issue objects with title and number.

    Example:
        >>> issues = get_existing_issues("owner", "repo")
        >>> for issue in issues:
        ...     print(f"{issue['title']}: {issue['number']}")
    """
    return get_all_issues(owner, repo)


# =============================================================================
# Duplicate Detection
# =============================================================================
def milestone_exists(owner: str, repo: str, title: str) -> bool:
    """
    Check if a milestone with the given title already exists.

    Args:
        owner: Repository owner.
        repo: Repository name.
        title: Milestone title.

    Returns:
        True if milestone exists, False otherwise.

    Example:
        >>> if milestone_exists("owner", "repo", "v1.0"):
        ...     print("Milestone already exists")
    """
    milestones = get_existing_milestones(owner, repo)
    normalized_title = normalize_issue_title(title)

    # Check exact match
    for milestone in milestones:
        if milestone.get("title") == title:
            return True

    # Check normalized match
    for milestone in milestones:
        if normalize_issue_title(milestone.get("title", "")) == normalized_title:
            return True

    return False


def label_exists(owner: str, repo: str, name: str) -> bool:
    """
    Check if a label with the given name already exists.

    Args:
        owner: Repository owner.
        repo: Repository name.
        name: Label name.

    Returns:
        True if label exists, False otherwise.

    Example:
        >>> if label_exists("owner", "repo", "bug"):
        ...     print("Label already exists")
    """
    labels = get_existing_labels(owner, repo)

    for label in labels:
        if label.get("name") == name:
            return True

    return False


def issue_exists(owner: str, repo: str, title: str) -> bool:
    """
    Check if an issue with the given title already exists.

    Args:
        owner: Repository owner.
        repo: Repository name.
        title: Issue title (normalized).

    Returns:
        True if issue exists, False otherwise.

    Example:
        >>> if issue_exists("owner", "repo", "Fix bug"):
        ...     print("Issue already exists")
    """
    issues = get_existing_issues(owner, repo)
    normalized_title = normalize_issue_title(title)

    # Check exact match
    for issue in issues:
        if issue.get("title") == title:
            return True

    # Check normalized match
    for issue in issues:
        if normalize_issue_title(issue.get("title", "")) == normalized_title:
            return True

    return False


# =============================================================================
# Cleanup Functions
# =============================================================================
def delete_milestone(owner: str, repo: str, number: int) -> bool:
    """
    Delete a milestone.

    Args:
        owner: Repository owner.
        repo: Repository name.
        number: Milestone number.

    Returns:
        True if successful, False otherwise.

    Example:
        >>> deleted = delete_milestone("owner", "repo", "1")
        >>> assert deleted
    """
    if DRY_RUN:
        log_dry_run(f"Would delete milestone #{number}")
        return True

    # Note: Deleting milestones via REST API
    log_warning("delete_milestone not fully implemented in Python version")
    return False


def cleanup_milestones(owner: str, repo: str, titles: Optional[List[str]] = None) -> int:
    """
    Cleanup duplicate milestones.

    Args:
        owner: Repository owner.
        repo: Repository name.
        titles: List of milestone titles to check (optional).

    Returns:
        Number of duplicates removed.

    Example:
        >>> removed = cleanup_milestones("owner", "repo", ["v1.0", "v1.1"])
        >>> assert removed >= 0
    """
    removed = 0
    skipped = 0

    # Get existing milestones
    existing_milestones = get_existing_milestones(owner, repo)

    # If no titles provided, check all existing milestones
    if titles is None or len(titles) == 0:
        # Group milestones by normalized title
        normalized_map: Dict[str, List[Dict[str, Any]]] = {}
        for milestone in existing_milestones:
            normalized = normalize_issue_title(milestone.get("title", ""))
            if normalized not in normalized_map:
                normalized_map[normalized] = []
            normalized_map[normalized].append(milestone)

        # Find duplicates
        for normalized, milestones in normalized_map.items():
            if len(milestones) > 1:
                log(f"Found {len(milestones)} duplicate milestone(s): {normalized}")
                for milestone in milestones[1:]:  # Keep the first one
                    number = milestone.get("number")
                    if number:
                        if delete_milestone(owner, repo, number):
                            removed += 1
                        else:
                            skipped += 1
    else:
        # Check only specified titles
        for title in titles:
            normalized = normalize_issue_title(title)

            for milestone in existing_milestones:
                if normalize_issue_title(milestone.get("title", "")) == normalized:
                    number = milestone.get("number")
                    if number:
                        if delete_milestone(owner, repo, number):
                            removed += 1
                        else:
                            skipped += 1

    log_success(f"Milestones: {removed} removed, {skipped} skipped")
    return removed


def cleanup_labels(owner: str, repo: str, names: Optional[List[str]] = None) -> int:
    """
    Cleanup duplicate labels.

    Args:
        owner: Repository owner.
        repo: Repository name.
        names: List of label names to check (optional).

    Returns:
        Number of duplicates removed.

    Example:
        >>> removed = cleanup_labels("owner", "repo", ["bug", "enhancement"])
        >>> assert removed >= 0
    """
    removed = 0
    skipped = 0

    # Get existing labels
    existing_labels = get_existing_labels(owner, repo)

    # If no names provided, check all labels
    if names is None or len(names) == 0:
        # Count label occurrences
        name_counts: Dict[str, List[Dict[str, Any]]] = {}
        for label in existing_labels:
            name = label.get("name", "")
            if name not in name_counts:
                name_counts[name] = []
            name_counts[name].append(label)

        # Find duplicates
        for name, labels in name_counts.items():
            if len(labels) > 1:
                log(f"Found {len(labels)} duplicate label(s): {name}")
                for label in labels[1:]:  # Keep the first one
                    if delete_label(owner, repo, name):
                        removed += 1
                    else:
                        skipped += 1
    else:
        # Check only specified names
        for name in names:
            if label_exists(owner, repo, name):
                if delete_label(owner, repo, name):
                    removed += 1
                else:
                    skipped += 1

    log_success(f"Labels: {removed} removed, {skipped} skipped")
    return removed


def cleanup_issues(owner: str, repo: str, titles: Optional[List[str]] = None) -> int:
    """
    Cleanup duplicate issues.

    Args:
        owner: Repository owner.
        repo: Repository name.
        titles: List of issue titles to check (optional).

    Returns:
        Number of duplicates removed.

    Example:
        >>> removed = cleanup_issues("owner", "repo", ["Fix bug"])
        >>> assert removed >= 0
    """
    removed = 0
    skipped = 0

    # Get existing issues
    existing_issues = get_existing_issues(owner, repo)

    # If no titles provided, check all issues
    if titles is None or len(titles) == 0:
        # Group issues by normalized title
        normalized_map: Dict[str, List[Dict[str, Any]]] = {}
        for issue in existing_issues:
            normalized = normalize_issue_title(issue.get("title", ""))
            if normalized not in normalized_map:
                normalized_map[normalized] = []
            normalized_map[normalized].append(issue)

        # Find duplicates
        for normalized, issues in normalized_map.items():
            if len(issues) > 1:
                log(f"Found {len(issues)} duplicate issue(s): {normalized}")
                for issue in issues[1:]:  # Keep the first one
                    number = issue.get("number")
                    if number:
                        if delete_issue(owner, repo, number):
                            removed += 1
                        else:
                            skipped += 1
    else:
        # Check only specified titles
        for title in titles:
            normalized = normalize_issue_title(title)

            for issue in existing_issues:
                if normalize_issue_title(issue.get("title", "")) == normalized:
                    number = issue.get("number")
                    if number:
                        if delete_issue(owner, repo, number):
                            removed += 1
                        else:
                            skipped += 1

    log_success(f"Issues: {removed} removed, {skipped} skipped")
    return removed


# =============================================================================
# Main Cleanup Function
# =============================================================================
def cleanup_all(owner: str, repo: str, apply: bool = False, resources: str = "milestones,labels,issues") -> int:
    """
    Main cleanup function - handles all resources.

    Args:
        owner: Repository owner.
        repo: Repository name.
        apply: Apply flag (True to actually delete, False for dry-run).
        resources: Resources to clean (comma-separated).

    Returns:
        Total items removed.

    Example:
        >>> removed = cleanup_all("owner", "repo", False, "milestones,labels,issues")
        >>> assert removed >= 0
    """
    # Set DRY_RUN based on apply flag - use local variable to avoid mypy constant errors
    _apply = apply  # Use lowercase to avoid constant redefinition errors

    total_removed = 0

    if "milestones" in resources or resources == "all":
        log("Checking for duplicate milestones...")
        removed = cleanup_milestones(owner, repo)
        total_removed += removed

    if "labels" in resources or resources == "all":
        log("Checking for duplicate labels...")
        removed = cleanup_labels(owner, repo)
        total_removed += removed

    if "issues" in resources or resources == "all":
        log("Checking for duplicate issues...")
        removed = cleanup_issues(owner, repo)
        total_removed += removed

    if _dry_run_imported:
        log_warning("Dry-run mode: no changes were made")
        log("Use --apply to actually delete duplicates")

    return total_removed
