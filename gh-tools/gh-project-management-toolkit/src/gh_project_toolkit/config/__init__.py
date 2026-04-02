"""
Configuration module for GitHub Project Management Toolkit.

This module provides configuration management for the toolkit, including
default values, milestone definitions, and label groupings.
"""

from .defaults import (
    DEFAULT_PROJECT_NAME,
    DEFAULT_REPO,
    DEFAULT_JSON_FILE,
    ISSUES_JSON_PATH,
    TMP_DIR,
    GITHUB_GRAPHQL_ENDPOINT,
    GITHUB_REST_API_BASE,
    SCRIPT_NAME,
    SCRIPT_VERSION,
    SCRIPT_DESCRIPTION,
    DRY_RUN,
    VERBOSE,
    EXIT_SUCCESS,
    EXIT_ERROR,
    EXIT_MISSING_CMD,
    EXIT_INVALID_CONFIG,
    EXIT_API_ERROR,
)

from .milestones import (
    MILESTONES,
    ALL_LABELS,
    get_milestone_titles,
    get_milestone_description,
    get_all_milestones,
    count_milestones,
    get_milestones_json,
    count_labels,
)

__all__ = [
    # Defaults
    "DEFAULT_PROJECT_NAME",
    "DEFAULT_REPO",
    "DEFAULT_JSON_FILE",
    "ISSUES_JSON_PATH",
    "TMP_DIR",
    "GITHUB_GRAPHQL_ENDPOINT",
    "GITHUB_REST_API_BASE",
    "SCRIPT_NAME",
    "SCRIPT_VERSION",
    "SCRIPT_DESCRIPTION",
    "DRY_RUN",
    "VERBOSE",
    "EXIT_SUCCESS",
    "EXIT_ERROR",
    "EXIT_MISSING_CMD",
    "EXIT_INVALID_CONFIG",
    "EXIT_API_ERROR",
    # Milestones
    "MILESTONES",
    "ALL_LABELS",
    "get_milestone_titles",
    "get_milestone_description",
    "get_all_milestones",
    "count_milestones",
    "get_milestones_json",
    "count_labels",
]