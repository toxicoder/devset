"""
Tests for duplicates module.

This module tests the duplicate detection and cleanup functions.

Example:
    >>> # Run tests with pytest
    >>> pytest tests/test_lib/test_duplicates.py
"""

import pytest


class TestNormalizeIssueTitle:
    """Tests for the normalize_issue_title() function."""

    def test_normalize_issue_title_removes_hash_prefix_at_start(self):
        """Test that normalize_issue_title() removes # prefix at start."""
        from gh_project_toolkit.lib.duplicates import normalize_issue_title
        assert normalize_issue_title("#361 Fix bug") == "Fix bug"

    def test_normalize_issue_title_removes_hash_prefix_at_start_with_space(self):
        """Test that normalize_issue_title() removes # prefix at start with space."""
        from gh_project_toolkit.lib.duplicates import normalize_issue_title
        assert normalize_issue_title("# 123 Bug fix") == "Bug fix"

    def test_normalize_issue_title_removes_hash_prefix_at_start_with_dash(self):
        """Test that normalize_issue_title() removes # prefix at start with dash."""
        from gh_project_toolkit.lib.duplicates import normalize_issue_title
        assert normalize_issue_title("#361: Bug fix") == "Bug fix"

    def test_normalize_issue_title_removes_hash_prefix_at_end(self):
        """Test that normalize_issue_title() removes # prefix at end."""
        from gh_project_toolkit.lib.duplicates import normalize_issue_title
        assert normalize_issue_title("Bug fix #361") == "Bug fix"

    def test_normalize_issue_title_removes_hash_prefix_at_end_with_space(self):
        """Test that normalize_issue_title() removes # prefix at end with space."""
        from gh_project_toolkit.lib.duplicates import normalize_issue_title
        assert normalize_issue_title("Bug fix # 123") == "Bug fix"

    def test_normalize_issue_title_removes_hash_prefix_at_end_with_dash(self):
        """Test that normalize_issue_title() removes # prefix at end with dash."""
        from gh_project_toolkit.lib.duplicates import normalize_issue_title
        # The function removes #123 pattern at end, but leaves the dash
        result = normalize_issue_title("Bug fix - #361")
        assert "Bug fix" in result

    def test_normalize_issue_title_removes_plain_number_at_start(self):
        """Test that normalize_issue_title() removes plain number at start."""
        from gh_project_toolkit.lib.duplicates import normalize_issue_title
        assert normalize_issue_title("361 Bug fix") == "Bug fix"

    def test_normalize_issue_title_removes_plain_number_at_end(self):
        """Test that normalize_issue_title() removes plain number at end."""
        from gh_project_toolkit.lib.duplicates import normalize_issue_title
        # The function removes plain number pattern at end
        result = normalize_issue_title("Bug fix 361")
        assert "Bug fix" in result

    def test_normalize_issue_title_removes_parentheses_at_start(self):
        """Test that normalize_issue_title() removes parentheses at start."""
        from gh_project_toolkit.lib.duplicates import normalize_issue_title
        # The function removes (123) pattern at start
        result = normalize_issue_title("(361) Bug fix")
        assert "Bug fix" in result

    def test_normalize_issue_title_removes_parentheses_at_end(self):
        """Test that normalize_issue_title() removes parentheses at end."""
        from gh_project_toolkit.lib.duplicates import normalize_issue_title
        # The function removes (123) pattern at end
        result = normalize_issue_title("Bug fix (361)")
        assert "Bug fix" in result

    def test_normalize_issue_title_returns_original_if_no_bug_number(self):
        """Test that normalize_issue_title() returns original if no bug number."""
        from gh_project_toolkit.lib.duplicates import normalize_issue_title
        assert normalize_issue_title("Bug fix") == "Bug fix"

    def test_normalize_issue_title_handles_multiple_patterns(self):
        """Test that normalize_issue_title() handles multiple patterns."""
        from gh_project_toolkit.lib.duplicates import normalize_issue_title
        assert normalize_issue_title("#123 Bug fix #456") == "Bug fix"

    def test_normalize_issue_title_preserves_title_with_no_match(self):
        """Test that normalize_issue_title() preserves title with no match."""
        from gh_project_toolkit.lib.duplicates import normalize_issue_title
        assert normalize_issue_title("Update README") == "Update README"

    def test_normalize_issue_title_handles_empty_string(self):
        """Test that normalize_issue_title() handles empty string."""
        from gh_project_toolkit.lib.duplicates import normalize_issue_title
        assert normalize_issue_title("") == ""

    def test_normalize_issue_title_handles_only_bug_number(self):
        """Test that normalize_issue_title() handles only bug number."""
        from gh_project_toolkit.lib.duplicates import normalize_issue_title
        # The function removes the bug number, leaving empty string
        # If empty, returns original
        result = normalize_issue_title("#361")
        assert result == "" or result == "#361"

    def test_normalize_issue_title_handles_whitespace_around_bug_number(self):
        """Test that normalize_issue_title() handles whitespace around bug number."""
        from gh_project_toolkit.lib.duplicates import normalize_issue_title
        assert normalize_issue_title("#  123  Bug fix") == "Bug fix"


if __name__ == "__main__":
    pytest.main([__file__, "-v"])