"""
Tests for milestones configuration module.

This module tests the milestone definitions and label groupings used by the toolkit.

Example:
    >>> # Run tests with pytest
    >>> pytest tests/test_config/test_milestones.py
"""

import pytest


class TestMilestones:
    """Tests for milestone definitions."""

    def test_milestones_dict_exists(self):
        """Test that MILESTONES dictionary is defined."""
        from gh_project_toolkit.config.milestones import MILESTONES
        assert isinstance(MILESTONES, dict)
        assert len(MILESTONES) > 0

    def test_v0_0_foundations_exists(self):
        """Test that v0.0 Foundations milestone exists."""
        from gh_project_toolkit.config.milestones import MILESTONES
        assert "v0.0 Foundations" in MILESTONES
        assert "Repo" in MILESTONES["v0.0 Foundations"]

    def test_v1_0_full_restaurant_os_exists(self):
        """Test that v1.0 Full Restaurant OS milestone exists."""
        from gh_project_toolkit.config.milestones import MILESTONES
        assert "v1.0 Full Restaurant OS" in MILESTONES
        # The actual description contains "Restaurant OS" in the title
        # and has description about staff scheduling etc.
        desc = MILESTONES["v1.0 Full Restaurant OS"]
        assert "Staff" in desc or "scheduling" in desc
        assert "marketing" in desc or "automation" in desc

    def test_all_milestones_have_descriptions(self):
        """Test that all milestones have non-empty descriptions."""
        from gh_project_toolkit.config.milestones import MILESTONES
        for title, description in MILESTONES.items():
            assert len(description) > 0, f"Milestone '{title}' has empty description"


class TestMilestoneFunctions:
    """Tests for milestone utility functions."""

    def test_get_milestone_titles(self):
        """Test get_milestone_titles returns a list."""
        from gh_project_toolkit.config.milestones import get_milestone_titles
        titles = get_milestone_titles()
        assert isinstance(titles, list)
        assert "v0.0 Foundations" in titles

    def test_get_milestone_description(self):
        """Test get_milestone_description returns correct description."""
        from gh_project_toolkit.config.milestones import get_milestone_description
        desc = get_milestone_description("v0.0 Foundations")
        assert "Repo" in desc

    def test_get_milestone_description_not_found(self):
        """Test get_milestone_description returns empty string for unknown milestone."""
        from gh_project_toolkit.config.milestones import get_milestone_description
        desc = get_milestone_description("NonExistent")
        assert desc == ""

    def test_count_milestones(self):
        """Test count_milestones returns correct count."""
        from gh_project_toolkit.config.milestones import count_milestones
        count = count_milestones()
        assert count == 7

    def test_get_milestones_json(self):
        """Test get_milestones_json returns valid JSON."""
        from gh_project_toolkit.config.milestones import get_milestones_json
        import json
        json_str = get_milestones_json()
        data = json.loads(json_str)
        assert isinstance(data, list)
        assert len(data) == 7
        assert all("title" in item for item in data)
        assert all("description" in item for item in data)


class TestAllLabels:
    """Tests for ALL_LABELS array."""

    def test_all_labels_list_exists(self):
        """Test that ALL_LABELS list is defined."""
        from gh_project_toolkit.config.milestones import ALL_LABELS
        assert isinstance(ALL_LABELS, list)
        assert len(ALL_LABELS) > 0

    def test_all_labels_has_mvp(self):
        """Test that ALL_LABELS contains 'mvp'."""
        from gh_project_toolkit.config.milestones import ALL_LABELS
        assert "mvp" in ALL_LABELS

    def test_all_labels_has_phase_labels(self):
        """Test that ALL_LABELS contains phase labels."""
        from gh_project_toolkit.config.milestones import ALL_LABELS
        phase_labels = ["phase:foundations", "phase:core-skill", "phase:integrations"]
        for label in phase_labels:
            assert label in ALL_LABELS

    def test_all_labels_has_skill_labels(self):
        """Test that ALL_LABELS contains skill labels."""
        from gh_project_toolkit.config.milestones import ALL_LABELS
        skill_labels = ["skill:digest", "skill:inventory", "skill:pos"]
        for label in skill_labels:
            assert label in ALL_LABELS

    def test_all_labels_has_priority_labels(self):
        """Test that ALL_LABELS contains priority labels."""
        from gh_project_toolkit.config.milestones import ALL_LABELS
        priority_labels = ["priority:high", "priority:medium", "good-first-issue"]
        for label in priority_labels:
            assert label in ALL_LABELS

    def test_all_labels_count(self):
        """Test that ALL_LABELS has correct count."""
        from gh_project_toolkit.config.milestones import ALL_LABELS, count_labels
        assert len(ALL_LABELS) == 40
        assert len(ALL_LABELS) == count_labels()


class TestLabelColors:
    """Tests for label color configuration."""

    def test_get_label_color_priority_high(self):
        """Test get_label_color returns red for priority:high."""
        from gh_project_toolkit.config.milestones import get_label_color
        color = get_label_color("priority:high")
        assert color == "e11d21"

    def test_get_label_color_priority_medium(self):
        """Test get_label_color returns orange for priority:medium."""
        from gh_project_toolkit.config.milestones import get_label_color
        color = get_label_color("priority:medium")
        assert color == "d93f0b"

    def test_get_label_color_good_first_issue(self):
        """Test get_label_color returns green for good-first-issue."""
        from gh_project_toolkit.config.milestones import get_label_color
        color = get_label_color("good-first-issue")
        assert color == "008672"

    def test_get_label_color_phase(self):
        """Test get_label_color returns blue for phase labels."""
        from gh_project_toolkit.config.milestones import get_label_color
        color = get_label_color("phase:foundations")
        assert color == "58a6ff"

    def test_get_label_color_skill(self):
        """Test get_label_color returns purple for skill labels."""
        from gh_project_toolkit.config.milestones import get_label_color
        color = get_label_color("skill:digest")
        assert color == "8b5cf6"

    def test_get_label_color_unknown(self):
        """Test get_label_color returns gray for unknown labels."""
        from gh_project_toolkit.config.milestones import get_label_color
        color = get_label_color("unknown-label")
        assert color == "ededed"


class TestLabelFunctions:
    """Tests for label utility functions."""

    def test_get_all_labels_by_category(self):
        """Test get_all_labels_by_category returns correct structure."""
        from gh_project_toolkit.config.milestones import get_all_labels_by_category
        labels = get_all_labels_by_category()
        assert isinstance(labels, dict)
        assert "phase" in labels
        assert "integration" in labels
        assert "skill" in labels
        assert "priority" in labels
        assert "category" in labels
        assert "milestone" in labels

    def test_get_label_count_phase(self):
        """Test get_label_count returns correct count for phase."""
        from gh_project_toolkit.config.milestones import get_label_count
        count = get_label_count("phase")
        assert count == 7

    def test_get_label_count_integration(self):
        """Test get_label_count returns correct count for integration."""
        from gh_project_toolkit.config.milestones import get_label_count
        count = get_label_count("integration")
        assert count == 3

    def test_get_label_count_skill(self):
        """Test get_label_count returns correct count for skill."""
        from gh_project_toolkit.config.milestones import get_label_count
        count = get_label_count("skill")
        assert count == 11

    def test_get_label_count_all(self):
        """Test that get_label_count returns correct count for all."""
        from gh_project_toolkit.config.milestones import get_label_count
        count = get_label_count("all")
        assert count == 40


if __name__ == "__main__":
    pytest.main([__file__, "-v"])