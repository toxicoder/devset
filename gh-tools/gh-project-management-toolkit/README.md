# GitHub Project Management Toolkit

A Python-based toolkit for automating GitHub project management tasks including milestone creation, label setup, Project V2 board management, and issue processing.

## Features

- **Milestone Management**: Create and manage GitHub milestones
- **Label Management**: Create and manage GitHub labels with color coding
- **Project V2 Setup**: Initialize GitHub Projects (beta)
- **Issue Processing**: Bulk import issues from JSON files
- **Duplicate Detection**: Find and cleanup duplicate milestones/labels/issues
- **Dry-run Mode**: Preview changes without making them
- **Verbose Logging**: Detailed output for debugging

## Installation

### Prerequisites

- Python 3.8 or higher
- pip (Python package manager)
- GitHub Personal Access Token (with repo scope)

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

# Run in dry-run mode (no changes made)
gh-project-toolkit setup owner repo --dry-run

# Create project setup (actual changes)
gh-project-toolkit setup owner repo -y

# Process issues from JSON file
gh-project-toolkit issues owner repo issues.json

# Cleanup duplicates (dry-run)
gh-project-toolkit cleanup owner repo

# Cleanup duplicates (apply changes)
gh-project-toolkit cleanup owner repo --yes
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

### As a Python Module

```bash
# Run as a module
python -m gh_project_toolkit --help
```

## Configuration

The toolkit uses configuration from:

- `src/gh_project_toolkit/config/defaults.py` - General defaults
- `src/gh_project_toolkit/config/milestones.py` - Milestone definitions

### Environment Variables

| Variable       | Description                           | Required |
| :------------- | :------------------------------------ | :------- |
| `GITHUB_TOKEN` | Personal access token with repo scope | Yes      |
| `DRY_RUN`      | Set to "true" for dry-run mode        | No       |
| `VERBOSE`      | Set to "true" for verbose output      | No       |

### GitHub Token

Create a Personal Access Token (PAT) with the following scopes:

- `repo` - Full control of private repositories
- `public_repo` - Access to public repositories

Set your token:

```bash
export GITHUB_TOKEN=your_token_here
```

## Testing in Module Reference

### Run All Tests

```bash
make test
# or
pytest tests/ -v
```

### Run Tests with Coverage

```bash
make test-coverage
# or
pytest tests/ --cov=src/gh_project_toolkit --cov-report=term-missing
```

### Run Tests for a Specific Module

```bash
pytest tests/test_lib/test_logging.py -v
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

## Project Structure

```text
gh-tools/gh-project-management-toolkit/
├── src/
│   └── gh_project_toolkit/
│       ├── __init__.py         # Package initialization
│       ├── cli.py              # Command-line interface
│       ├── models.py           # Pydantic models
│       ├── config/
│       │   ├── __init__.py
│       │   ├── defaults.py     # Configuration defaults
│       │   └── milestones.py   # Milestone definitions
│       └── lib/
│           ├── __init__.py
│           ├── logging.py      # Logging utilities
│           ├── validation.py   # Validation functions
│           ├── github_api.py   # GitHub API client
│           ├── labels.py       # Label management
│           ├── projects.py     # Project V2 management
│           ├── issues.py       # Issue processing
│           └── duplicates.py   # Duplicate detection
├── tests/
│   ├── conftest.py             # Pytest fixtures
│   ├── test_config/            # Configuration tests
│   └── test_lib/               # Library tests
├── Makefile                    # Build commands
├── pyproject.toml              # Python project config
├── pyrightconfig.json          # Pyright type checker config
└── README.md                   # This file
```

## Module Reference

### Package Modules

#### `gh_project_toolkit`

The main package module provides package-level metadata and exports core functionality.

**Location**: `src/gh_project_toolkit/__init__.py`

**Exports**:

- `__version__` - Package version (e.g., "1.0.0")
- `__author__` - Package author
- `__description__` - Package description

**Example**:

```python
from gh_project_toolkit import __version__, __author__
print(f"Version: {__version__}, Author: {__author__}")
```

#### `gh_project_toolkit.cli`

Command-line interface for the toolkit.

**Location**: `src/gh_project_toolkit/cli.py`

**Main Functions**:

- `main()` - Main entry point for CLI
- `setup_project(owner, repo, project_name, dry_run)` - Setup GitHub project with milestones and labels
- `process_project_issues(owner, repo, json_file, project_id)` - Process issues from JSON file
- `cleanup_duplicates(owner, repo, titles)` - Cleanup duplicate milestones and labels

**CLI Commands**:

| Command | Description |
| :------ | :---------- |
| `setup` | Setup a new GitHub project with milestones and labels |
| `issues` | Process issues from JSON file |
| `cleanup` | Cleanup duplicate milestones/labels/issues |

**CLI Options**:

| Option | Description |
| :----- | :---------- |
| `--version` | Show version and exit |
| `-v, --verbose` | Enable verbose output |
| `--dry-run` | Enable dry-run mode (no changes made) |
| `-y, --yes` | Skip confirmation prompts |
| `-p, --project` | Specify project name (default: "Development Roadmap") |

**Example**:

```python
from gh_project_toolkit.cli import main, setup_project

