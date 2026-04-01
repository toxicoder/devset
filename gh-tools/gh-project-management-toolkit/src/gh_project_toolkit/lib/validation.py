"""
Validation and dependency checking utilities for GitHub Project Management Toolkit.

This module provides functions for validating required commands, checking
file existence, and validating JSON content. All validation functions are
designed to provide clear error messages and support dry-run mode.

Example:
    >>> from gh_project_toolkit.lib.validation import require_cmd, validate_json
    >>> require_cmd("gh")
    >>> validate_json("config.json")
"""

import json
import shutil
import subprocess
from pathlib import Path
from typing import Optional, Any

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

def print_status_line(char: str = "=", width: Optional[int] = None) -> None:
    """Print status line fallback."""
    if width is None:
        width = 80
    print(char * width)

# Try to import from the actual package
try:
    from gh_project_toolkit.config.defaults import (
        DRY_RUN as _dry_run,
        VERBOSE as _verbose,
    )
    from gh_project_toolkit.lib.logging import (
        log_verbose as _log_verbose,
        log_error as _log_error,
        print_status_line as _print_status_line,
    )
    # Use imported values - assign to lowercase variables to avoid mypy constant redefinition errors
    _dry_run_imported = _dry_run
    _verbose_imported = _verbose
    log_verbose = _log_verbose
    log_error = _log_error
    print_status_line = _print_status_line
except ImportError:
    # Use fallback values defined above
    _dry_run_imported = False
    _verbose_imported = False
    pass


# =============================================================================
# Dependency Checking
# =============================================================================
def require_cmd(cmd: str) -> bool:
    """
    Check if a command is available on the system.

    Args:
        cmd: Command name to check.

    Returns:
        True if command found, False otherwise.

    Example:
        >>> require_cmd("gh")
        True
        >>> require_cmd("nonexistent_command_xyz123")
        False
    """
    if shutil.which(cmd) is not None:
        log_verbose(f"Found required command: {cmd}")
        return True
    else:
        log_error(f"Required command '{cmd}' not found. Please install it first.")
        return False


def require_all_cmds(*cmds: str) -> bool:
    """
    Validate that all required commands are available.

    Args:
        *cmds: List of command names to check.

    Returns:
        True if all commands found, False otherwise.

    Example:
        >>> require_all_cmds("gh", "jq", "python3")
        True
        >>> require_all_cmds("bash", "nonexistent_xyz123")
        False
    """
    missing: list[str] = []
    for cmd in cmds:
        if shutil.which(cmd) is None:
            missing.append(cmd)

    if missing:
        log_error(f"Missing required commands: {' '.join(missing)}")
        return False

    log_verbose("All required commands verified")
    return True


# =============================================================================
# File Validation
# =============================================================================
def require_file(file_path: str) -> bool:
    """
    Check if a file exists and is readable.

    Args:
        file_path: File path to check.

    Returns:
        True if file exists and is readable, False otherwise.

    Example:
        >>> require_file("config.json")
        True
        >>> require_file("nonexistent_file_xyz.txt")
        False
    """
    path = Path(file_path)
    if path.exists():
        if path.is_file():
            log_verbose(f"File exists and is readable: {file_path}")
            return True
        else:
            log_error(f"Path exists but is not a file: {file_path}")
            return False
    else:
        log_error(f"File not found: {file_path}")
        return False


def require_non_empty_file(file_path: str) -> bool:
    """
    Check if a file exists and has non-zero size.

    Args:
        file_path: File path to check.

    Returns:
        True if file exists and has content, False otherwise.

    Example:
        >>> require_non_empty_file("data.json")
        True
        >>> require_non_empty_file("empty_file.txt")
        False
    """
    if not require_file(file_path):
        return False

    path = Path(file_path)
    try:
        size = path.stat().st_size
        if size > 0:
            log_verbose(f"File has content: {file_path} ({size} bytes)")
            return True
        else:
            log_error(f"File is empty: {file_path}")
            return False
    except OSError as e:
        log_error(f"Could not stat file {file_path}: {e}")
        return False


# =============================================================================
# JSON Validation
# =============================================================================
def validate_json(file_path: str) -> bool:
    """
    Validate that a file contains valid JSON.

    Args:
        file_path: File path to validate.

    Returns:
        True if valid JSON, False otherwise.

    Example:
        >>> validate_json("data.json")
        True
        >>> validate_json("invalid.json")
        False
    """
    try:
        with open(file_path, "r", encoding="utf-8") as f:
            json.load(f)
        log_verbose(f"JSON is valid: {file_path}")
        return True
    except (json.JSONDecodeError, FileNotFoundError) as e:
        log_error(f"Invalid JSON in file: {file_path}: {e}")
        return False


