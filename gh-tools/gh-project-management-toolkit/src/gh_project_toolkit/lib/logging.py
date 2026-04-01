"""
Logging and output utilities for GitHub Project Management Toolkit.

This module provides colored logging functions for different message types
(info, error, success, warning). All functions support the DRY_RUN and VERBOSE
flags for conditional output.

Example:
    >>> from gh_project_toolkit.lib.logging import log, log_success, log_error
    >>> log("Starting setup process")
    >>> log_success("Setup completed successfully")
    >>> log_error("Configuration file not found")
"""

import os
import sys
from datetime import datetime
from typing import Optional, Any

# =============================================================================
# Configuration
# =============================================================================
# Define fallback values at module level before try block (avoids mypy "already defined" errors)
COLOR_INFO = "\033[1;34m"
COLOR_ERROR = "\033[1;31m"
COLOR_SUCCESS = "\033[1;32m"
COLOR_WARN = "\033[1;33m"
COLOR_RESET = "\033[0m"
DRY_RUN = False
VERBOSE = False

# Try to import from the actual package
try:
    from gh_project_toolkit.config.defaults import (
        DRY_RUN as _dry_run,
        VERBOSE as _verbose,
    )
    # Use imported values - assign to lowercase variables to avoid mypy constant redefinition errors
    _dry_run_imported = _dry_run
    _verbose_imported = _verbose
except ImportError:
    # Use fallback values defined above
    _dry_run_imported = False
    _verbose_imported = False
    pass


# =============================================================================
# Logging Functions
# =============================================================================
def log(message: str, *args: Any, **kwargs: Any) -> None:
    """
    Log an informational message with colored output.

    Args:
        message: The message to log. Can contain format specifiers.
        *args: Additional arguments for printf formatting.
        **kwargs: Additional keyword arguments for printf formatting.

    Example:
        >>> log("Starting setup process")
        >>> log("Processing %d items", 42)
        >>> log("Value: {value}", value=123)

    Note:
        The function supports both printf-style formatting (%s, %d, etc.) and
        format() style formatting.
    """
    formatted_message = message
    if args:
        formatted_message = message % args
    elif kwargs:
        formatted_message = message.format(**kwargs)

    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print(f"{COLOR_INFO}[{timestamp}] [+]{COLOR_RESET} {formatted_message}")


def log_success(message: str, *args: Any, **kwargs: Any) -> None:
    """
    Log a success message with colored output.

    Args:
        message: The message to log. Can contain format specifiers.
        *args: Additional arguments for printf formatting.
        **kwargs: Additional keyword arguments for printf formatting.

    Example:
        >>> log_success("Setup completed successfully")
        >>> log_success("Created %d milestones", 5)
    """
    formatted_message = message
    if args:
        formatted_message = message % args
    elif kwargs:
        formatted_message = message.format(**kwargs)

    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print(f"{COLOR_SUCCESS}[{timestamp}] [✓]{COLOR_RESET} {formatted_message}")


def log_error(message: str, *args: Any, **kwargs: Any) -> None:
    """
    Log an error message to stderr with colored output.

    Args:
        message: The message to log. Can contain format specifiers.
        *args: Additional arguments for printf formatting.
        **kwargs: Additional keyword arguments for printf formatting.

    Example:
        >>> log_error("Configuration file not found")
        >>> log_error("Missing required command: %s", "gh")
    """
    formatted_message = message
    if args:
        formatted_message = message % args
    elif kwargs:
        formatted_message = message.format(**kwargs)

    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print(f"{COLOR_ERROR}[{timestamp}] [✗]{COLOR_RESET} {formatted_message}", file=sys.stderr)


def log_warning(message: str, *args: Any, **kwargs: Any) -> None:
    """
    Log a warning message with colored output.

    Args:
        message: The message to log. Can contain format specifiers.
        *args: Additional arguments for printf formatting.
        **kwargs: Additional keyword arguments for printf formatting.

    Example:
        >>> log_warning("Deprecated option used")
        >>> log_warning("Low disk space: %d%% remaining", 10)
    """
    formatted_message = message
    if args:
        formatted_message = message % args
    elif kwargs:
        formatted_message = message.format(**kwargs)

    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print(f"{COLOR_WARN}[{timestamp}] [!]{COLOR_RESET} {formatted_message}")


def log_verbose(message: str, *args: Any, **kwargs: Any) -> None:
    """
    Log a verbose message (only when VERBOSE=true).

    Args:
        message: The message to log. Can contain format specifiers.
        *args: Additional arguments for printf formatting.
        **kwargs: Additional keyword arguments for printf formatting.

    Example:
        >>> log_verbose("Debug info: variable value is %s", var)
        >>> log_verbose("Processing item %d of %d", current, total)
    """
    if VERBOSE:
        formatted_message = message
        if args:
            formatted_message = message % args
        elif kwargs:
            formatted_message = message.format(**kwargs)

        print(f"[VERBOSE] {formatted_message}")


# =============================================================================
# Dry-run Message Functions
# =============================================================================
def log_dry_run(message: str, *args: Any, **kwargs: Any) -> None:
    """
    Log a dry-run message indicating what would be done.

    Args:
        message: Description of the action that would be performed.
        *args: Additional arguments for printf formatting.
        **kwargs: Additional keyword arguments for printf formatting.

    Example:
        >>> log_dry_run("Creating milestone: %s", title)
        >>> log_dry_run("Would create %d labels", 10)
    """
    if DRY_RUN:
        formatted_message = message
        if args:
            formatted_message = message % args
        elif kwargs:
            formatted_message = message.format(**kwargs)

        print(f"{COLOR_WARN}[DRY-RUN]{COLOR_RESET} {formatted_message}")


# =============================================================================
# Status Line Functions
# =============================================================================
def print_status_line(char: str = "=", width: Optional[int] = None) -> None:
    """
    Print a status line separator.

    Args:
        char: Optional separator character (default: '=').
        width: Optional width of the line. If None, uses COLUMNS or 80.

    Example:
        >>> print_status_line()
        >>> print_status_line("-")
    """
    if width is None:
        width = int(os.environ.get("COLUMNS", 80))

    print(char * width)


def print_section_header(title: str, char: str = "=") -> None:
    """
    Print a formatted section header.

    Args:
        title: Header title.
        char: Optional separator character (default: '=').

    Example:
        >>> print_section_header("Processing Milestones")
        >>> print_section_header("Setup Complete", "-")
    """
    width = int(os.environ.get("COLUMNS", 80))
    pad_width = (width - len(title) - 2) // 2

    print(char * pad_width + " " + title + " " + char * pad_width)
    print(char * width)


def print_summary(summary: str) -> None:
    """
    Print a final summary section.

    Args:
        summary: Summary text to display.

    Example:
        >>> print_summary("All operations completed successfully")
    """
    print_status_line("=")
    print(f"{COLOR_SUCCESS}{summary}{COLOR_RESET}")
    print_status_line("=")


def print_summary_line(char: str = "=", width: Optional[int] = None) -> None:
    """
    Print a summary line separator.

    Args:
        char: Optional separator character (default: '=').
        width: Optional width of the line. If None, uses COLUMNS or 80.

    Example:
        >>> print_summary_line()
        >>> print_summary_line("-")
    """
    if width is None:
        width = int(os.environ.get("COLUMNS", 80))

    print(char * width)