# Run CLI
main()

# Use function directly
result = setup_project("owner", "repo", "My Project", dry_run=False)
```

#### `gh_project_toolkit.models`

Pydantic models for data validation and serialization.

**Location**: `src/gh_project_toolkit/models.py`

**Issue Models**:

| Model | Description |
| :---- | :---------- |
| `Issue` | Represents a GitHub issue with title, body, labels, milestone, assignees |
| `IssueCreateRequest` | Request model for creating an issue |
| `IssueModel` | Model for GitHub issue data from API responses |

**Milestone Models**:

| Model | Description |
| :---- | :---------- |
| `Milestone` | Represents a GitHub milestone with title, description, due_on, state |
| `MilestoneCreateRequest` | Request model for creating a milestone |
| `MilestoneModel` | Model for GitHub milestone data from API responses |

**Label Models**:

| Model | Description |
| :---- | :---------- |
| `Label` | Represents a GitHub label with name, color, description |
| `LabelCreateRequest` | Request model for creating a label |
| `LabelModel` | Model for GitHub label data from API responses |

**Project V2 Models**:

| Model | Description |
| :---- | :---------- |
| `ProjectFieldOption` | Option for a Project V2 single-select field |
| `ProjectField` | Project V2 field with options |
| `ProjectV2` | GitHub Project V2 with id, title, number, state |
| `ProjectItem` | Item in a Project V2 |

**Response Models**:

| Model | Description |
| :---- | :---------- |
| `GitHubResponse` | Base model for GitHub API responses |
| `CreateIssueResponse` | Response model for issue creation |
| `CreateMilestoneResponse` | Response model for milestone creation |
| `CreateLabelResponse` | Response model for label creation |

**Example**:

```python
from gh_project_toolkit.models import Issue, Milestone, Label

# Create an issue
issue = Issue(
    title="Fix bug",
    body="Description of the bug",
    labels=["bug", "high-priority"],
    milestone="v1.0",
    assignees=["user1", "user2"]
)

# Create a milestone
milestone = Milestone(
    title="v1.0",
    description="Major release",
    due_on="2024-12-31",
    state="open"
)

# Create a label
label = Label(
    name="bug",
    color="e11d21",
    description="Something isn't working"
)
```

### Configuration Module (`config/`)

#### `defaults.py`

Default configuration values for the toolkit.

**Location**: `src/gh_project_toolkit/config/defaults.py`

**Script Metadata**:

| Constant | Type | Default | Description |
| :------- | :--- | :------ | :---------- |
| `SCRIPT_NAME` | `str` | `"setup-restoclaw.py"` | Script name for display |
| `SCRIPT_VERSION` | `str` | `"1.0.0"` | Script version |
| `SCRIPT_DESCRIPTION` | `str` | Creates GitHub milestones... | Script description |

**GitHub Repository Configuration**:

| Constant | Type | Default | Description |
| :------- | :--- | :------ | :---------- |
| `DEFAULT_REPO` | `str` | `"toxicoder/RestoClaw"` | Default repository |
| `DEFAULT_JSON_FILE` | `str` | `"issues.json"` | Default issues file |
| `DEFAULT_PROJECT_NAME` | `str` | `"RestoClaw Development Roadmap"` | Default project name |

**Paths and Files**:

| Constant | Type | Default | Description |
| :------- | :--- | :------ | :---------- |
| `ISSUES_JSON_PATH` | `str` | `"issues.json"` | Path to issues file |
| `TMP_DIR` | `str` | `"/tmp"` | Temporary directory |

**GitHub API Configuration**:

| Constant | Type | Default | Description |
| :------- | :--- | :------ | :---------- |
| `GITHUB_GRAPHQL_ENDPOINT` | `str` | `"https://api.github.com/graphql"` | GraphQL endpoint |
| `GITHUB_REST_API_BASE` | `str` | `"https://api.github.com"` | REST API base |

**Exit Codes**:

| Constant | Type | Value | Description |
| :------- | :--- | :---- | :---------- |
| `EXIT_SUCCESS` | `int` | `0` | Success exit code |
| `EXIT_ERROR` | `int` | `1` | General error |
| `EXIT_MISSING_CMD` | `int` | `2` | Missing command |
| `EXIT_INVALID_CONFIG` | `int` | `3` | Invalid config |
| `EXIT_API_ERROR` | `int` | `4` | API error |

**Functions**:

- `get_script_dir()` - Get directory containing the script
- `get_script_path()` - Get full path to main script file

**Example**:

```python
from gh_project_toolkit.config.defaults import (
    DEFAULT_REPO,
    DEFAULT_PROJECT_NAME,
    EXIT_SUCCESS,
    SCRIPT_VERSION
)

