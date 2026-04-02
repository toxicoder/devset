"""
Tests for labels module.

This module tests the label management functions.

Example:
    >>> # Run tests with pytest
    >>> pytest tests/test_lib/test_labels.py
"""

import pytest


class TestGetAllLabelsByCategory:
    """Tests for the get_all_labels_by_category() function."""

    def test_get_all_labels_by_category_returns_correct_structure(self):
        """Test that get_all_labels_by_category() returns correct structure."""
        from gh_project_toolkit.lib.labels import get_all_labels_by_category
        labels = get_all_labels_by_category()

        assert isinstance(labels, dict)
        assert "phase" in labels
        assert "integration" in labels
        assert "skill" in labels
        assert "priority" in labels
        assert "category" in labels
        assert "milestone" in labels

    def test_get_all_labels_by_category_has_phase_labels(self):
        """Test that get_all_labels_by_category() has phase labels."""
        from gh_project_toolkit.lib.labels import get_all_labels_by_category
        labels = get_all_labels_by_category()
        assert "mvp" in labels["phase"]
        assert "phase:foundations" in labels["phase"]


class TestGetAllLabelsArray:
    """Tests for the get_all_labels_array() function."""

    def test_get_all_labels_array_returns_list(self):
        """Test that get_all_labels_array() returns a list."""
        from gh_project_toolkit.lib.labels import get_all_labels_array
        labels = get_all_labels_array()
        assert isinstance(labels, list)

    def test_get_all_labels_array_contains_mvp(self):
        """Test that get_all_labels_array() contains 'mvp'."""
        from gh_project_toolkit.lib.labels import get_all_labels_array
        labels = get_all_labels_array()
        assert "mvp" in labels


class TestGetLabelCount:
    """Tests for the get_label_count() function."""

    def test_get_label_count_phase(self):
        """Test that get_label_count() returns correct count for phase."""
        from gh_project_toolkit.lib.labels import get_label_count
        assert get_label_count("phase") == 7

    def test_get_label_count_integration(self):
        """Test that get_label_count() returns correct count for integration."""
        from gh_project_toolkit.lib.labels import get_label_count
        assert get_label_count("integration") == 3

    def test_get_label_count_skill(self):
        """Test that get_label_count() returns correct count for skill."""
        from gh_project_toolkit.lib.labels import get_label_count
        assert get_label_count("skill") == 11

    def test_get_label_count_all(self):
        """Test that get_label_count returns correct count for all."""
        from gh_project_toolkit.lib.labels import get_label_count
        assert get_label_count("all") == 40


class TestGetLabelColor:
    """Tests for the get_label_color() function."""

    def test_get_label_color_priority_high(self):
        """Test that get_label_color() returns red for priority:high."""
        from gh_project_toolkit.lib.labels import get_label_color
        assert get_label_color("priority:high") == "e11d21"

    def test_get_label_color_priority_medium(self):
        """Test that get_label_color() returns orange for priority:medium."""
        from gh_project_toolkit.lib.labels import get_label_color
        assert get_label_color("priority:medium") == "d93f0b"

    def test_get_label_color_good_first_issue(self):
        """Test that get_label_color() returns green for good-first-issue."""
        from gh_project_toolkit.lib.labels import get_label_color
        assert get_label_color("good-first-issue") == "008672"

    def test_get_label_color_phase(self):
        """Test that get_label_color() returns blue for phase labels."""
        from gh_project_toolkit.lib.labels import get_label_color
        assert get_label_color("phase:foundations") == "58a6ff"

    def test_get_label_color_skill(self):
        """Test that get_label_color() returns purple for skill labels."""
        from gh_project_toolkit.lib.labels import get_label_color
        assert get_label_color("skill:digest") == "8b5cf6"

    def test_get_label_color_unknown(self):
        """Test that get_label_color() returns gray for unknown labels."""
        from gh_project_toolkit.lib.labels import get_label_color
        assert get_label_color("unknown-label") == "ededed"


if __name__ == "__main__":
    pytest.main([__file__, "-v"])