"""
Tests for configuration defaults module.

This module tests the default configuration values used throughout the toolkit.

Example:
    >>> # Run tests with pytest
    >>> pytest tests/test_config/test_defaults.py
"""

import sys
import os
from pathlib import Path

import pytest

# Add src directory to path
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "src"))


class TestScriptMetadata:
    """Tests for script metadata configuration."""

    def test_script_name(self):
        """Test that SCRIPT_NAME is defined."""
        from gh_project_toolkit.config.defaults import SCRIPT_NAME
        assert SCRIPT_NAME == "setup-restoclaw.py"

    def test_script_version(self):
        """Test that SCRIPT_VERSION is defined."""
        from gh_project_toolkit.config.defaults import SCRIPT_VERSION
        assert SCRIPT_VERSION == "1.0.0"

    def test_script_description(self):
        """Test that SCRIPT_DESCRIPTION is defined."""
        from gh_project_toolkit.config.defaults import SCRIPT_DESCRIPTION
        assert "Creates GitHub milestones" in SCRIPT_DESCRIPTION


class TestRepositoryConfiguration:
    """Tests for repository configuration values."""

    def test_default_repo(self):
        """Test that DEFAULT_REPO is defined with correct format."""
        from gh_project_toolkit.config.defaults import DEFAULT_REPO
        assert "/" in DEFAULT_REPO
        assert "toxicoder" in DEFAULT_REPO
        assert "RestoClaw" in DEFAULT_REPO

    def test_default_json_file(self):
        """Test that DEFAULT_JSON_FILE is defined."""
        from gh_project_toolkit.config.defaults import DEFAULT_JSON_FILE
        assert DEFAULT_JSON_FILE == "issues.json"

    def test_default_project_name(self):
        """Test that DEFAULT_PROJECT_NAME is defined."""
        from gh_project_toolkit.config.defaults import DEFAULT_PROJECT_NAME
        assert "Development Roadmap" in DEFAULT_PROJECT_NAME


class TestPathsAndFiles:
    """Tests for path configuration."""

    def test_issues_json_path(self):
        """Test that ISSUES_JSON_PATH is defined."""
        from gh_project_toolkit.config.defaults import ISSUES_JSON_PATH
        assert ISSUES_JSON_PATH == "issues.json"

    def test_tmp_dir(self):
        """Test that TMP_DIR is defined."""
        from gh_project_toolkit.config.defaults import TMP_DIR
        assert TMP_DIR is not None
        assert len(TMP_DIR) > 0

    def test_get_script_dir(self):
        """Test that get_script_dir returns a valid path."""
        from gh_project_toolkit.config.defaults import get_script_dir
        script_dir = get_script_dir()
        assert isinstance(script_dir, Path)
        assert script_dir.exists()


class TestGitHubAPIConfiguration:
    """Tests for GitHub API configuration."""

    def test_graphql_endpoint(self):
        """Test that GITHUB_GRAPHQL_ENDPOINT is defined."""
        from gh_project_toolkit.config.defaults import GITHUB_GRAPHQL_ENDPOINT
        assert GITHUB_GRAPHQL_ENDPOINT == "https://api.github.com/graphql"

    def test_rest_api_base(self):
        """Test that GITHUB_REST_API_BASE is defined."""
        from gh_project_toolkit.config.defaults import GITHUB_REST_API_BASE
        assert GITHUB_REST_API_BASE == "https://api.github.com"


class TestColorConfiguration:
    """Tests for color configuration."""

    def test_color_info(self):
        """Test that COLOR_INFO is defined with ANSI code."""
        from gh_project_toolkit.config.defaults import COLOR_INFO
        assert COLOR_INFO.startswith("\033")
        assert "34" in COLOR_INFO  # Blue color code

    def test_color_error(self):
        """Test that COLOR_ERROR is defined with ANSI code."""
        from gh_project_toolkit.config.defaults import COLOR_ERROR
        assert COLOR_ERROR.startswith("\033")
        assert "31" in COLOR_ERROR  # Red color code

    def test_color_success(self):
        """Test that COLOR_SUCCESS is defined with ANSI code."""
        from gh_project_toolkit.config.defaults import COLOR_SUCCESS
        assert COLOR_SUCCESS.startswith("\033")
        assert "32" in COLOR_SUCCESS  # Green color code

    def test_color_warn(self):
        """Test that COLOR_WARN is defined with ANSI code."""
        from gh_project_toolkit.config.defaults import COLOR_WARN
        assert COLOR_WARN.startswith("\033")
        assert "33" in COLOR_WARN  # Yellow color code

    def test_color_reset(self):
        """Test that COLOR_RESET is defined."""
        from gh_project_toolkit.config.defaults import COLOR_RESET
        assert COLOR_RESET == "\033[0m"


class TestExitCodes:
    """Tests for exit code constants."""

    def test_exit_success(self):
        """Test that EXIT_SUCCESS is 0."""
        from gh_project_toolkit.config.defaults import EXIT_SUCCESS
        assert EXIT_SUCCESS == 0

    def test_exit_error(self):
        """Test that EXIT_ERROR is 1."""
        from gh_project_toolkit.config.defaults import EXIT_ERROR
        assert EXIT_ERROR == 1

    def test_exit_missing_cmd(self):
        """Test that EXIT_MISSING_CMD is 2."""
        from gh_project_toolkit.config.defaults import EXIT_MISSING_CMD
        assert EXIT_MISSING_CMD == 2

    def test_exit_invalid_config(self):
        """Test that EXIT_INVALID_CONFIG is 3."""
        from gh_project_toolkit.config.defaults import EXIT_INVALID_CONFIG
        assert EXIT_INVALID_CONFIG == 3

    def test_exit_api_error(self):
        """Test that EXIT_API_ERROR is 4."""
        from gh_project_toolkit.config.defaults import EXIT_API_ERROR
        assert EXIT_API_ERROR == 4


class TestBehaviorFlags:
    """Tests for behavior flag configuration."""

    def test_dry_run_default_false(self):
        """Test that DRY_RUN defaults to False."""
        from gh_project_toolkit.config.defaults import DRY_RUN
        assert DRY_RUN is False

    def test_verbose_default_false(self):
        """Test that VERBOSE defaults to False."""
        from gh_project_toolkit.config.defaults import VERBOSE
        assert VERBOSE is False


if __name__ == "__main__":
    pytest.main([__file__, "-v"])