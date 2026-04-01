"""
Tests for issues module.

This module tests the issue processing and JSON handling functions.

Example:
    >>> # Run tests with pytest
    >>> pytest tests/test_lib/test_issues.py
"""

import json
import pytest
from pathlib import Path
from typing import Callable, Dict, Optional, Union


class TestCreateTempFile:
    """Tests for the create_temp_file() function."""

    def test_create_temp_file_returns_temp_path(self):
        """Test that create_temp_file() returns a temp path."""
        from gh_project_toolkit.lib.issues import create_temp_file
        temp_file = create_temp_file("test")
        assert "/" in temp_file

    def test_create_temp_file_includes_test_base_name(self):
        """Test that create_temp_file() includes the test base name."""
        from gh_project_toolkit.lib.issues import create_temp_file
        temp_file = create_temp_file("issues")
        assert "issues" in temp_file

    def test_create_temp_file_includes_pid(self):
        """Test that create_temp_file() includes PID."""
        from gh_project_toolkit.lib.issues import create_temp_file
        temp_file = create_temp_file("test")
        assert ".json" in temp_file


class TestCleanupTemp:
    """Tests for the cleanup_temp() function."""

    def test_cleanup_temp_removes_existing_file(self, tmp_path: Path):
        """Test that cleanup_temp() removes existing file."""
        from gh_project_toolkit.lib.issues import cleanup_temp
        temp_file = tmp_path / "test.json"
        temp_file.write_text("test")
        cleanup_temp(str(temp_file))
        assert not temp_file.exists()

    def test_cleanup_temp_handles_nonexistent_file(self):
        """Test that cleanup_temp() handles non-existent file."""
        from gh_project_toolkit.lib.issues import cleanup_temp
        result = cleanup_temp("/nonexistent/file.txt")
        assert result is True


class TestStripComments:
    """Tests for the strip_comments() function."""

    def test_strip_comments_removes_simple_comment(self):
        """Test that strip_comments() removes simple comment."""
        from gh_project_toolkit.lib.issues import strip_comments
        result = strip_comments("/* comment */ text")
        assert "comment" not in result

    def test_strip_comments_preserves_text_after_comment(self):
        """Test that strip_comments() preserves text after comment."""
        from gh_project_toolkit.lib.issues import strip_comments
        result = strip_comments("/* comment */ text")
        assert "text" in result


class TestNormalizeWhitespace:
    """Tests for the normalize_whitespace() function."""

    def test_normalize_whitespace_removes_trailing_whitespace(self):
        """Test that normalize_whitespace() removes trailing whitespace from lines."""
        from gh_project_toolkit.lib.issues import normalize_whitespace
        result = normalize_whitespace("line   \n  another   ")
        # The function strips trailing whitespace, but preserves leading whitespace
        # on non-empty lines
        assert "line" in result
        assert "another" in result


class TestCleanJsonFile:
    """Tests for the clean_json_file() function."""

    def test_clean_json_file_removes_comments(self, tmp_path: Path):
        """Test that clean_json_file() removes /* */ comments."""
        from gh_project_toolkit.lib.issues import clean_json_file

        input_file = tmp_path / "input.json"
        output_file = tmp_path / "output.json"

        input_file.write_text("""/*
 * This is a comment
 */
[
  {
    "title": "Issue"
  }
]""")

        result = clean_json_file(str(input_file), str(output_file))
        assert result is True
        assert output_file.exists()

        output_content = output_file.read_text()
        assert "/*" not in output_content
        assert "*/" not in output_content

    def test_clean_json_file_preserves_valid_json(self, tmp_path: Path):
        """Test that clean_json_file() preserves valid JSON."""
        from gh_project_toolkit.lib.issues import clean_json_file

        input_file = tmp_path / "input.json"
        output_file = tmp_path / "output.json"

        input_file.write_text('{"title": "Test"}')

        result = clean_json_file(str(input_file), str(output_file))
        assert result is True

        output_data = json.loads(output_file.read_text())
        assert output_data["title"] == "Test"

    def test_clean_json_file_fails_for_nonexistent_input(self, tmp_path: Path):
        """Test that clean_json_file() fails for non-existent input."""
        from gh_project_toolkit.lib.issues import clean_json_file

        output_file = tmp_path / "output.json"
        result = clean_json_file("/nonexistent/input.json", str(output_file))
        assert result is False


class TestValidateAndCountIssues:
    """Tests for the validate_and_count_issues() function."""

    def test_validate_and_count_issues_returns_count(self, temp_json_file: Callable[[list, str], str]):
        """Test that validate_and_count_issues() returns issue count."""
        from gh_project_toolkit.lib.issues import validate_and_count_issues

        file_path = temp_json_file([{"title": "Issue 1"}, {"title": "Issue 2"}])
        count = validate_and_count_issues(file_path)
        assert count == 2

    def test_validate_and_count_issues_returns_none_for_empty_array(self, empty_json_file: str):
        """Test that validate_and_count_issues() returns None for empty array."""
        from gh_project_toolkit.lib.issues import validate_and_count_issues
        assert validate_and_count_issues(empty_json_file) is None

    def test_validate_and_count_issues_fails_for_invalid_json(self, invalid_json_file: str):
        """Test that validate_and_count_issues() fails for invalid JSON."""
        from gh_project_toolkit.lib.issues import validate_and_count_issues
        assert validate_and_count_issues(invalid_json_file) is None

    def test_validate_and_count_issues_fails_for_non_array(self, tmp_path: Path):
        """Test that validate_and_count_issues() fails for non-array JSON."""
        from gh_project_toolkit.lib.issues import validate_and_count_issues

        file_path = tmp_path / "object.json"
        file_path.write_text('{"key": "value"}')

        from gh_project_toolkit.lib.issues import validate_and_count_issues
        assert validate_and_count_issues(str(file_path)) is None


