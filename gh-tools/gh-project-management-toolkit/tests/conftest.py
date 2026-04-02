"""
Pytest configuration and fixtures for GitHub Project Management Toolkit tests.

This module provides shared fixtures, mocks, and test utilities used across
the test suite.

Example:
    >>> # Fixtures are automatically available in all test files
    >>> def test_something(mock_github_api):
    ...     # Use the mock_github_api fixture
    ...     pass
"""

import json
import sys
from pathlib import Path
from typing import Any, Callable, Dict, List, Tuple
from unittest.mock import MagicMock

import pytest
from pytest import CaptureFixture, MonkeyPatch

# Add src directory to path
sys.path.insert(0, str(Path(__file__).parent.parent / "src"))


# =============================================================================
# Type Aliases for Fixtures
# =============================================================================

from typing import Protocol


class TempFileCreator(Protocol):
    """Protocol for temp_json_file fixture - creates a temp JSON file and returns path."""

    def __call__(self, content: Dict[str, Any], filename: str = "test.json") -> str: ...




# =============================================================================
# Configuration Fixtures
# =============================================================================


@pytest.fixture
def mock_config_defaults(monkeypatch: MonkeyPatch) -> MagicMock:
    """
    Mock the configuration defaults module.

    Args:
        monkeypatch: Pytest monkeypatch fixture.

    Returns:
        MagicMock: The mocked module.
    """
    mock = MagicMock()
    mock.DRY_RUN = False
    mock.VERBOSE = False
    mock.TMP_DIR = "/tmp"
    mock.COLOR_INFO = "\033[1;34m"
    mock.COLOR_ERROR = "\033[1;31m"
    mock.COLOR_SUCCESS = "\033[1;32m"
    mock.COLOR_WARN = "\033[1;33m"
    mock.COLOR_RESET = "\033[0m"
    mock.EXIT_SUCCESS = 0
    mock.EXIT_ERROR = 1
    return mock


@pytest.fixture
def mock_config_milestones(monkeypatch: MonkeyPatch) -> MagicMock:
    """
    Mock the milestones configuration module.

    Args:
        monkeypatch: Pytest monkeypatch fixture.

    Returns:
        MagicMock: The mocked module.
    """
    mock = MagicMock()
    mock.MILESTONES = {
        "v0.0 Foundations": "Repo, Docker, basic install",
        "v0.1 MVP": "4 daily digests",
    }
    mock.ALL_LABELS = ["mvp", "phase:foundations", "bug"]

    def _get_milestone_titles() -> list[str]:
        return list(mock.MILESTONES.keys())

    def _get_milestone_description(title: str) -> str:
        return mock.MILESTONES.get(title, "")

    def _count_milestones() -> int:
        return len(mock.MILESTONES)

    def _count_labels() -> int:
        return len(mock.ALL_LABELS)

    mock.get_milestone_titles = _get_milestone_titles
    mock.get_milestone_description = _get_milestone_description
    mock.count_milestones = _count_milestones
    mock.count_labels = _count_labels
    return mock


# =============================================================================
# GitHub API Mocks
# =============================================================================


@pytest.fixture
def mock_github_api(monkeypatch: MonkeyPatch) -> MagicMock:
    """
    Mock the GitHub API module.

    Args:
        monkeypatch: Pytest monkeypatch fixture.

    Returns:
        MagicMock: The mocked module.
    """
    mock = MagicMock()

    # Mock owner ID
    mock.get_owner_id.return_value = "U_kgDOBf1x7w"

    # Mock repo ID
    mock.get_repo_id.return_value = "R_kgDOBf1x7w"

    # Mock milestone creation
    mock.create_milestone.return_value = "1"

    # Mock milestone retrieval
    mock.get_all_milestones.return_value = [
        {"title": "v0.0 Foundations", "number": 1, "state": "open"},
        {"title": "v0.1 MVP", "number": 2, "state": "open"},
    ]

    # Mock label creation
    mock.create_label.return_value = True

    # Mock label deletion
    mock.delete_label.return_value = True

    # Mock label retrieval
    mock.get_all_labels.return_value = [
        {"name": "bug", "color": "e11d21"},
        {"name": "enhancement", "color": "84b6eb"},
    ]

    # Mock project creation
    mock.create_project.return_value = "PVT_xxx"

    # Mock project existence check
    mock.project_exists.return_value = "PVT_xxx"

    # Mock project fields
    mock.get_project_fields.return_value = {
        "data": {
            "node": {
                "fields": {
                    "nodes": [
                        {
                            "id": "PVTSSF_xxx",
                            "name": "Status",
                            "options": [
                                {"id": "O_xxx_todo", "name": "To Do"},
                                {"id": "O_xxx_inprogress", "name": "In Progress"},
                                {"id": "O_xxx_done", "name": "Done"},
                            ],
                        }
                    ]
                }
            }
        }
    }

    # Mock issue creation
    mock.create_issue.return_value = "https://github.com/owner/repo/issues/123"

    # Mock issue node ID
    mock.get_issue_node_id.return_value = "I_kwDOBf1x7w"

    # Mock issue addition to project
    mock.add_issue_to_project.return_value = "PVTI_xxx"

    # Mock project field update
    mock.update_project_field.return_value = True

    # Mock todo option
    mock.get_todo_option.return_value = "O_xxx_todo"

    # Mock status field ID
    mock.get_status_field_id.return_value = "PVTSSF_xxx"

    # Mock wait rate limit
    mock.wait_rate_limit = lambda _seconds: None  # type: ignore[call-arg]

    return mock