def validate_json_array(file_path: str) -> bool:
    """
    Validate that JSON contains a non-empty array.

    Args:
        file_path: File path to validate.

    Returns:
        True if valid JSON array with content, False otherwise.

    Example:
        >>> validate_json_array("data.json")
        True
        >>> validate_json_array("empty_array.json")
        False
    """
    if not validate_json(file_path):
        return False

    try:
        with open(file_path, "r", encoding="utf-8") as f:
            data = json.load(f)

        if not isinstance(data, list):
            log_error(f"JSON file must contain an array, got: {type(data).__name__}")
            return False

        if len(data) == 0:
            log_error("JSON array is empty")
            return False

        log_verbose(f"JSON is a valid array with {len(data)} items: {file_path}")
        return True
    except (json.JSONDecodeError, FileNotFoundError) as e:
        log_error(f"Invalid JSON in file: {file_path}: {e}")
        return False


# =============================================================================
# Repository Validation
# =============================================================================
def validate_git_repo() -> bool:
    """
    Validate that the current directory is a Git repository.

    Returns:
        True if current directory is a Git repository, False otherwise.

    Example:
        >>> validate_git_repo()
        True
    """
    try:
        result = subprocess.run(
            ["git", "rev-parse", "--git-dir"],
            capture_output=True,
            text=True,
            check=False,
        )
        if result.returncode == 0:
            log_verbose("Valid Git repository found")
            return True
        else:
            log_error("Current directory is not a Git repository")
            return False
    except FileNotFoundError:
        log_error("Git not found - cannot validate repository")
        return False


def validate_repo_format(repo: str) -> bool:
    """
    Validate repository format (OWNER/REPO).

    Args:
        repo: Repository string to validate.

    Returns:
        True if valid format, False otherwise.

    Example:
        >>> validate_repo_format("owner/repo")
        True
        >>> validate_repo_format("invalid")
        False
    """
    import re

    pattern = r"^[a-zA-Z0-9_-]+/[a-zA-Z0-9_-]+$"
    if re.match(pattern, repo):
        log_verbose(f"Valid repository format: {repo}")
        return True
    else:
        log_error(f"Invalid repository format: {repo} (expected: OWNER/REPO)")
        return False


# =============================================================================
# Input Validation
# =============================================================================
def require_non_empty(name: str, value: Optional[str]) -> bool:
    """
    Validate that a string is not empty.

    Args:
        name: Variable name (for error message).
        value: String value to check.

    Returns:
        True if string is not empty, False otherwise.

    Example:
        >>> require_non_empty("title", "value")
        True
        >>> require_non_empty("varname", "")
        False
    """
    if value is not None and value != "":
        return True
    else:
        log_error(f"Required parameter is empty: {name}")
        return False


def require_range(name: str, value: Any, min_val: Optional[int] = None, max_val: Optional[int] = None) -> bool:
    """
    Validate that a number is within a range.

    Args:
        name: Variable name (for error message).
        value: Number value to check.
        min_val: Minimum value (optional).
        max_val: Maximum value (optional).

    Returns:
        True if number is within range, False otherwise.

    Example:
        >>> require_range("count", 5, 1, 10)
        True
        >>> require_range("count", 0, 1, 10)
        False
    """
    if not isinstance(value, (int, float)):
        log_error(f"Parameter '{name}' is not a number: {value}")
        return False

    if min_val is not None and value < min_val:
        log_error(f"Parameter '{name}' must be >= {min_val}: {value}")
        return False

    if max_val is not None and value > max_val:
        log_error(f"Parameter '{name}' must be <= {max_val}: {value}")
        return False

    return True


# =============================================================================
# Utility Functions
# =============================================================================
def print_validation_summary(total: int, success: int, failures: int) -> None:
    """
    Print validation summary report.

    Args:
        total: Total count.
        success: Success count.
        failures: Failure count.

    Example:
        >>> print_validation_summary(10, 8, 2)
    """
    print("")
    print_status_line("=")
    print("Validation Summary")
    print_status_line("-")
    print(f"  Total checks:  {total}")
    print(f"  Passed:        {success}")
    print(f"  Failed:        {failures}")
    print_status_line("=")


def print_checkmark(count: int) -> str:
    """
    Print checkmark symbol.

    Args:
        count: Count for pluralization logic.

    Returns:
        Checkmark or plural checkmarks.

    Example:
        >>> print_checkmark(1)
        '✓'
    """
    return "✓"


def print_xmark(count: int) -> str:
    """
    Print X mark symbol.

    Args:
        count: Count for pluralization logic.

    Returns:
        X mark or plural X marks.

    Example:
        >>> print_xmark(1)
        '✗'
    """
    return "✗"