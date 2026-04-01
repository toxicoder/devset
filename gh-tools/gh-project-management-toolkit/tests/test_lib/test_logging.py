"""
Tests for logging module.

This module tests the logging and output utilities used throughout the toolkit.

Example:
    >>> # Run tests with pytest
    >>> pytest tests/test_lib/test_logging.py
"""

from __future__ import annotations

import pytest
from pytest import CaptureFixture


class TestLogFunction:
    """Tests for the log() function."""

    def test_log_outputs_message(self, capsys: CaptureFixture[str]) -> None:
        """Test that log() outputs the message."""
        from gh_project_toolkit.lib.logging import log
        log("test message")
        captured = capsys.readouterr()
        assert "test message" in captured.out

    def test_log_outputs_timestamp(self, capsys: CaptureFixture[str]) -> None:
        """Test that log() outputs a timestamp."""
        from gh_project_toolkit.config.defaults import DRY_RUN, VERBOSE
        from gh_project_toolkit.lib.logging import log
        log("test")
        captured = capsys.readouterr()
        assert "[" in captured.out
        assert "]" in captured.out

    def test_log_uses_color_info(self, capsys: CaptureFixture[str]) -> None:
        """Test that log() uses COLOR_INFO."""
        from gh_project_toolkit.config.defaults import COLOR_INFO
        from gh_project_toolkit.lib.logging import log
        log("test")
        captured = capsys.readouterr()
        assert COLOR_INFO in captured.out

    def test_log_formats_with_timestamp(self, capsys: CaptureFixture[str]) -> None:
        """Test that log() formats output with timestamp."""
        from gh_project_toolkit.lib.logging import log
        log("message")
        captured = capsys.readouterr()
        assert "[" in captured.out

    def test_log_preserves_printf_formatting(self, capsys: CaptureFixture[str]) -> None:
        """Test that log() preserves printf formatting."""
        from gh_project_toolkit.lib.logging import log
        log("count: %d", 42)
        captured = capsys.readouterr()
        assert "count: 42" in captured.out

    def test_log_handles_special_characters(self, capsys: CaptureFixture[str]) -> None:
        """Test that log() handles special characters."""
        from gh_project_toolkit.lib.logging import log
        log("special: test & | < >")
        captured = capsys.readouterr()
        assert "special:" in captured.out

    def test_log_handles_empty_string(self, capsys: CaptureFixture[str]) -> None:
        """Test that log() handles empty string."""
        from gh_project_toolkit.lib.logging import log
        log("")
        captured = capsys.readouterr()
        assert captured.out is not None


class TestLogSuccessFunction:
    """Tests for the log_success() function."""

    def test_log_success_outputs_message(self, capsys: CaptureFixture[str]) -> None:
        """Test that log_success() outputs the message."""
        from gh_project_toolkit.lib.logging import log_success
        log_success("success message")
        captured = capsys.readouterr()
        assert "success message" in captured.out

    def test_log_success_uses_success_color(self, capsys: CaptureFixture[str]) -> None:
        """Test that log_success() uses COLOR_SUCCESS."""
        from gh_project_toolkit.config.defaults import COLOR_SUCCESS
        from gh_project_toolkit.lib.logging import log_success
        log_success("done")
        captured = capsys.readouterr()
        assert COLOR_SUCCESS in captured.out

    def test_log_success_uses_checkmark(self, capsys: CaptureFixture[str]) -> None:
        """Test that log_success() uses checkmark symbol."""
        from gh_project_toolkit.lib.logging import log_success
        log_success("done")
        captured = capsys.readouterr()
        assert "✓" in captured.out


class TestLogErrorFunction:
    """Tests for the log_error() function."""

    def test_log_error_outputs_message(self, capsys: CaptureFixture[str]) -> None:
        """Test that log_error() outputs the message."""
        from gh_project_toolkit.lib.logging import log_error
        log_error("error message")
        captured = capsys.readouterr()
        assert "error message" in captured.err

    def test_log_error_uses_error_color(self, capsys: CaptureFixture[str]) -> None:
        """Test that log_error() uses COLOR_ERROR."""
        from gh_project_toolkit.config.defaults import COLOR_ERROR
        from gh_project_toolkit.lib.logging import log_error
        log_error("error")
        captured = capsys.readouterr()
        assert COLOR_ERROR in captured.err

    def test_log_error_uses_x_symbol(self, capsys: CaptureFixture[str]) -> None:
        """Test that log_error() uses x symbol."""
        from gh_project_toolkit.lib.logging import log_error
        log_error("fail")
        captured = capsys.readouterr()
        assert "✗" in captured.err


