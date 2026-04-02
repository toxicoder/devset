"""
Command-line interface for GitHub Project Management Toolkit.

This module provides the main entry point for the CLI, handling command-line
argument parsing and orchestrating the project setup process.

Example:
    >>> from gh_project_toolkit.cli import main
    >>> main()
    # Or run directly:
    # python -m gh_project_toolkit --help
"""

import argparse
import sys
from pathlib import Path
from typing import Optional, List

# Add src directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

# Import configuration with fallbacks
try:
    from gh_project_toolkit.config.defaults import (
        DRY_RUN as _dry_run,
        VERBOSE as _verbose,
    )
except ImportError:
    _dry_run = False
    _verbose = False

# Module-level flags (can be overridden by CLI args) - use lowercase names to avoid mypy constant errors
dry_run = _dry_run
verbose = _verbose

from gh_project_toolkit.config.milestones import MILESTONES, ALL_LABELS, get_label_color as get_label_color_from_config
from gh_project_toolkit.lib.logging import (
    log,
    log_success,
    log_error,
    log_dry_run,
)
from gh_project_toolkit.lib.validation import (
    # require_file - imported but not used, kept for potential future use
)
from gh_project_toolkit.lib.github_api import (
    milestone_exists,
    label_exists,
    create_milestone,
    create_label,
)
from gh_project_toolkit.lib.projects import create_or_find_project
from gh_project_toolkit.lib.issues import process_issues
from gh_project_toolkit.lib.duplicates import cleanup_all  # type: ignore[unused-import]
from gh_project_toolkit import __version__


def setup_project(owner: str, repo: str, project_name: str, dry_run: bool = False) -> int:
    """
    Setup GitHub project with milestones and labels.

    Args:
        owner: Repository owner.
        repo: Repository name.
        project_name: Project name.
        dry_run: If True, don't make actual changes.

    Returns:
        0 on success, 1 on failure.
    """
    log(f"Setting up project for {owner}/{repo}")
    log(f"Project name: {project_name}")

    if dry_run:
        log_dry_run("This is a dry run - no changes will be made")

    # Setup milestones
    log("Setting up milestones...")
    for milestone in MILESTONES:
        # MILESTONES is Dict[str, str] - key is title, value is description
        title = milestone
        description = MILESTONES[milestone]
        due_on = None  # No due_on in milestones config

        if dry_run:
            log_dry_run(f"Would create milestone: {title}")
            continue

        if milestone_exists(owner, repo, title):
            log(f"Milestone already exists: {title}")
            continue

        result = create_milestone(owner, repo, title, description, due_on)
        if result:
            log_success(f"Created milestone: {title}")
        else:
            log_error(f"Failed to create milestone: {title}")

    # Setup labels
    log("Setting up labels...")
    for label in ALL_LABELS:
        if dry_run:
            log_dry_run(f"Would create label: {label}")
            continue

        if label_exists(owner, repo, label):
            log(f"Label already exists: {label}")
            continue

        color = get_label_color_from_config(label)
        if create_label(owner, repo, label, color):
            log_success(f"Created label: {label}")
        else:
            log_error(f"Failed to create label: {label}")

    # Setup project
    log("Setting up project...")
    project_id = create_or_find_project(owner, repo, project_name)
    if project_id:
        log_success(f"Project ready: {project_id}")
    else:
        log_error("Failed to create project")
        return 1

    if dry_run:
        log_dry_run("Setup complete (dry run)")
    else:
        log_success("Setup complete")

    return 0


def process_project_issues(owner: str, repo: str, json_file: str, project_id: Optional[str] = None) -> int:
    """
    Process issues from JSON file and create them on GitHub.

    Args:
        owner: Repository owner.
        repo: Repository name.
        json_file: Path to JSON file with issues.
        project_id: Project ID to add issues to (optional).

    Returns:
        Number of issues created.
    """
    log(f"Processing issues from {json_file}")

    if project_id:
        log(f"Adding issues to project: {project_id}")

    count = process_issues(owner, repo, json_file, project_id)
    log_success(f"Processed {count} issues")
    return count