print(f"Default repo: {DEFAULT_REPO}")
print(f"Script version: {SCRIPT_VERSION}")
```

#### `milestones.py`

Milestone definitions and label groupings.

**Location**: `src/gh_project_toolkit/config/milestones.py`

**Milestones** (`MILESTONES`):
A dictionary mapping milestone titles to descriptions.

| Milestone | Description |
| :-------- | :---------- |
| `"v0.0 Foundations"` | Repo, Docker, basic NemoClaw/OpenClaw install, logging, CI. |
| `"v0.1 Email Digest MVP"` | 4x daily digests + cross-channel conversational follow-up. |
| `"v0.2 Auto-Reply Drafting"` | One-click AI-draft replies with approval gate. |
| `"v0.3 Inventory + Supplier Ordering"` | Daily stock-check, low-stock alerts, suggested POs, one-click order. |
| `"v0.4 POS Sync & Daily Sales Brief"` | Pull sales from Toast/Square/Lightspeed, produce sales brief. |
| `"v0.5 Review Monitoring"` | Scrape reviews, sentiment-flag negatives, draft response. |
| `"v1.0 Full Restaurant OS"` | Staff scheduling, reservation management, marketing automation. |

**Labels** (`ALL_LABELS`):

List of 37 labels organized by category:

- Phase labels (mvp, phase:*)
- Integration labels (integration:*)
- Skill labels (skill:*)
- Priority labels (priority:*, good-first-issue)
- Category labels (documentation, testing, etc.)
- Milestone labels (milestone:v*)

**Functions**:


| Function | Description |
| :------- | :---------- |
| `get_milestone_titles()` | Get all milestone titles as list |
| `get_milestone_description(title)` | Get description by title |
| `get_all_milestones()` | Get milestones as list of dicts |
| `count_milestones()` | Count total milestones |
| `get_milestones_json()` | Get milestones as JSON string |
| `count_labels()` | Count total labels |
| `get_label_color(label)` | Get color code for label |
| `get_all_labels_by_category()` | Get labels organized by category |
| `get_label_count(category)` | Get label count for category |

**Label Colors** (`LABEL_COLORS`):

Dictionary mapping labels to 6-character hex color codes:

- `priority:high` - `e11d21` (Red)
- `priority:medium` - `d93f0b` (Orange)
- `good-first-issue` - `008672` (Green)
- `documentation` - `0075ca` (Blue)
- `testing` - `be805e` (Brown)
- `phase:*` - `58a6ff` (Blue)
- `integration:*` - `1677e2` (Darker blue)
- `skill:*` - `8b5cf6` (Purple)
- `milestone:*` - `d2b48c` (Tan)

**Example**:

```python
from gh_project_toolkit.config.milestones import (
    MILESTONES,
    ALL_LABELS,
    get_milestone_description,
    get_label_color,
    count_milestones
)

# Get milestone description
desc = get_milestone_description("v0.0 Foundations")
# Returns: "Repo, Docker, basic NemoClaw/OpenClaw install, logging, CI."

# Get label color
color = get_label_color("priority:high")
# Returns: "e11d21"

# Count milestones
count = count_milestones()
# Returns: 7
```

### Library Module (`lib/`)

#### `logging.py`

Logging and output utilities with colored output and dry-run support.

**Location**: `src/gh_project_toolkit/lib/logging.py`

**Configuration**:

| Variable | Type | Default | Description |
| :------- | :---- | :------ | :---------- |
| `COLOR_INFO` | `str` | `"\033[1;34m"` | Blue color code |
| `COLOR_ERROR` | `str` | `"\033[1;31m"` | Red color code |
| `COLOR_SUCCESS` | `str` | `"\033[1;32m"` | Green color code |
| `COLOR_WARN` | `str` | `"\033[1;33m"` | Yellow color code |
| `COLOR_RESET` | `str` | `"\033[0m"` | Reset color |
| `DRY_RUN` | `bool` | `False` | Dry-run mode flag |
| `VERBOSE` | `bool` | `False` | Verbose mode flag |

**Logging Functions**:

| Function | Description | Example |
| :------- | :---------- | :------ |
| `log(message, *args, **kwargs)` | Log informational message | `log("Starting setup")` |
| `log_success(message, *args, **kwargs)` | Log success message | `log_success("Setup complete")` |
| `log_error(message, *args, **kwargs)` | Log error to stderr | `log_error("Connection failed")` |
| `log_warning(message, *args, **kwargs)` | Log warning message | `log_warning("Deprecated option")` |
| `log_verbose(message, *args, **kwargs)` | Log verbose (only if VERBOSE=true) | `log_verbose("Debug info")` |
| `log_dry_run(message, *args, **kwargs)` | Log dry-run (only if DRY_RUN=true) | `log_dry_run("Would create milestone")` |

**Status Line Functions**:

| Function | Description | Example |
| :------- | :---------- | :------ |
| `print_status_line(char="=", width=None)` | Print status line separator | `print_status_line()` |
| `print_section_header(title, char="=")` | Print section header | `print_section_header("Processing")` |
| `print_summary(summary)` | Print final summary | `print_summary("All done")` |
| `print_summary_line(char="=", width=None)` | Print summary separator | `print_summary_line()` |

**Example**:

```python
from gh_project_toolkit.lib.logging import (
    log, log_success, log_error, log_warning,
    log_verbose, log_dry_run,
    print_status_line, print_section_header
)

