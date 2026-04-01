"""
Milestone definitions and label groupings for GitHub Project Management Toolkit.

This module defines all milestone data and label groupings used by the toolkit.
Milestones are organized by version and contain descriptions that outline the
scope and purpose of each release.

Example:
    >>> from gh_project_toolkit.config.milestones import MILESTONES, ALL_LABELS
    >>> for title, desc in MILESTONES.items():
    ...     print(f"{title}: {desc}")
"""

from typing import Dict, List

# =============================================================================
# Milestone Definitions
# =============================================================================
#: Declare dictionary of milestones
#: Key: Version title (e.g., "v0.0 Foundations")
#: Value: Description of the milestone scope
MILESTONES: Dict[str, str] = {
    "v0.0 Foundations": "Repo, Docker, basic NemoClaw/OpenClaw install, logging, CI.",
    "v0.1 Email Digest MVP": "4x daily digests + cross-channel conversational follow-up.",
    "v0.2 Auto-Reply Drafting": "One-click AI-draft replies with approval gate.",
    "v0.3 Inventory + Supplier Ordering": "Daily stock-check, low-stock alerts, suggested POs, one-click order placement.",
    "v0.4 POS Sync & Daily Sales Brief": "Pull sales from Toast/Square/Lightspeed, produce sales brief, tie to inventory.",
    "v0.5 Review Monitoring & Response Generation": "Scrape reviews, sentiment-flag negatives, draft response.",
    "v1.0 Full Restaurant OS": "Staff scheduling, reservation/wait-list management, marketing automation, read-only admin dashboard.",
}


#: All labels organized by category
ALL_LABELS: List[str] = [
    # Phase labels
    "mvp",
    "phase:foundations",
    "phase:core-skill",
    "phase:integrations",
    "phase:conversation",
    "phase:security",
    "phase:infrastructure",
    # Integration labels
    "integration:google",
    "integration:twilio",
    "integration:nemoclaw",
    # Skill labels
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
    # Priority labels
    "priority:high",
    "priority:medium",
    "good-first-issue",
    # Category labels
    "documentation",
    "testing",
    "infrastructure",
    "onboarding",
    "configuration",
    "ci-cd",
    "observability",
    "e2e",
    "performance",
    # Milestone labels
    "milestone:v0.0",
    "milestone:v0.1",
    "milestone:v0.2",
    "milestone:v0.3",
    "milestone:v0.4",
    "milestone:v0.5",
    "milestone:v1.0",
]

# =============================================================================
# Label Colors
# =============================================================================
#: Label colors follow a pattern based on category
LABEL_COLORS: Dict[str, str] = {
    "priority:high": "e11d21",  # Red for high priority
    "priority:medium": "d93f0b",  # Orange for medium priority
    "good-first-issue": "008672",  # Green for beginner friendly
    "documentation": "0075ca",  # Blue for docs
    "testing": "be805e",  # Brown for testing
    "infrastructure": "1d76db",  # Blue for infrastructure
    "phase:foundations": "58a6ff",  # Blue for phases
    "phase:core-skill": "58a6ff",
    "phase:integrations": "58a6ff",
    "phase:conversation": "58a6ff",
    "phase:security": "58a6ff",
    "phase:infrastructure": "58a6ff",
    "integration:google": "1677e2",  # Darker blue for integrations
    "integration:twilio": "1677e2",
    "integration:nemoclaw": "1677e2",
    "skill:digest": "8b5cf6",  # Purple for skills
    "skill:inventory": "8b5cf6",
    "skill:pos": "8b5cf6",
    "skill:review": "8b5cf6",
    "skill:staff": "8b5cf6",
    "skill:reservation": "8b5cf6",
    "skill:marketing": "8b5cf6",
    "skill:order": "8b5cf6",
    "skill:sales-brief": "8b5cf6",
    "skill:sentiment": "8b5cf6",
    "skill:review-response": "8b5cf6",
    "milestone:v0.0": "d2b48c",  # Tan for milestones
    "milestone:v0.1": "d2b48c",
    "milestone:v0.2": "d2b48c",
    "milestone:v0.3": "d2b48c",
    "milestone:v0.4": "d2b48c",
    "milestone:v0.5": "d2b48c",
    "milestone:v1.0": "d2b48c",
    # Default gray for unknown labels
    "*": "ededed",
}


# =============================================================================
# Functions
# =============================================================================
def get_milestone_titles() -> List[str]:
    """
    Get all milestone titles as a list.

    Returns:
        List[str]: A list of all milestone titles.

    Example:
        >>> titles = get_milestone_titles()
        >>> assert "v0.0 Foundations" in titles
    """
    return list(MILESTONES.keys())


def get_milestone_description(title: str) -> str:
    """
    Get milestone description by title.

    Args:
        title: The milestone title.

    Returns:
        The milestone description, or empty string if not found.

    Example:
        >>> desc = get_milestone_description("v0.0 Foundations")
        >>> assert "Repo" in desc
        >>> desc = get_milestone_description("NonExistent")
        >>> assert desc == ""
    """
    return MILESTONES.get(title, "")


def get_all_milestones() -> List[Dict[str, str]]:
    """
    Get all milestones as a list of dictionaries.

    Returns:
        List[Dict[str, str]]: A list of milestone dictionaries with title and description.

    Example:
        >>> milestones = get_all_milestones()
        >>> assert len(milestones) == 7
    """
    return [
        {"title": title, "description": description}
        for title, description in MILESTONES.items()
    ]


def count_milestones() -> int:
    """
    Count total number of milestones.

    Returns:
        int: The number of milestones defined.

    Example:
        >>> count = count_milestones()
        >>> assert count == 7
    """
    return len(MILESTONES)


def get_milestones_json() -> str:
    """
    Get milestones in JSON format.

    Returns:
        str: A JSON string representing the milestones.

    Example:
        >>> json_str = get_milestones_json()
        >>> assert '"title": "v0.0 Foundations"' in json_str
    """
    import json

    return json.dumps(
        [
            {"title": title, "description": description}
            for title, description in MILESTONES.items()
        ]
    )


def count_labels() -> int:
    """
    Count total number of labels.

    Returns:
        int: The number of labels defined.

    Example:
        >>> count = count_labels()
        >>> assert count == 37
    """
    return len(ALL_LABELS)


def get_label_color(label: str) -> str:
    """
    Get label color for a specific label.

    Label colors follow a pattern based on category.

    Args:
        label: The label name.

    Returns:
        6-character hex color code.

    Example:
        >>> color = get_label_color("priority:high")
        >>> assert color == "e11d21"
        >>> color = get_label_color("unknown-label")
        >>> assert color == "ededed"
    """
    # Check for exact match first
    if label in LABEL_COLORS:
        return LABEL_COLORS[label]

    # Check for category patterns
    for pattern, color in LABEL_COLORS.items():
        if pattern != "*" and label.startswith(pattern.split(":")[0] + ":"):
            return color

    # Default color
    return LABEL_COLORS["*"]


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


def get_label_count(category: str) -> int:
    """
    Get count of labels in a category.

    Args:
        category: The category name (phase, integration, skill, priority, category, milestone, or "all").

    Returns:
        int: The number of labels in the category.

    Example:
        >>> count = get_label_count("phase")
        >>> assert count == 7
        >>> count = get_label_count("all")
        >>> assert count == 37
    """
    categories = get_all_labels_by_category()

    if category == "all":
        return len(ALL_LABELS)

    if category in categories:
        return len(categories[category])

    return 0