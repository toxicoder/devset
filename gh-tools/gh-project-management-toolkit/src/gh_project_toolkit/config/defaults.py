"""
Default configuration values for GitHub Project Management Toolkit.

This module contains all default configuration values that control the behavior
of the toolkit. These values can be overridden via environment variables or
command-line arguments.

Example:
    >>> from gh_project_toolkit.config.defaults import DEFAULT_REPO, SCRIPT_VERSION
    >>> print(f"Default repo: {DEFAULT_REPO}")
    >>> print(f"Script version: {SCRIPT_VERSION}")
"""

import os
from pathlib import Path

# =============================================================================
# Script Metadata
# =============================================================================
#: Script name (for display purposes)
SCRIPT_NAME: str = "setup-restoclaw.py"

#: Script version
SCRIPT_VERSION: str = "1.0.0"

#: Script description
SCRIPT_DESCRIPTION: str = "Creates GitHub milestones, labels, Project V2, and issues"

# =============================================================================
# GitHub Repository Configuration
# =============================================================================
#: Default GitHub repository (OWNER/REPO format)
DEFAULT_REPO: str = "toxicoder/RestoClaw"

#: Default issues JSON file path
DEFAULT_JSON_FILE: str = "issues.json"

#: Default project name for Project V2
DEFAULT_PROJECT_NAME: str = "RestoClaw Development Roadmap"

# =============================================================================
# Paths and Files
# =============================================================================
#: Path to the issues JSON file
ISSUES_JSON_PATH: str = DEFAULT_JSON_FILE

#: Temporary directory for processing (overridable)
TMP_DIR: str = os.environ.get("TMPDIR", "/tmp")

# =============================================================================
# GitHub API Configuration
# =============================================================================
#: GraphQL endpoint for GitHub API (for reference)
GITHUB_GRAPHQL_ENDPOINT: str = "https://api.github.com/graphql"

#: REST API base URL
GITHUB_REST_API_BASE: str = "https://api.github.com"

# =============================================================================
# Color Configuration (ANSI escape codes)
# =============================================================================
#: Default color for informational messages (bold blue)
COLOR_INFO: str = "\033[1;34m"

#: Default color for error messages (bold red)
COLOR_ERROR: str = "\033[1;31m"

#: Default color for success messages (bold green)
COLOR_SUCCESS: str = "\033[1;32m"

#: Default color for warning messages (bold yellow)
COLOR_WARN: str = "\033[1;33m"

#: Reset color
COLOR_RESET: str = "\033[0m"

# =============================================================================
# Script Behavior Flags
# =============================================================================
#: Dry-run mode flag (set via --dry-run)
DRY_RUN: bool = os.environ.get("DRY_RUN", "false").lower() == "true"

#: Verbose mode flag (set via --verbose)
VERBOSE: bool = os.environ.get("VERBOSE", "false").lower() == "true"

# =============================================================================
# Exit Codes
# =============================================================================
#: Success exit code
EXIT_SUCCESS: int = 0

#: General error exit code
EXIT_ERROR: int = 1

#: Missing command exit code
EXIT_MISSING_CMD: int = 2

#: Invalid configuration exit code
EXIT_INVALID_CONFIG: int = 3

#: API error exit code
EXIT_API_ERROR: int = 4


def get_script_dir() -> Path:
    """
    Get the directory containing the script.

    Returns:
        Path: The directory path containing the script file.

    Example:
        >>> script_dir = get_script_dir()
        >>> assert script_dir.exists()
    """
    return Path(__file__).parent.parent.parent


def get_script_path() -> Path:
    """
    Get the full path to the main script file.

    Returns:
        Path: The full path to the main script file.

    Example:
        >>> script_path = get_script_path()
        >>> assert script_path.exists()
    """
    return get_script_dir() / "setup-restoclaw.py"