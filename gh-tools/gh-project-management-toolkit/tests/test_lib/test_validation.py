"""
Tests for validation module.

This module tests the validation and dependency checking utilities.

Example:
    >>> # Run tests with pytest
    >>> pytest tests/test_lib/test_validation.py
"""

from pathlib import Path
from typing import Any, Callable, Dict

import pytest


# Type alias for temp_json_file fixture
TempFileCreator = Callable[[Dict[str, Any], str], str]


class TestRequireCmd:
    """Tests for the require_cmd() function."""

    def test_require_cmd_returns_true_for_existing_command(self) -> None:
        """Test that require_cmd() returns True for existing command."""
        from gh_project_toolkit.lib.validation import require_cmd
        assert require_cmd("bash") is True

    def test_require_cmd_returns_false_for_nonexistent_command(self) -> None:
        """Test that require_cmd() returns False for non-existent command."""
        from gh_project_toolkit.lib.validation import require_cmd
        assert require_cmd("nonexistent_command_xyz123") is False


class TestRequireAllCmds:
    """Tests for the require_all_cmds() function."""

    def test_require_all_cmds_returns_true_for_existing_commands(self) -> None:
        """Test that require_all_cmds() returns True for all existing commands."""
        from gh_project_toolkit.lib.validation import require_all_cmds
        assert require_all_cmds("bash", "echo") is True

    def test_require_all_cmds_returns_false_for_missing_command(self) -> None:
        """Test that require_all_cmds() returns False for missing command."""
        from gh_project_toolkit.lib.validation import require_all_cmds
        assert require_all_cmds("bash", "nonexistent_xyz123") is False


class TestRequireFile:
    """Tests for the require_file() function."""

    def test_require_file_returns_true_for_existing_file(self, temp_json_file: TempFileCreator) -> None:
        """Test that require_file() returns True for existing file."""
        from gh_project_toolkit.lib.validation import require_file
        file_path = temp_json_file({"key": "value"})  # type: ignore[call-arg]
        assert require_file(file_path) is True

    def test_require_file_returns_false_for_nonexistent_file(self) -> None:
        """Test that require_file() returns False for non-existent file."""
        from gh_project_toolkit.lib.validation import require_file
        assert require_file("/nonexistent_file_xyz.txt") is False


class TestRequireNonEmptyFile:
    """Tests for the require_non_empty_file() function."""

    def test_require_non_empty_file_returns_true_for_non_empty_file(self, temp_json_file: TempFileCreator) -> None:
        """Test that require_non_empty_file() returns True for non-empty file."""
        from gh_project_toolkit.lib.validation import require_non_empty_file
        file_path = temp_json_file({"key": "value"})  # type: ignore[call-arg]
        assert require_non_empty_file(file_path) is True

    def test_require_non_empty_file_returns_false_for_empty_file(self, tmp_path: Path) -> None:
        """Test that require_non_empty_file() returns False for empty file."""
        from gh_project_toolkit.lib.validation import require_non_empty_file
        file_path = tmp_path / "empty.json"
        file_path.write_text("")
        assert require_non_empty_file(str(file_path)) is False


class TestValidateJson:
    """Tests for the validate_json() function."""

    def test_validate_json_returns_true_for_valid_json(self, valid_json_file: str) -> None:
        """Test that validate_json() returns True for valid JSON."""
        from gh_project_toolkit.lib.validation import validate_json
        assert validate_json(valid_json_file) is True

    def test_validate_json_returns_false_for_invalid_json(self, invalid_json_file: str) -> None:
        """Test that validate_json() returns False for invalid JSON."""
        from gh_project_toolkit.lib.validation import validate_json
        assert validate_json(invalid_json_file) is False

    def test_validate_json_returns_false_for_nonexistent_file(self) -> None:
        """Test that validate_json() returns False for non-existent file."""
        from gh_project_toolkit.lib.validation import validate_json
        assert validate_json("/nonexistent.json") is False


