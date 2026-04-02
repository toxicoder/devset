"""
GitHub Project Management Toolkit

A Python-based toolkit for automating GitHub project management tasks including
milestone creation, label setup, Project V2 board management, and issue processing.

This module provides a comprehensive interface for managing GitHub repositories
through the GitHub API, supporting dry-run mode, verbose logging, and duplicate
detection/cleanup functionality.

Example:
    >>> from gh_project_toolkit.cli import main
    >>> main()

Attributes:
    __version__: The current version of the toolkit
    __author__: The author of the toolkit

.. _GitHub Project Management Toolkit:
    https://github.com/toxicoder/RestoClaw
"""

__version__ = "1.0.0"
__author__ = "toxicoder"
__description__ = "GitHub project management toolkit for automating milestones, labels, and issues"

__all__ = [
    "__version__",
    "__author__",
    "__description__",
]
