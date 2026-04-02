# Tests

## Running Tests

This project uses pytest for Python testing.

```bash
# Install development dependencies
pip install -e ".[dev]"

# Run all tests
pytest tests/ -v

# Run tests with coverage
pytest tests/ --cov=src/gh_project_toolkit --cov-report=term-missing

# Run a specific test file
pytest tests/test_lib/test_logging.py -v

# Run a specific test function
pytest tests/test_lib/test_logging.py::test_log_verbose -v
```

## Test Coverage

| Module      | Test File                       | Status   |
| :---------- | :------------------------------ | :------- |
| Logging     | `tests/test_lib/test_logging.py`    | Complete |
| Validation  | `tests/test_lib/test_validation.py` | Complete |
| GitHub API  | `tests/test_lib/test_github_api.py` | Complete |
| Milestones  | `tests/test_config/test_milestones.py` | Complete |
| Labels      | `tests/test_lib/test_labels.py`     | Complete |
| Projects    | `tests/test_lib/test_projects.py`   | Complete |
| Issues      | `tests/test_lib/test_issues.py`     | Complete |
| Duplicates  | `tests/test_lib/test_duplicates.py` | Complete |

## Directory Structure

```text
tests/
├── README.md                   # This file
├── conftest.py                 # Pytest fixtures
├── test_config/                # Configuration tests
│   ├── test_defaults.py
│   └── test_milestones.py
└── test_lib/                   # Library tests
    ├── test_logging.py
    ├── test_validation.py
    ├── test_github_api.py
    ├── test_labels.py
    ├── test_projects.py
    ├── test_issues.py
    └── test_duplicates.py
```

## Making a Test Run

```bash
# Run all tests with verbose output
pytest tests/ -v

# Run with coverage report
pytest tests/ --cov=src/gh_project_toolkit --cov-report=term-missing

# Run a specific module
pytest tests/test_lib/test_validation.py -v

# Run with debug output
pytest tests/ -v -s
```

## Adding New Tests

1. Create test file in `tests/test_lib/` or `tests/test_config/`
2. Name files with `test_*.py` prefix
3. Name test functions with `test_*` prefix
4. Use pytest fixtures from `conftest.py`
5. Run tests to verify they pass