# Basic logging
log("Starting setup")
log_success("Setup complete")

# With formatting
log("Processing %d items", 42)
log("Value: {value}", value=123)

# Verbose logging (only when VERBOSE=true)
log_verbose("Debug: processing item %d", current)

# Dry-run logging (only when DRY_RUN=true)
log_dry_run("Would create milestone: %s", title)

# Status lines
print_status_line()
print_section_header("Setup Complete")
```

#### `validation.py`

Validation and dependency checking utilities.

**Location**: `src/gh_project_toolkit/lib/validation.py`

**Dependency Checking Functions**:

| Function | Description | Returns |
| :------- | :---------- | :------ |
| `require_cmd(cmd)` | Check if command is available | `bool` |
| `require_all_cmds(*cmds)` | Check if all commands are available | `bool` |

**File Validation Functions**:

| Function | Description | Returns |
| :------- | :---------- | :------ |
| `require_file(file_path)` | Check if file exists | `bool` |
| `require_non_empty_file(file_path)` | Check if file has content | `bool` |

**JSON Validation Functions**:

| Function | Description | Returns |
| :------- | :---------- | :------ |
| `validate_json(file_path)` | Validate JSON file | `bool` |
| `validate_json_array(file_path)` | Validate JSON array | `bool` |

**Repository Validation Functions**:

| Function | Description | Returns |
| :------- | :---------- | :------ |
| `validate_git_repo()` | Check if current dir is Git repo | `bool` |
| `validate_repo_format(repo)` | Validate OWNER/REPO format | `bool` |

**Input Validation Functions**:

| Function | Description | Returns |
| :------- | :---------- | :------ |
| `require_non_empty(name, value)` | Check if string is not empty | `bool` |
| `require_range(name, value, min_val, max_val)` | Check if number in range | `bool` |

**Utility Functions**:
| Function | Description |
| :------- | :---------- |
| `print_validation_summary(total, success, failures)` | Print validation summary |
| `print_checkmark(count)` | Print checkmark symbol |
| `print_xmark(count)` | Print X mark symbol |

**Example**:

```python
from gh_project_toolkit.lib.validation import (
    require_cmd, require_all_cmds,
    require_file, require_non_empty_file,
    validate_json, validate_json_array,
    validate_repo_format, require_non_empty
)

# Check commands
if not require_cmd("gh"):
    print("GitHub CLI not found")

# Check files
if not require_file("config.json"):
    print("Config file missing")

# Validate JSON
if validate_json_array("issues.json"):
    print("Valid issues file")

# Validate repo format
if not validate_repo_format("owner/repo"):
    print("Invalid repository format")

# Validate input
if not require_non_empty("title", title):
    print("Title is required")
```

#### `github_api.py`

GitHub API helper functions for GraphQL and REST endpoints.

**Location**: `src/gh_project_toolkit/lib/github_api.py`

**Repository Information Functions**:

| Function | Description | Returns |
| :------- | :---------- | :------ |
| `get_owner_id(owner, repo)` | Get repository owner ID | `Optional[str]` |
| `get_repo_id(owner, repo)` | Get repository node ID | `Optional[str]` |

**Milestone Functions**:

| Function | Description | Returns |
| :------- | :---------- | :------ |
| `create_milestone(owner, repo, title, description, due_date)` | Create milestone | `Optional[str]` |
| `get_all_milestones(owner, repo)` | Get all milestones | `List[Dict]` |

**Label Functions**:

| Function | Description | Returns |
| :------- | :---------- | :------ |
| `create_label(owner, repo, name, color, description)` | Create label | `bool` |
| `delete_label(owner, repo, name)` | Delete label | `bool` |
| `get_all_labels(owner, repo)` | Get all labels | `List[Dict]` |

**Project V2 Functions**:

| Function | Description | Returns |
| :------- | :---------- | :------ |
| `project_exists(owner_id, title)` | Check if Project V2 exists | `Optional[str]` |
| `create_project(owner_id, title)` | Create Project V2 | `Optional[str]` |
| `get_project_fields(project_id)` | Get Project V2 fields | `Dict[str, Any]` |
| `add_issue_to_project(project_id, content_id)` | Add issue to Project V2 | `Optional[str]` |
| `update_project_field(project_id, item_id, field_id, option_id)` | Update field value | `bool` |
| `get_todo_option(fields_json)` | Get "To Do" option ID | `Optional[str]` |
| `get_status_field_id(fields_json)` | Get Status field ID | `Optional[str]` |

**Issue Functions**:

| Function | Description | Returns |
| :------- | :---------- | :------ |
| `create_issue(owner, repo, title, body, labels, milestone, assignees)` | Create issue | `Optional[str]` |
| `get_issue_node_id(owner, repo, number)` | Get issue node ID | `Optional[str]` |

**Helper Functions**:

| Function | Description | Returns |
| :------- | :---------- | :------ |
| `get_all_issues(owner, repo)` | Get all issues | `List[Dict]` |
| `delete_issue(owner, repo, number)` | Delete issue | `bool` |
| `milestone_exists(owner, repo, title)` | Check if milestone exists | `bool` |
| `label_exists(owner, repo, name)` | Check if label exists | `bool` |
| `issue_exists(owner, repo, title)` | Check if issue exists | `bool` |
| `get_label_color(label)` | Get label color | `str` |
| `wait_rate_limit(seconds)` | Wait for rate limit | `None` |

**Example**:

```python
from gh_project_toolkit.lib.github_api import (
    get_owner_id, get_repo_id,
    create_milestone, get_all_milestones,
    create_label, get_all_labels,
    create_issue, get_issue_node_id,
    milestone_exists, label_exists, issue_exists
)