# =============================================================================
# Issue Data Fixtures
# =============================================================================


@pytest.fixture
def sample_issues_json():
    """
    Sample issues JSON data.

    Returns:
        str: JSON string with sample issues.
    """
    return json.dumps(
        [
            {
                "title": "First Issue",
                "body": "This is the first issue",
                "labels": ["bug", "good-first-issue"],
                "milestone": "v0.0 Foundations",
                "assignees": ["user1"],
            },
            {
                "title": "Second Issue",
                "body": "This is the second issue",
                "labels": ["enhancement"],
                "milestone": "v0.1",
                "assignees": [],
            },
        ]
    )


@pytest.fixture
def sample_issues_with_comments():
    """
    Sample issues JSON with comments.

    Returns:
        str: JSON string with comments that need to be stripped.
    """
    return """/*
 * Sample issues for testing
 */
[
  {
    "title": "First Issue",
    "body": "This is the first issue"
  }
]"""


@pytest.fixture
def sample_milestones() -> List[Dict[str, Any]]:
    """
    Sample milestone data.

    Returns:
        List[Dict]: List of milestone dictionaries.
    """
    return [
        {"title": "v0.0 Foundations", "number": 1, "state": "open"},
        {"title": "v0.1 MVP", "number": 2, "state": "open"},
    ]


@pytest.fixture
def sample_labels() -> List[Dict[str, Any]]:
    """
    Sample label data.

    Returns:
        List[Dict]: List of label dictionaries.
    """
    return [
        {"name": "bug", "color": "e11d21"},
        {"name": "enhancement", "color": "84b6eb"},
    ]


@pytest.fixture
def sample_issues() -> List[Dict[str, Any]]:
    """
    Sample issue data.

    Returns:
        List[Dict]: List of issue dictionaries.
    """
    return [
        {"title": "Bug fix", "number": 1, "state": "open"},
        {"title": "New feature", "number": 2, "state": "open"},
    ]


# =============================================================================
# File Fixtures
# =============================================================================


@pytest.fixture
def temp_json_file(tmp_path: Path) -> TempFileCreator:
    """
    Create a temporary JSON file.

    Args:
        tmp_path: Pytest tmp_path fixture.

    Returns:
        Callable: Function that creates a temp JSON file.
    """

    def _create_file(content: Dict[str, Any], filename: str = "test.json") -> str:
        file_path = tmp_path / filename
        file_path.write_text(json.dumps(content))
        return str(file_path)

    return _create_file


@pytest.fixture
def valid_json_file(tmp_path: Path) -> str:
    """
    Create a valid JSON file.

    Args:
        tmp_path: Pytest tmp_path fixture.

    Returns:
        str: Path to the valid JSON file.
    """
    file_path = tmp_path / "valid.json"
    file_path.write_text('{"key": "value", "array": [1, 2, 3]}')
    return str(file_path)


@pytest.fixture
def invalid_json_file(tmp_path: Path) -> str:
    """
    Create an invalid JSON file.

    Args:
        tmp_path: Pytest tmp_path fixture.

    Returns:
        str: Path to the invalid JSON file.
    """
    file_path = tmp_path / "invalid.json"
    file_path.write_text('{"key": "value"')  # Missing closing brace
    return str(file_path)


@pytest.fixture
def empty_json_file(tmp_path: Path) -> str:
    """
    Create an empty JSON array file.

    Args:
        tmp_path: Pytest tmp_path fixture.

    Returns:
        str: Path to the empty JSON file.
    """
    file_path = tmp_path / "empty.json"
    file_path.write_text("[]")
    return str(file_path)


# =============================================================================
# Logging Fixtures
# =============================================================================


@pytest.fixture
def capture_output(capsys: CaptureFixture[str]) -> Callable[[], Tuple[str, str]]:
    """
    Capture stdout and stderr output.

    Args:
        capsys: Pytest capsys fixture.

    Returns:
        Callable[[], Tuple[str, str]]: Function that captures and returns output as (stdout, stderr).
    """

    def _capture() -> Tuple[str, str]:
        captured = capsys.readouterr()
        return captured.out, captured.err

    return _capture


# =============================================================================
# Path Fixtures
# =============================================================================


@pytest.fixture
def script_dir():
    """
    Get the script directory path.

    Returns:
        Path: Path to the script directory.
    """
    return Path(__file__).parent.parent / "src"


@pytest.fixture
def test_dir():
    """
    Get the test directory path.

    Returns:
        Path: Path to the test directory.
    """
    return Path(__file__).parent


# =============================================================================
# Utility Functions
# =============================================================================


def assert_json_contains(json_str: str, expected: Dict[str, Any]) -> None:
    """
    Assert that a JSON string contains expected values.

    Args:
        json_str: JSON string to check.
        expected: Dictionary of expected key-value pairs.
    """
    data = json.loads(json_str)
    for key, value in expected.items():
        assert key in data, f"Key '{key}' not found in JSON"
        assert data[key] == value, f"Expected {key}={value}, got {data[key]}"


def assert_json_array_length(json_str: str, length: int) -> None:
    """
    Assert that a JSON array has the expected length.

    Args:
        json_str: JSON string to check.
        length: Expected array length.
    """
    data: List[Any] = json.loads(json_str)
    assert isinstance(data, list), "JSON is not an array"
    assert len(data) == length, f"Expected {length} items, got {len(data)}"
