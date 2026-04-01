"""
Label management functions for GitHub Project Management Toolkit.

This module provides functions for managing GitHub labels, including
creating labels, organizing them by category, and generating label data.

Example:
    >>> from gh_project_toolkit.lib.labels import create_all_labels, get_label_color
    >>> created = create_all_labels("owner", "repo", "ededed")
    >>> color = get_label_color("priority:high")
"""

from typing import Dict, List, Any

# =============================================================================
# Configuration
# =============================================================================
# Define fallback values at module level before try block (avoids mypy "already defined" errors)
_all_labels_fallback: List[str] = []

def get_label_color_from_config(label: str) -> str:
    """Get label color from config fallback."""
    return "ededed"

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

def create_label(owner: str, repo: str, name: str, color: str, description: str = "") -> bool:
    """Create label fallback."""
    return False

def get_all_labels(owner: str, repo: str) -> List[Dict[str, Any]]:
    """Get all labels fallback."""
    return []

# ALL_LABELS is defined at module level before try block
ALL_LABELS: List[str] = []

# Try to import from the actual package
try:
    from gh_project_toolkit.config.milestones import (
        ALL_LABELS as _all_labels_imported,
        get_label_color as _get_label_color_from_config,
    )
    from gh_project_toolkit.lib.logging import (
        log_verbose as _log_verbose,
        log_error as _log_error,
        log_success as _log_success,
        log as _log,
    )
    from gh_project_toolkit.lib.github_api import (
        create_label as _create_label,
        get_all_labels as _get_all_labels,
    )
    # Use imported values
    ALL_LABELS = _all_labels_imported
    log_verbose = _log_verbose
    log_error = _log_error
    log_success = _log_success
    log = _log
    create_label = _create_label
    get_all_labels = _get_all_labels
    # Override the fallback function with the imported one
    def get_label_color_from_config(label: str) -> str:
        return _get_label_color_from_config(label)
except ImportError:
    # Use fallback values defined above
    ALL_LABELS = _all_labels_fallback
    pass


# =============================================================================
# Label Groupings
# =============================================================================
def get_all_labels_by_category() -> Dict[str, List[str]]:
    """
    Get all labels organized by category.

    Returns:
        Dict[str, List[str]]: A dictionary with categories as keys and label lists as values.

    Example:
        >>> labels = get_all_labels_by_category()
        >>> assert "phase" in labels
        >>> assert "mvp" in labels["phase"]
    """
    return {
        "phase": [
            "mvp",
            "phase:foundations",
            "phase:core-skill",
            "phase:integrations",
            "phase:conversation",
            "phase:security",
            "phase:infrastructure",
        ],
        "integration": [
            "integration:google",
            "integration:twilio",
            "integration:nemoclaw",
        ],
        "skill": [
            "skill:digest",
            "skill:inventory",
            "skill:pos",
            "skill:review",
            "skill:staff",
            "skill:reservation",
            "skill:marketing",
            "skill:order",
            "skill:sales-brief",
            "skill:sentiment",
            "skill:review-response",
        ],
        "priority": [
            "priority:high",
            "priority:medium",
            "good-first-issue",
        ],
        "category": [
            "documentation",
            "testing",
            "infrastructure",
            "onboarding",
            "configuration",
            "ci-cd",
            "observability",
            "e2e",
            "performance",
        ],
        "milestone": [
            "milestone:v0.0",
            "milestone:v0.1",
            "milestone:v0.2",
            "milestone:v0.3",
            "milestone:v0.4",
            "milestone:v0.5",
            "milestone:v1.0",
        ],
    }


def get_all_labels_array() -> List[str]:
    """
    Get all labels as a flat array.

    Returns:
        List[str]: A list of all label names.

    Example:
        >>> labels = get_all_labels_array()
        >>> assert "mvp" in labels
    """
    return list(ALL_LABELS)


# =============================================================================
# Label Creation
# =============================================================================
def create_all_labels(owner: str, repo: str, color: str = "ededed") -> int:
    """
    Create all labels in the repository.

    Args:
        owner: Repository owner.
        repo: Repository name.
        color: Label color (6-character hex, default: ededed).

    Returns:
        Number of labels created.

    Example:
        >>> created = create_all_labels("owner", "repo", "ededed")
        >>> assert created > 0
    """
    created = 0
    already_exists = 0

    log("Creating labels...")

    for label in ALL_LABELS:
        if create_label(owner, repo, label, color, "auto-generated"):
            created += 1
            log_verbose(f"Created label: {label}")
        else:
            # Check if it already exists (not an error)
            labels = get_all_labels(owner, repo)
            if any(lbl.get("name") == label for lbl in labels):
                log_verbose(f"Label already exists: {label}")
                already_exists += 1

    log_success(f"Labels: {created} created, {already_exists} already existed")
    return created


def create_labels_by_category(owner: str, repo: str, category: str, color: str = "ededed") -> int:
    """
    Create labels from a category.

    Args:
        owner: Repository owner.
        repo: Repository name.
        category: Category name (phase, integration, skill, priority, category, milestone).
        color: Label color (6-character hex, default: ededed).

    Returns:
        Number of labels created.

    Example:
        >>> created = create_labels_by_category("owner", "repo", "phase", "ededed")
        >>> assert created > 0
    """
    categories = get_all_labels_by_category()

    if category not in categories:
        log_error(f"Unknown category: {category}")
        return 0

    labels = categories[category]
    created = 0

    log(f"Creating labels for category: {category}")

    for label in labels:
        if create_label(owner, repo, label, color, "auto-generated"):
            created += 1
            log_verbose(f"Created label: {label}")

    log_success(f"Created {created} label(s) for category: {category}")
    return created


# =============================================================================
# Label Information
# =============================================================================
def get_label_count(category: str) -> int:
    """
    Get count of labels in a category.

    Args:
        category: Category name.

    Returns:
        Number of labels in the category.

    Example:
        >>> count = get_label_count("phase")
        >>> assert count == 7
    """
    categories = get_all_labels_by_category()

    if category == "all":
        return len(ALL_LABELS)

    if category in categories:
        return len(categories[category])

    return 0


def get_label_color(label: str) -> str:
    """
    Get label color for a specific label.

    Label colors follow a pattern based on category.

    Args:
        label: Label name.

    Returns:
        6-character hex color code.

    Example:
        >>> color = get_label_color("priority:high")
        >>> assert color == "e11d21"
    """
    return get_label_color_from_config(label)