# Get owner ID
owner_id = get_owner_id("owner", "repo")
# Returns: "U_kgDOBf1x7w" or None

# Create milestone
milestone_num = create_milestone(
    "owner", "repo", "v1.0",
    "Major release", "2024-12-31"
)
# Returns: "1" or None

# Create label
created = create_label(
    "owner", "repo", "bug",
    "e11d21", "Something isn't working"
)
# Returns: True or False

# Check if milestone exists
if milestone_exists("owner", "repo", "v1.0"):
    print("Milestone already exists")

# Create issue
issue_url = create_issue(
    "owner", "repo",
    "Fix bug",
    "Description",
    "bug,high-priority"
)
# Returns: "https://github.com/owner/repo/issues/123" or None
```

#### `labels.py`

Label management functions.

**Location**: `src/gh_project_toolkit/lib/labels.py`

**Functions**:


| Function | Description | Returns |
| :------- | :---------- | :------ |
| `get_all_labels_by_category()` | Get labels by category | `Dict[str, List[str]]` |
| `get_all_labels_array()` | Get labels as flat list | `List[str]` |
| `create_all_labels(owner, repo, color)` | Create all labels | `int` |
| `create_labels_by_category(owner, repo, category, color)` | Create category labels | `int` |
| `get_label_count(category)` | Get label count | `int` |
| `get_label_color(label)` | Get label color | `str` |

**Label Categories**:

| Category | Labels |
| :------- | :----- |
| `phase` | mvp, phase:foundations, phase:core-skill, phase:integrations, phase:conversation, phase:security, phase:infrastructure |
| `integration` | integration:google, integration:twilio, integration:nemoclaw |
| `skill` | skill:digest, skill:inventory, skill:pos, skill:review, skill:staff, skill:reservation, skill:marketing, skill:order, skill:sales-brief, skill:sentiment, skill:review-response |
| `priority` | priority:high, priority:medium, good-first-issue |
| `category` | documentation, testing, infrastructure, onboarding, configuration, ci-cd, observability, e2e, performance |
| `milestone` | milestone:v0.0, milestone:v0.1, milestone:v0.2, milestone:v0.3, milestone:v0.4, milestone:v0.5, milestone:v1.0 |

**Example**:

```python
from gh_project_toolkit.lib.labels import (
    get_all_labels_by_category,
    create_all_labels,
    create_labels_by_category,
    get_label_count,
    get_label_color
)

# Get labels by category
labels = get_all_labels_by_category()
# Returns: {"phase": [...], "integration": [...], ...}

# Create all labels
created = create_all_labels("owner", "repo", "ededed")
# Returns: 37 (number created)

# Create labels by category
created = create_labels_by_category("owner", "repo", "phase", "ededed")
# Returns: 7 (number created)

# Get label count
count = get_label_count("phase")
# Returns: 7
```

#### `projects.py`

Project V2 management functions.

**Location**: `src/gh_project_toolkit/lib/projects.py`

**Configuration**:

| Variable | Type | Default | Description |
| :------- | :---- | :------ | :---------- |
| `DEFAULT_PROJECT_NAME` | `str` | `"RestoClaw Development Roadmap"` | Default project name |

**Main Functions**:

| Function | Description | Returns |
| :------- | :---------- | :------ |
| `ensure_project_exists(owner, repo, project_name)` | Create or find Project V2 | `Optional[str]` |
| `configure_project_fields(project_id)` | Configure Project V2 fields | `bool` |
| `create_project_field(project_id, field_name, field_type)` | Create custom field | `Optional[str]` |
| `create_project_field_option(field_id, option_name)` | Create field option | `Optional[str]` |
| `get_project_todo_option(project_id)` | Get "To Do" option | `Optional[str]` |
| `link_issue_to_project(project_id, owner, repo, issue_number)` | Add issue to Project V2 | `Optional[str]` |
| `print_project_summary(project_name, project_id, issue_count)` | Print summary | `None` |

**Aliases**:
- `create_or_find_project` - Alias for `ensure_project_exists`

**Example**:

```python
from gh_project_toolkit.lib.projects import (
    ensure_project_exists,
    configure_project_fields,
    link_issue_to_project,
    print_project_summary
)

