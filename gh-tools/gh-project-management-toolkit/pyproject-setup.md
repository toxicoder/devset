# GitHub Project Management Toolkit - Python

A Python-based toolkit for automating GitHub project management tasks including milestone creation, label setup, Project V2 board management, and issue processing.

## Overview

This is the Python version of the GitHub Project Management Toolkit, which was originally written in Bash. The Python version provides:

- Better type safety with type hints
- More powerful testing with pytest
- Better IDE support with autocomplete and refactoring
- More maintainable code structure
- Easier to extend with Python's rich ecosystem

## Project Structure

```text
gh-tools/gh-project-management-toolkit/
├── pyproject.toml              # Python project configuration
├── pyproject-setup.md          # This file
├── src/
│   └── gh_project_toolkit/
│       ├── __init__.py         # Package initialization
│       ├── __main__.py         # CLI entry point (python -m)
│       ├── cli.py              # Command-line interface
│       │
│       ├── config/
│       │   ├── __init__.py
│       │   ├── defaults.py     # Configuration defaults
│       │   └── milestones.py   # Milestone definitions
│       │
│       └── lib/
│           ├── __init__.py
│           ├── logging.py      # Logging utilities
│           ├── validation.py   # Validation functions
│           ├── github_api.py   # GitHub API client
│           ├── labels.py       # Label management
│           ├── projects.py     # Project V2 management
│           ├── issues.py       # Issue processing
│           └── duplicates.py   # Duplicate detection
│
├── tests/
│   ├── conftest.py             # Pytest fixtures
│   ├── test_config/
│   │   ├── test_defaults.py
│   │   └── test_milestones.py
│   └── test_lib/
│       ├── test_logging.py
│       ├── test_validation.py
│       ├── test_github_api.py
│       ├── test_labels.py
│       ├── test_projects.py
│       ├── test_issues.py
│       └── test_duplicates.py
│
├── Makefile                    # Python project Makefile
└── issues.json                 # Sample issues data
```

## Installation

### Prerequisites

- Python 3.8 or higher
- pip (Python package manager)

### Install from PyPI

```bash
pip install gh-project-management-toolkit
```

### Install from Source

```bash
cd gh-tools/gh-project-management-toolkit
pip install -e .
```

### Install Development Dependencies

```bash
pip install -e ".[dev]"
```

## Usage

### Command Line

```bash
# Show help
gh-project-toolkit --help

# Run in dry-run mode
gh-project-toolkit --dry-run

# Run with verbose output
gh-project-toolkit --verbose

# Run with custom repository
gh-project-toolkit --repo owner/repo

# Check for duplicates
gh-project-toolkit --cleanup-duplicates

# Run cleanup (dry-run)
gh-project-toolkit --cleanup-duplicates

# Run cleanup (apply changes)
gh-project-toolkit --cleanup-duplicates --apply
```

### Python API

```python
from gh_project_toolkit.cli import main
from gh_project_toolkit.lib.github_api import get_owner_id, create_milestone
from gh_project_toolkit.lib.validation import validate_repo_format

# Run the CLI
main()

# Use the API directly
owner_id = get_owner_id("owner", "repo")
success = create_milestone("owner", "repo", "v1.0", "Description")
```

### Python Module

```bash
# Run as a module
python -m gh_project_toolkit --help
```

## Testing

### Run All Tests

```bash
make test
# or
pytest tests/
```

### Run Tests with Coverage

```bash
make test-coverage
# or
pytest tests/ --cov=src/gh_project_toolkit --cov-report=term-missing
```

### Run Tests for a Specific Module

```bash
make test-module MODULE=test_lib/test_logging.py
# or
pytest tests/test_lib/test_logging.py
```

### Run Tests with Verbose Output

```bash
pytest tests/ -v
```

## Development

### Linting

```bash
# Run ruff linting
make lint

# Run ruff with fixes
make lint-fix
```

### Type Checking

```bash
make type-check
# or
mypy src/
```

### Formatting

```bash
make format
# or
black src/ tests/
```

### Clean Build Artifacts

```bash
make clean
# or
make clean-build
```

## Configuration

The toolkit uses configuration from `src/gh_project_toolkit/config/defaults.py` and `src/gh_project_toolkit/config/milestones.py`.

### Environment Variables

- `DRY_RUN`: Set to "true" for dry-run mode
- `VERBOSE`: Set to "true" for verbose output
- `TMPDIR`: Set temporary directory (default: /tmp)

### GitHub API

The toolkit uses the GitHub API. You need to set the `GITHUB_TOKEN` environment variable with a personal access token that has the appropriate permissions.

```bash
export GITHUB_TOKEN=your_token_here
```

## License

MIT License - See LICENSE file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request