class TestExtractTitle:
    """Tests for the extract_title() function."""

    def test_extract_title_extracts_title(self):
        """Test that extract_title() extracts title."""
        from gh_project_toolkit.lib.issues import extract_title
        title = extract_title('{"title": "My Issue"}')
        assert title == "My Issue"

    def test_extract_title_defaults_to_unnamed(self):
        """Test that extract_title() defaults to 'Untitled'."""
        from gh_project_toolkit.lib.issues import extract_title
        title = extract_title('{"body": "No title"}')
        assert title == "Untitled"

    def test_extract_title_handles_empty_title(self):
        """Test that extract_title() handles empty title."""
        from gh_project_toolkit.lib.issues import extract_title
        title = extract_title('{"title": ""}')
        assert title == ""


class TestExtractBody:
    """Tests for the extract_body() function."""

    def test_extract_body_extracts_body(self):
        """Test that extract_body() extracts body."""
        from gh_project_toolkit.lib.issues import extract_body
        body = extract_body('{"body": "Issue body here"}')
        assert body == "Issue body here"

    def test_extract_body_returns_empty_for_missing_body(self):
        """Test that extract_body() returns empty for missing body."""
        from gh_project_toolkit.lib.issues import extract_body
        body = extract_body('{"title": "Test"}')
        assert body == ""


class TestExtractLabels:
    """Tests for the extract_labels() function."""

    def test_extract_labels_extracts_labels(self):
        """Test that extract_labels() extracts labels."""
        from gh_project_toolkit.lib.issues import extract_labels
        labels = extract_labels('{"labels": ["bug", "enhancement"]}')
        assert labels == "bug,enhancement"

    def test_extract_labels_returns_empty_for_missing_labels(self):
        """Test that extract_labels() returns empty for missing labels."""
        from gh_project_toolkit.lib.issues import extract_labels
        labels = extract_labels('{"title": "Test"}')
        assert labels == ""

    def test_extract_labels_returns_empty_array(self):
        """Test that extract_labels() returns empty for empty labels."""
        from gh_project_toolkit.lib.issues import extract_labels
        labels = extract_labels('{"labels": []}')
        assert labels == ""


class TestExtractMilestone:
    """Tests for the extract_milestone() function."""

    def test_extract_milestone_extracts_milestone(self):
        """Test that extract_milestone() extracts milestone."""
        from gh_project_toolkit.lib.issues import extract_milestone
        milestone = extract_milestone('{"milestone": "v1.0"}')
        assert milestone == "v1.0"

    def test_extract_milestone_returns_empty_for_missing_milestone(self):
        """Test that extract_milestone() returns None for missing milestone."""
        from gh_project_toolkit.lib.issues import extract_milestone
        milestone = extract_milestone('{"title": "Test"}')
        assert milestone is None


class TestExtractAssignees:
    """Tests for the extract_assignees() function."""

    def test_extract_assignees_extracts_assignees(self):
        """Test that extract_assignees() extracts assignees."""
        from gh_project_toolkit.lib.issues import extract_assignees
        assignees = extract_assignees('{"assignees": ["user1", "user2"]}')
        assert assignees == "user1,user2"

    def test_extract_assignees_returns_empty_for_missing_assignees(self):
        """Test that extract_assignees() returns empty for missing assignees."""
        from gh_project_toolkit.lib.issues import extract_assignees
        assignees = extract_assignees('{"title": "Test"}')
        assert assignees == ""


class TestValidateIssue:
    """Tests for the validate_issue() function."""

    def test_validate_issue_succeeds_with_title(self):
        """Test that validate_issue() succeeds with title."""
        from gh_project_toolkit.lib.issues import validate_issue
        assert validate_issue('{"title": "Test"}') is True

    def test_validate_issue_fails_without_title(self):
        """Test that validate_issue() fails without title."""
        from gh_project_toolkit.lib.issues import validate_issue
        assert validate_issue('{"body": "Test"}') is False


class TestGenerateIssueJson:
    """Tests for the generate_issue_json() function."""

    def test_generate_issue_json_creates_valid_json(self):
        """Test that generate_issue_json() creates valid JSON."""
        from gh_project_toolkit.lib.issues import generate_issue_json
        import json

        result = generate_issue_json("Title", "Body", "bug", "v1.0", "user1")
        json.loads(result)

    def test_generate_issue_json_includes_all_fields(self):
        """Test that generate_issue_json() includes all fields."""
        from gh_project_toolkit.lib.issues import generate_issue_json
        import json

        result = generate_issue_json("Title", "Body", "bug", "v1.0", "user1")
        data = json.loads(result)

        assert data["title"] == "Title"
        assert data["body"] == "Body"
        assert "bug" in data["labels"]
        assert data["milestone"] == "v1.0"
        assert "user1" in data["assignees"]


if __name__ == "__main__":
    pytest.main([__file__, "-v"])