# Ensure project exists
project_id = ensure_project_exists("owner", "repo", "My Project")
# Returns: "PVT_xxx" or None

# Configure project fields
success = configure_project_fields(project_id)
# Returns: True

# Link issue to project
item_id = link_issue_to_project(project_id, "owner", "repo", 123)
# Returns: "PVTI_xxx" or None

# Print project summary
print_project_summary("My Project", project_id, 10)
```

#### `issues.py`

Issue processing and JSON handling functions.

**Location**: `src/gh_project_toolkit/lib/issues.py`

**Configuration**:

| Variable | Type | Default | Description |
| :------- | :---- | :------ | :---------- |
| `TMP_DIR` | `str` | `"/tmp"` | Temporary directory |
| `DRY_RUN` | `bool` | `False` | Dry-run mode |
| `VERBOSE` | `bool` | `False` | Verbose mode |

**Temporary File Functions**:

| Function | Description | Returns |
| :------- | :---------- | :------ |
| `create_temp_file(base)` | Create temp file | `str` |
| `cleanup_temp(file_path)` | Remove temp file | `bool` |

**JSON Processing Functions**:

| Function | Description | Returns |
| :------- | :---------- | :------ |
| `strip_comments(content)` | Remove `/* */` comments | `str` |
| `normalize_whitespace(content)` | Normalize whitespace | `str` |
| `clean_json_file(input_path, output_path)` | Clean JSON file | `bool` |

**Validation Functions**:

| Function | Description | Returns |
| :------- | :---------- | :------ |
| `validate_and_count_issues(json_file)` | Validate and count issues | `Optional[int]` |

**Data Extraction Functions**:

| Function | Description | Returns |
| :------- | :---------- | :------ |
| `extract_title(issue_json)` | Extract issue title | `str` |
| `extract_body(issue_json)` | Extract issue body | `str` |
| `extract_labels(issue_json)` | Extract labels | `str` |
| `extract_milestone(issue_json)` | Extract milestone | `Optional[str]` |
| `extract_assignees(issue_json)` | Extract assignees | `str` |

**Issue Processing Functions**:

| Function | Description | Returns |
| :------- | :---------- | :------ |
| `process_issue(owner, repo, issue_json)` | Process single issue | `Optional[str]` |
| `process_all_issues(owner, repo, json_file, project_id)` | Process all issues | `int` |

**Template Functions**:

| Function | Description | Returns |
| :------- | :---------- | :------ |
| `generate_issue_json(title, body, labels, milestone, assignees)` | Generate issue JSON | `str` |
| `generate_sample_issues(output_file)` | Generate sample issues | `bool` |

**Validation Functions**:

| Function | Description | Returns |
| :------- | :---------- | :------ |
| `validate_issue(issue_json)` | Validate issue JSON | `bool` |

**Aliases**:
- `process_issues` - Alias for `process_all_issues`

**Example**:

```python
from gh_project_toolkit.lib.issues import (
    clean_json_file,
    validate_and_count_issues,
    extract_title, extract_body,
    process_issue, process_all_issues,
    generate_issue_json
)

# Clean JSON file
success = clean_json_file("issues.json", "issues_cleaned.json")

# Validate and count
count = validate_and_count_issues("issues.json")

# Extract data from issue
issue_json = '{"title": "Bug", "body": "...", "labels": ["bug"]}'
title = extract_title(issue_json)
labels = extract_labels(issue_json)

# Process single issue
issue_url = process_issue("owner", "repo", issue_json)

# Process all issues
count = process_all_issues("owner", "repo", "issues.json", project_id)