class TestValidateJsonArray:
    """Tests for the validate_json_array() function."""

    def test_validate_json_array_returns_true_for_valid_array(self, tmp_path: Path) -> None:
        """Test that validate_json_array() returns True for valid array."""
        from gh_project_toolkit.lib.validation import validate_json_array
        file_path = tmp_path / "array.json"
        file_path.write_text('[{"item": "value"}]')
        assert validate_json_array(str(file_path)) is True

    def test_validate_json_array_returns_false_for_empty_array(self, empty_json_file: str) -> None:
        """Test that validate_json_array() returns False for empty array."""
        from gh_project_toolkit.lib.validation import validate_json_array
        assert validate_json_array(empty_json_file) is False

    def test_validate_json_array_returns_false_for_object(self, tmp_path: Path) -> None:
        """Test that validate_json_array() returns False for object instead of array."""
        from gh_project_toolkit.lib.validation import validate_json_array
        file_path = tmp_path / "object.json"
        file_path.write_text('{"key": "value"}')
        assert validate_json_array(str(file_path)) is False


class TestValidateGitRepo:
    """Tests for the validate_git_repo() function."""

    def test_validate_git_repo_returns_true_in_git_repo(self) -> None:
        """Test that validate_git_repo() returns True in git repo."""
        from gh_project_toolkit.lib.validation import validate_git_repo
        assert validate_git_repo() is True


class TestValidateRepoFormat:
    """Tests for the validate_repo_format() function."""

    def test_validate_repo_format_returns_true_for_valid_format(self) -> None:
        """Test that validate_repo_format() returns True for valid format."""
        from gh_project_toolkit.lib.validation import validate_repo_format
        assert validate_repo_format("owner/repo") is True

    def test_validate_repo_format_returns_true_for_complex_owner_repo(self) -> None:
        """Test that validate_repo_format() returns True for complex owner/repo."""
        from gh_project_toolkit.lib.validation import validate_repo_format
        assert validate_repo_format("my-org/my-repo") is True

    def test_validate_repo_format_returns_false_for_invalid_format(self) -> None:
        """Test that validate_repo_format() returns False for invalid format."""
        from gh_project_toolkit.lib.validation import validate_repo_format
        assert validate_repo_format("invalid") is False

    def test_validate_repo_format_returns_false_for_missing_repo(self) -> None:
        """Test that validate_repo_format() returns False for missing repo."""
        from gh_project_toolkit.lib.validation import validate_repo_format
        assert validate_repo_format("owner/") is False


class TestRequireNonEmpty:
    """Tests for the require_non_empty() function."""

    def test_require_non_empty_returns_true_for_non_empty_value(self) -> None:
        """Test that require_non_empty() returns True for non-empty value."""
        from gh_project_toolkit.lib.validation import require_non_empty
        assert require_non_empty("varname", "value") is True

    def test_require_non_empty_returns_false_for_empty_value(self) -> None:
        """Test that require_non_empty() returns False for empty value."""
        from gh_project_toolkit.lib.validation import require_non_empty
        assert require_non_empty("varname", "") is False


class TestRequireRange:
    """Tests for the require_range() function."""

    def test_require_range_returns_true_for_valid_range(self) -> None:
        """Test that require_range() returns True for valid range."""
        from gh_project_toolkit.lib.validation import require_range
        assert require_range("count", 5, 1, 10) is True

    def test_require_range_returns_false_for_value_below_minimum(self) -> None:
        """Test that require_range() returns False for value below minimum."""
        from gh_project_toolkit.lib.validation import require_range
        assert require_range("count", 0, 1, 10) is False

    def test_require_range_returns_false_for_value_above_maximum(self) -> None:
        """Test that require_range() returns False for value above maximum."""
        from gh_project_toolkit.lib.validation import require_range
        assert require_range("count", 11, 1, 10) is False

    def test_require_range_returns_false_for_non_numeric_value(self) -> None:
        """Test that require_range() returns False for non-numeric value."""
        from gh_project_toolkit.lib.validation import require_range
        assert require_range("count", "abc", 1, 10) is False


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
