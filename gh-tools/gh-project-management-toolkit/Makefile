# =============================================================================
# Makefile - GitHub Project Management Toolkit
# =============================================================================
# This Makefile provides commands for testing, linting, and managing the
# Python version of the GitHub Project Management Toolkit.
#
# Usage:
#   make test              # Run all tests
#   make test-coverage     # Run tests with coverage
#   make lint              # Run linting
#   make format            # Format code with black
#   make type-check        # Run mypy type checking
#   make clean             # Clean up test artifacts
# =============================================================================

# Configuration
PYTHON := python3
PIP := pip3
TESTS_DIR := tests
SRC_DIR := src

# Colors for output
BLUE := \033[1;34m
GREEN := \033[1;32m
RED := \033[1;31m
YELLOW := \033[1;33m
RESET := \033[0m

# Default target
.PHONY: all
all: test

# =============================================================================
# Testing Targets
# =============================================================================

## Run all tests
.PHONY: test
test:
	@echo -e "$(BLUE)Running all tests...$(RESET)"
	$(PYTHON) -m pytest $(TESTS_DIR)/ -v

## Run tests with coverage
.PHONY: test-coverage
test-coverage:
	@echo -e "$(BLUE)Running tests with coverage...$(RESET)"
	$(PYTHON) -m pytest $(TESTS_DIR)/ --cov=$(SRC_DIR)/gh_project_toolkit --cov-report=term-missing --cov-report=html

## Run tests for a specific module
.PHONY: test-module
test-module:
	@echo -e "$(BLUE)Running tests for module...$(RESET)"
	$(PYTHON) -m pytest $(TESTS_DIR)/$(MODULE) -v

# =============================================================================
# Linting and Formatting
# =============================================================================

## Run ruff linting
.PHONY: lint
lint:
	@echo -e "$(BLUE)Running ruff linting...$(RESET)"
	$(PYTHON) -m ruff check $(SRC_DIR)/ $(TESTS_DIR)/

## Run ruff linting with fixes
.PHONY: lint-fix
lint-fix:
	@echo -e "$(BLUE)Running ruff linting with fixes...$(RESET)"
	$(PYTHON) -m ruff check $(SRC_DIR)/ $(TESTS_DIR)/ --fix

## Run mypy type checking
.PHONY: type-check
type-check:
	@echo -e "$(BLUE)Running mypy type checking...$(RESET)"
	$(PYTHON) -m mypy $(SRC_DIR)/

## Format code with black
.PHONY: format
format:
	@echo -e "$(BLUE)Formatting code with black...$(RESET)"
	$(PYTHON) -m black $(SRC_DIR)/ $(TESTS_DIR)/

# =============================================================================
# Development Targets
# =============================================================================

## Install development dependencies
.PHONY: install-dev
install-dev:
	@echo -e "$(BLUE)Installing development dependencies...$(RESET)"
	$(PIP) install -e ".[dev]"

## Install production dependencies
.PHONY: install
install:
	@echo -e "$(BLUE)Installing production dependencies...$(RESET)"
	$(PIP) install -e .

## Uninstall
.PHONY: uninstall
uninstall:
	@echo -e "$(BLUE)Uninstalling package...$(RESET)"
	$(PIP) uninstall -y gh-project-management-toolkit

# =============================================================================
# Clean Targets
# =============================================================================

## Clean up test artifacts
.PHONY: clean
clean:
	@echo -e "$(BLUE)Cleaning test artifacts...$(RESET)"
	rm -rf coverage/
	rm -rf .pytest_cache/
	rm -rf __pycache__/
	rm -rf $(SRC_DIR)/__pycache__/
	rm -rf $(TESTS_DIR)/__pycache__/
	find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name "*.pyc" -delete 2>/dev/null || true
	@echo -e "$(GREEN)Cleaned$(RESET)"

## Clean build artifacts
.PHONY: clean-build
clean-build:
	@echo -e "$(BLUE)Cleaning build artifacts...$(RESET)"
	rm -rf build/
	rm -rf dist/
	rm -rf *.egg-info/
	@echo -e "$(GREEN)Cleaned build artifacts$(RESET)"

# =============================================================================
# Documentation
# =============================================================================

## Show this help message
.PHONY: help
help:
	@echo -e "$(BLUE)GitHub Project Management Toolkit Makefile Help$(RESET)"
	@echo ""
	@echo "Testing:"
	@echo "  make test              Run all tests"
	@echo "  make test-coverage     Run tests with coverage"
	@echo "  make test-module       Run tests for a specific module"
	@echo ""
	@echo "Linting and Formatting:"
	@echo "  make lint              Run ruff linting"
	@echo "  make lint-fix          Run ruff linting with fixes"
	@echo "  make type-check        Run mypy type checking"
	@echo "  make format            Format code with black"
	@echo ""
	@echo "Development:"
	@echo "  make install           Install production dependencies"
	@echo "  make install-dev       Install development dependencies"
	@echo "  make uninstall         Uninstall package"
	@echo ""
	@echo "Cleaning:"
	@echo "  make clean             Clean up test artifacts"
	@echo "  make clean-build       Clean build artifacts"
	@echo ""
	@echo -e "$(BLUE)For more information, see README.md$(RESET)"

# =============================================================================
# Phony Targets
# =============================================================================

.PHONY: all test test-coverage test-module lint lint-fix type-check format \
	install install-dev uninstall clean clean-build help