# Generate issue JSON
json_str = generate_issue_json(
    "New Feature",
    "Description",
    "enhancement,roadmap"
)
```

#### `duplicates.py`

Duplicate detection and cleanup functions.

**Location**: `src/gh_project_toolkit/lib/duplicates.py`

**Normalization Functions**:

| Function | Description | Returns |
| :------- | :---------- | :------ |
| `normalize_issue_title(title)` | Normalize title by removing bug numbers | `str` |

**GitHub API Helper Functions**:

| Function | Description | Returns |
| :------- | :---------- | :------ |
| `get_existing_milestones(owner, repo)` | Get all milestones | `List[Dict]` |
| `get_existing_labels(owner, repo)` | Get all labels | `List[Dict]` |
| `get_existing_issues(owner, repo)` | Get all issues | `List[Dict]` |

**Existence Check Functions**:

| Function | Description | Returns |
| :------- | :---------- | :------ |
| `milestone_exists(owner, repo, title)` | Check if milestone exists | `bool` |
| `label_exists(owner, repo, name)` | Check if label exists | `bool` |
| `issue_exists(owner, repo, title)` | Check if issue exists | `bool` |

**Cleanup Functions**:

| Function | Description | Returns |
| :------- | :---------- | :------ |
| `delete_milestone(owner, repo, number)` | Delete milestone | `bool` |
| `cleanup_milestones(owner, repo, titles)` | Cleanup duplicate milestones | `int` |
| `cleanup_labels(owner, repo, names)` | Cleanup duplicate labels | `int` |
| `cleanup_issues(owner, repo, titles)` | Cleanup duplicate issues | `int` |
| `cleanup_all(owner, repo, apply, resources)` | Cleanup all resources | `int` |

**Normalization Patterns**:
The `normalize_issue_title` function removes:
- `#123` at start/end
- `123` at start/end
- `bug #123` patterns
- `(123)` at start/end

**Example**:

```python
from gh_project_toolkit.lib.duplicates import (
    normalize_issue_title,
    get_existing_issues,
    cleanup_all,
    cleanup_milestones,
    cleanup_labels,
    cleanup_issues
)

# Normalize title
normalized = normalize_issue_title("#361 Fix bug")
# Returns: "Fix bug"

# Get existing issues
issues = get_existing_issues("owner", "repo")

# Cleanup duplicates (dry-run by default)
removed = cleanup_all("owner", "repo", apply=False, resources="milestones,labels,issues")

# Cleanup milestones only
removed = cleanup_milestones("owner", "repo", ["v1.0", "v1.1"])

# Cleanup with apply
removed = cleanup_all("owner", "repo", apply=True)
```

## Pydantic Models Reference

### Issue Models

#### `Issue`

```python
class Issue(BaseModel):
    title: str              # Issue title (required)
    body: str = ""          # Issue body/description
    labels: List[str] = []  # List of label names
    milestone: Optional[str] = None  # Milestone title or number
    assignees: List[str] = []  # List of assignee usernames
```

#### `IssueCreateRequest`

```python
class IssueCreateRequest(BaseModel):
    title: str                    # Issue title
    body: str = ""                # Issue body
    labels: Optional[List[str]]   # List of labels
    milestone: Optional[int]      # Milestone number
    assignees: Optional[List[str]]  # List of assignees
```

#### `IssueModel`

```python
class IssueModel(BaseModel):
    title: str
    body: str
    labels: List[Dict[str, Any]]      # Label objects from API
    milestone: Optional[Dict[str, Any]]
    assignees: List[Dict[str, Any]]   # User objects from API
```

### Milestone Models

#### `Milestone`

```python
class Milestone(BaseModel):
    title: str                      # Milestone title (required)
    description: str = ""           # Milestone description
    due_on: Optional[str] = None    # Due date in ISO format
    state: str = "open"             # 'open' or 'closed'
```

#### `MilestoneCreateRequest`

```python
class MilestoneCreateRequest(BaseModel):
    title: str                      # Milestone title
    description: str = ""           # Milestone description
    due_on: Optional[str] = None    # Due date in ISO format
```

#### `MilestoneModel`

```python
class MilestoneModel(BaseModel):
    number: int
    title: str
    description: str
    state: str
    due_on: Optional[str] = None
    open_issues: int = 0
    closed_issues: int = 0
```

### Label Models

#### `Label`

```python
class Label(BaseModel):
    name: str                      # Label name (required)
    color: str                     # 6-character hex color code
    description: str = ""          # Label description
```

#### `LabelCreateRequest`

```python
class LabelCreateRequest(BaseModel):
    name: str                      # Label name
    color: str                     # 6-character hex color code
    description: str = ""          # Label description
```

#### `LabelModel`

```python
class LabelModel(BaseModel):
    name: str
    color: str
    description: str
    default: bool = False          # Whether this is a default GitHub label
```

### Project V2 Models

#### `ProjectFieldOption`

```python
class ProjectFieldOption(BaseModel):
    id: str    # The option ID
    name: str  # The option name
```

#### `ProjectField`

```python
class ProjectField(BaseModel):
    id: str                  # The field ID
    name: str                # The field name
    options: List[ProjectFieldOption]  # Field options
```

#### `ProjectV2`

```python
class ProjectV2(BaseModel):
    id: str     # The project ID
    title: str  # Project title
    number: int # Project number
    state: str  # 'OPEN' or 'CLOSED'
```

#### `ProjectItem`

```python
class ProjectItem(BaseModel):
    id: str         # The item ID
    content_id: str # The content node ID (issue or PR)
    project_id: str # The project ID
```