class TestLogWarningFunction:
    """Tests for the log_warning() function."""

    def test_log_warning_outputs_message(self, capsys: CaptureFixture[str]) -> None:
        """Test that log_warning() outputs the message."""
        from gh_project_toolkit.lib.logging import log_warning
        log_warning("warning message")
        captured = capsys.readouterr()
        assert "warning message" in captured.out

    def test_log_warning_uses_warning_color(self, capsys: CaptureFixture[str]) -> None:
        """Test that log_warning() uses COLOR_WARN."""
        from gh_project_toolkit.config.defaults import COLOR_WARN
        from gh_project_toolkit.lib.logging import log_warning
        log_warning("alert")
        captured = capsys.readouterr()
        assert COLOR_WARN in captured.out

    def test_log_warning_uses_exclamation(self, capsys: CaptureFixture[str]) -> None:
        """Test that log_warning() uses exclamation symbol."""
        from gh_project_toolkit.lib.logging import log_warning
        log_warning("alert")
        captured = capsys.readouterr()
        assert "!" in captured.out


class TestLogVerboseFunction:
    """Tests for the log_verbose() function."""

    def test_log_verbose_outputs_when_verbose_true(
        self, capsys: CaptureFixture[str], monkeypatch: pytest.MonkeyPatch
    ) -> None:
        """Test that log_verbose() outputs when VERBOSE=true."""
        from gh_project_toolkit.lib.logging import log_verbose

        monkeypatch.setattr("gh_project_toolkit.lib.logging.VERBOSE", True)
        log_verbose("debug info")
        captured = capsys.readouterr()
        assert "[VERBOSE]" in captured.out
        assert "debug info" in captured.out

    def test_log_verbose_no_output_when_verbose_false(
        self, capsys: CaptureFixture[str], monkeypatch: pytest.MonkeyPatch
    ) -> None:
        """Test that log_verbose() does not output when VERBOSE=false."""
        from gh_project_toolkit.lib.logging import log_verbose

        monkeypatch.setattr("gh_project_toolkit.lib.logging.VERBOSE", False)
        log_verbose("debug info")
        captured = capsys.readouterr()
        assert "debug info" not in captured.out


class TestLogDryRunFunction:
    """Tests for the log_dry_run() function."""

    def test_log_dry_run_outputs_when_dry_run_true(
        self, capsys: CaptureFixture[str], monkeypatch: pytest.MonkeyPatch
    ) -> None:
        """Test that log_dry_run() outputs when DRY_RUN=true."""
        from gh_project_toolkit.lib.logging import log_dry_run

        monkeypatch.setattr("gh_project_toolkit.lib.logging.DRY_RUN", True)
        log_dry_run("would create")
        captured = capsys.readouterr()
        assert "[DRY-RUN]" in captured.out
        assert "would create" in captured.out

    def test_log_dry_run_no_output_when_dry_run_false(
        self, capsys: CaptureFixture[str], monkeypatch: pytest.MonkeyPatch
    ) -> None:
        """Test that log_dry_run() does not output when DRY_RUN=false."""
        from gh_project_toolkit.lib.logging import log_dry_run

        monkeypatch.setattr("gh_project_toolkit.lib.logging.DRY_RUN", False)
        log_dry_run("would create")
        captured = capsys.readouterr()
        assert "would create" not in captured.out


class TestPrintStatusLineFunction:
    """Tests for the print_status_line() function."""

    def test_print_status_line_outputs_separator(self, capsys: CaptureFixture[str]) -> None:
        """Test that print_status_line() outputs separator character."""
        from gh_project_toolkit.lib.logging import print_status_line
        print_status_line("=")
        captured = capsys.readouterr()
        assert "=" in captured.out

    def test_print_status_line_uses_default_separator(self, capsys: CaptureFixture[str]) -> None:
        """Test that print_status_line() uses default separator."""
        from gh_project_toolkit.lib.logging import print_status_line
        print_status_line()
        captured = capsys.readouterr()
        assert "=" in captured.out


class TestPrintSectionHeaderFunction:
    """Tests for the print_section_header() function."""

    def test_print_section_header_outputs_title(self, capsys: CaptureFixture[str]) -> None:
        """Test that print_section_header() outputs the title."""
        from gh_project_toolkit.lib.logging import print_section_header
        print_section_header("Test Section")
        captured = capsys.readouterr()
        assert "Test Section" in captured.out

    def test_print_section_header_uses_separator(self, capsys: CaptureFixture[str]) -> None:
        """Test that print_section_header() uses separator."""
        from gh_project_toolkit.lib.logging import print_section_header
        print_section_header("Test")
        captured = capsys.readouterr()
        assert "=" in captured.out


class TestPrintSummaryFunction:
    """Tests for the print_summary() function."""

    def test_print_summary_outputs_message(self, capsys: CaptureFixture[str]) -> None:
        """Test that print_summary() outputs the message."""
        from gh_project_toolkit.lib.logging import print_summary
        print_summary("Complete")
        captured = capsys.readouterr()
        assert "Complete" in captured.out
        assert "=" in captured.out


if __name__ == "__main__":
    pytest.main([__file__, "-v"])