def cleanup_duplicates(owner: str, repo: str, titles: Optional[List[str]] = None) -> int:
    """
    Cleanup duplicate milestones and labels.

    Args:
        owner: Repository owner.
        repo: Repository name.
        titles: List of milestone titles to check (optional).

    Returns:
        Number of duplicates removed.
    """
    log("Starting cleanup...")

    # cleanup_all signature: cleanup_all(owner, repo, apply=False, resources="milestones,labels,issues")
    # We need to pass titles through the cleanup_milestones function directly
    from gh_project_toolkit.lib.duplicates import cleanup_milestones, cleanup_labels, cleanup_issues
    
    total_removed = 0
    if titles:
        # If titles specified, cleanup only milestones
        removed = cleanup_milestones(owner, repo, titles)
        total_removed += removed
    else:
        # Cleanup all
        removed = cleanup_milestones(owner, repo)
        total_removed += removed
    
    log_success(f"Cleanup complete: {total_removed} duplicates removed")
    return total_removed


def main() -> int:
    """
    Main entry point for the CLI.

    Returns:
        Exit code (0 for success, 1 for failure).
    """
    parser = argparse.ArgumentParser(
        description="GitHub Project Management Toolkit - Automate project setup and issue management"
    )
    parser.add_argument(
        "--version",
        action="version",
        version=f"%(prog)s {__version__}",
    )
    parser.add_argument(
        "-v", "--verbose",
        action="store_true",
        default=False,
        help="Enable verbose output",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        default=False,
        help="Enable dry-run mode (no changes made)",
    )
    parser.add_argument(
        "-y", "--yes",
        action="store_true",
        default=False,
        help="Skip confirmation prompts",
    )

    subparsers = parser.add_subparsers(dest="command", help="Available commands")

    # Setup command
    setup_parser = subparsers.add_parser("setup", help="Setup a new GitHub project")
    setup_parser.add_argument("owner", help="Repository owner")
    setup_parser.add_argument("repo", help="Repository name")
    setup_parser.add_argument(
        "-p", "--project",
        default="Development Roadmap",
        help="Project name (default: Development Roadmap)",
    )

    # Issues command
    issues_parser = subparsers.add_parser("issues", help="Process issues from JSON file")
    issues_parser.add_argument("owner", help="Repository owner")
    issues_parser.add_argument("repo", help="Repository name")
    issues_parser.add_argument("json_file", help="Path to JSON file with issues")
    issues_parser.add_argument(
        "-p", "--project",
        help="Project ID to add issues to",
    )

    # Cleanup command
    cleanup_parser = subparsers.add_parser("cleanup", help="Cleanup duplicate milestones/labels")
    cleanup_parser.add_argument("owner", help="Repository owner")
    cleanup_parser.add_argument("repo", help="Repository name")
    cleanup_parser.add_argument(
        "-t", "--title",
        action="append",
        help="Milestone title to check (can be specified multiple times)",
    )

    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        return 1

    # Set global flags from CLI args
    global dry_run, verbose
    dry_run = args.dry_run
    verbose = args.verbose

    try:
        if args.command == "setup":
            if not args.yes:
                confirm = input(f"Setup project for {args.owner}/{args.repo}? [y/N] ")
                if confirm.lower() != "y":
                    log("Setup cancelled")
                    return 0

            return setup_project(args.owner, args.repo, args.project, dry_run)

        elif args.command == "issues":
            if not args.yes:
                confirm = input(f"Process issues from {args.json_file}? [y/N] ")
                if confirm.lower() != "y":
                    log("Processing cancelled")
                    return 0

            return process_project_issues(args.owner, args.repo, args.json_file, args.project)

        elif args.command == "cleanup":
            return cleanup_duplicates(args.owner, args.repo, args.title)

        else:
            log_error(f"Unknown command: {args.command}")
            return 1

    except KeyboardInterrupt:
        log("\nOperation cancelled by user")
        return 130
    except Exception as e:
        log_error(f"Unexpected error: {e}")
        if verbose:
            import traceback
            traceback.print_exc()
        return 1


if __name__ == "__main__":
    sys.exit(main())