### Response Models

#### `GitHubResponse`

```python
class GitHubResponse(BaseModel):
    data: Optional[Dict[str, Any]]    # Response data
    errors: Optional[List[Dict[str, Any]]]  # List of errors
    message: Optional[str]            # Error message
```

#### `CreateIssueResponse`

```python
class CreateIssueResponse(BaseModel):
    html_url: str  # URL to the created issue
    number: int    # Issue number
    id: str        # Issue node ID
```

#### `CreateMilestoneResponse`

```python
class CreateMilestoneResponse(BaseModel):
    number: int                # Milestone number
    title: str                 # Milestone title
    description: str = ""      # Milestone description
    due_on: Optional[str] = None  # Due date
```

#### `CreateLabelResponse`

```python
class CreateLabelResponse(BaseModel):
    id: int          # Label ID
    node_id: str     # Label node ID
    name: str        # Label name
    color: str       # Label color
    description: str = ""  # Label description
```

## Pydantic Models Configuration Reference

### Pydantic Environment Variables

| Variable | Description | Required | Default |
| :------- | :---------- | :------- | :------ |
| `GITHUB_TOKEN` | Personal access token with repo scope | Yes | - |
| `DRY_RUN` | Set to "true" for dry-run mode | No | `false` |
| `VERBOSE` | Set to "true" for verbose output | No | `false` |
| `TMPDIR` | Temporary directory path | No | `/tmp` |
| `COLUMNS` | Console width for status lines | No | 80 |

### Configuration Files

#### `src/gh_project_toolkit/config/defaults.py`

Contains default configuration values that control toolkit behavior.
- Script metadata (name, version, description)
- GitHub repository configuration
- Path and file configuration
- GitHub API configuration (endpoints)
- Exit codes

#### `src/gh_project_toolkit/config/milestones.py`

Contains milestone and label definitions.
- `MILESTONES`: Dictionary of 7 milestones
- `ALL_LABELS`: List of 37 labels
- `LABEL_COLORS`: Color mapping for labels

### GitHub API Endpoints

| Endpoint | Type | Description |
| :------- | :--- | :---------- |
| `https://api.github.com/graphql` | GraphQL | GitHub GraphQL API |
| `https://api.github.com` | REST | GitHub REST API |

### Exit Codes

| Code | Name | Description |
| :--- | :--- | :---------- |
| 0 | `EXIT_SUCCESS` | Operation completed successfully |
| 1 | `EXIT_ERROR` | General error |
| 2 | `EXIT_MISSING_CMD` | Required command not found |
| 3 | `EXIT_INVALID_CONFIG` | Invalid configuration |
| 4 | `EXIT_API_ERROR` | GitHub API error |

## Testing in Development Section

### Testing Run All Tests

```bash
make test
# or
pytest tests/ -v
```

### Testing Run Tests with Coverage

```bash
make test-coverage
# or
pytest tests/ --cov=src/gh_project_toolkit --cov-report=term-missing
```

### Testing Run Tests for a Specific Module

```bash
pytest tests/test_lib/test_logging.py -v
```

## Development in Development Section

### Development Linting

```bash
# Run ruff linting
make lint

# Run ruff with fixes
make lint-fix
```

### Development Type Checking

```bash
make type-check
# or
mypy src/
```

### Development Formatting

```bash
make format
# or
black src/ tests/
```

### Development Clean Build Artifacts

```bash
make clean
# or
make clean-build
```

## Project Structure in Development Section

```text
gh-tools/gh-project-management-toolkit/
├── src/
│   └── gh_project_toolkit/
│       ├── __init__.py         # Package initialization
│       ├── cli.py              # Command-line interface
│       ├── models.py           # Pydantic models
│       ├── config/
│       │   ├── __init__.py
│       │   ├── defaults.py     # Configuration defaults
│       │   └── milestones.py   # Milestone definitions
│       └── lib/
│           ├── __init__.py
│           ├── logging.py      # Logging utilities
│           ├── validation.py   # Validation functions
│           ├── github_api.py   # GitHub API client
│           ├── labels.py       # Label management
│           ├── projects.py     # Project V2 management
│           ├── issues.py       # Issue processing
│           └── duplicates.py   # Duplicate detection
├── tests/
│   ├── conftest.py             # Pytest fixtures
│   ├── test_config/            # Configuration tests
│   │   ├── test_defaults.py
│   │   └── test_milestones.py
│   └── test_lib/               # Library tests
│       ├── test_logging.py
│       ├── test_validation.py
│       ├── test_labels.py
│       ├── test_issues.py
│       └── test_duplicates.py
├── Makefile                    # Build commands
├── pyproject.toml              # Python project config
├── pyrightconfig.json          # Pyright type checker config
└── README.md                   # This file
```

## License

MIT License - See [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## Support

For support, please open an issue in the GitHub repository or contact the maintainers.
