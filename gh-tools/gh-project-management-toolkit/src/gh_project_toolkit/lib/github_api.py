"""
GitHub API helper functions for GraphQL and REST endpoints.

This module provides reusable functions for interacting with GitHub's
GraphQL and REST APIs. It includes helpers for common operations like
getting owner IDs, creating milestones, labels, and managing Projects V2.

Example:
    >>> from gh_project_toolkit.lib.github_api import get_owner_id, create_milestone
    >>> owner_id = get_owner_id("toxicoder", "RestoClaw")
    >>> milestone_num = create_milestone("owner", "repo", "v1.0", "Major release")
"""

import os
import time
from typing import Dict, List, Any, Optional

import requests  # type: ignore

# =============================================================================
# Configuration
# =============================================================================
# Define fallback values at module level before try block (avoids mypy "already defined" errors)
DRY_RUN = False
VERBOSE = False
GITHUB_GRAPHQL_ENDPOINT = "https://api.github.com/graphql"
GITHUB_REST_API_BASE = "https://api.github.com"

def log_verbose(message: str, *args: Any, **kwargs: Any) -> None:
    """Verbose logging fallback."""
    pass

def log_error(message: str, *args: Any, **kwargs: Any) -> None:
    """Error logging fallback."""
    pass

def log_dry_run(message: str, *args: Any, **kwargs: Any) -> None:
    """Dry-run logging fallback."""
    pass

def log_warning(message: str, *args: Any, **kwargs: Any) -> None:
    """Warning logging fallback."""
    pass

# Try to import from the actual package
try:
    from gh_project_toolkit.config.defaults import (
        DRY_RUN as _dry_run,
        VERBOSE as _verbose,
    )
    from gh_project_toolkit.lib.logging import (
        log_verbose as _log_verbose,
        log_error as _log_error,
        log_dry_run as _log_dry_run,
        log_warning as _log_warning,
    )
    # Use imported values - assign to lowercase variables to avoid mypy constant redefinition errors
    _dry_run_imported = _dry_run
    _verbose_imported = _verbose
    log_verbose = _log_verbose
    log_error = _log_error
    log_dry_run = _log_dry_run
    log_warning = _log_warning
except ImportError:
    # Use fallback values defined above
    _dry_run_imported = False
    _verbose_imported = False
    pass


# =============================================================================
# Repository Information
# =============================================================================
def get_owner_id(owner: str, repo: str) -> Optional[str]:
    """
    Get the current repository owner ID (user or organization).

    Args:
        owner: Repository owner name.
        repo: Repository name.

    Returns:
        The owner's node ID (starts with U_ for users, O_ for orgs), or None on failure.

    Example:
        >>> owner_id = get_owner_id("toxicoder", "RestoClaw")
        >>> print(owner_id)
        'U_kgDOBf1x7w'
    """
    if DRY_RUN:
        log_dry_run(f"Would get owner ID for {owner}/{repo}")
        return "U_kgDOBf1x7w"  # Return a dummy ID for dry-run

    query = f"""{{
  repository(owner:"{owner}", name:"{repo}") {{
    owner {{
      ... on User {{ id }}
      ... on Organization {{ id }}
    }}
  }}
}}"""

    try:
        response = requests.post(
            GITHUB_GRAPHQL_ENDPOINT,
            json={"query": query},
            headers={"Authorization": f"token {os.environ.get('GITHUB_TOKEN', '')}"},
            timeout=30,
        )
        response.raise_for_status()
        result = response.json()  # type: ignore[assignment]

        if "data" in result and "repository" in result["data"]:
            owner_data = result["data"]["repository"]["owner"]
            owner_id = owner_data.get("id")
            if owner_id:
                log_verbose(f"Got owner ID: {owner_id}")
                return owner_id

        log_error(f"Failed to get owner ID for {owner}/{repo}")
        return None

    except requests.RequestException as e:
        log_error(f"GitHub API request failed: {e}")
        return None


def get_repo_id(owner: str, repo: str) -> Optional[str]:
    """
    Get the repository node ID.

    Args:
        owner: Repository owner name.
        repo: Repository name.

    Returns:
        The repository's node ID, or None on failure.

    Example:
        >>> repo_id = get_repo_id("toxicoder", "RestoClaw")
        >>> print(repo_id)
        'R_kgDOBf1x7w'
    """
    if DRY_RUN:
        log_dry_run(f"Would get repository ID for {owner}/{repo}")
        return "R_kgDOBf1x7w"  # Return a dummy ID for dry-run

    query = f"""{{
  repository(owner:"{owner}", name:"{repo}") {{
    id
  }}
}}"""

    try:
        response = requests.post(
            GITHUB_GRAPHQL_ENDPOINT,
            json={"query": query},
            headers={"Authorization": f"token {os.environ.get('GITHUB_TOKEN', '')}"},
            timeout=30,
        )
        response.raise_for_status()
        result = response.json()  # type: ignore[assignment]

        if "data" in result and "repository" in result["data"]:
            repo_id = result["data"]["repository"]["id"]
            if repo_id:
                log_verbose(f"Got repository ID: {repo_id}")
                return repo_id

        log_error(f"Failed to get repository ID for {owner}/{repo}")
        return None

    except requests.RequestException as e:
        log_error(f"GitHub API request failed: {e}")
        return None


# =============================================================================
# Milestone Management
# =============================================================================
def create_milestone(owner: str, repo: str, title: str, description: str, due_date: Optional[str] = None) -> Optional[str]:
    """
    Create a milestone in the repository.

    Args:
        owner: Repository owner.
        repo: Repository name.
        title: Milestone title.
        description: Milestone description.
        due_date: Milestone due date (optional, format: YYYY-MM-DD).

    Returns:
        The created milestone number or None on failure.

    Example:
        >>> milestone_num = create_milestone("owner", "repo", "v1.0", "Major release")
        >>> print(milestone_num)
        '1'
    """
    if DRY_RUN:
        log_dry_run(f"Would create milestone: {title}")
        return "1"  # Return a dummy number for dry-run

    url = f"{GITHUB_REST_API_BASE}/repos/{owner}/{repo}/milestones"
    data = {"title": title, "description": description}
    if due_date:
        data["due_on"] = due_date

    try:
        response = requests.post(
            url,
            json=data,
            headers={"Authorization": f"token {os.environ.get('GITHUB_TOKEN', '')}"},
            timeout=30,
        )
        response.raise_for_status()
        result = response.json()  # type: ignore[assignment]

        if "number" in result:
            log_verbose(f"Created milestone: {title} (#{result['number']})")
            return str(result["number"])

        log_error(f"Failed to create milestone '{title}'")
        return None

    except requests.RequestException as e:
        log_error(f"Failed to create milestone '{title}': {e}")
        return None


def get_all_milestones(owner: str, repo: str) -> List[Dict[str, Any]]:
    """
    Get all milestones from the repository.

    Args:
        owner: Repository owner.
        repo: Repository name.

    Returns:
        List of milestone dictionaries (raw API response).

    Example:
        >>> milestones = get_all_milestones("owner", "repo")
        >>> for m in milestones:
        ...     print(f"{m['title']}: {m['description']}")
    """
    url = f"{GITHUB_REST_API_BASE}/repos/{owner}/{repo}/milestones"

    try:
        response = requests.get(
            url,
            headers={"Authorization": f"token {os.environ.get('GITHUB_TOKEN', '')}"},
            timeout=30,
        )
        response.raise_for_status()
        return response.json()  # type: ignore[return-value]

    except requests.RequestException as e:
        log_error(f"Failed to get milestones: {e}")
        return []


def get_all_milestones_proto(owner: str, repo: str) -> List[Any]:
    """
    Get all milestones from the repository as protobuf objects.

    Args:
        owner: Repository owner.
        repo: Repository name.

    Returns:
        List of protobuf Milestone objects.

    Example:
        >>> from gh_project_toolkit.lib.github_api import get_all_milestones_proto
        >>> milestones = get_all_milestones_proto("owner", "repo")
        >>> for m in milestones:
        ...     print(f"{m.title}: {m.description}")
    """
    from gh_project_toolkit.models import MilestoneModel
    
    raw_data = get_all_milestones(owner, repo)
    return [MilestoneModel(**m).to_proto() for m in raw_data]


# =============================================================================
# Label Management
# =============================================================================
def create_label(owner: str, repo: str, name: str, color: str, description: str = "") -> bool:
    """
    Create a label in the repository.

    Args:
        owner: Repository owner.
        repo: Repository name.
        name: Label name.
        color: Label color (6-character hex, without #).
        description: Label description.

    Returns:
        True if successful, False otherwise.

    Example:
        >>> created = create_label("owner", "repo", "bug", "e11d21", "Something isn't working")
        >>> assert created
    """
    if DRY_RUN:
        log_dry_run(f"Would create label: {name} (color: {color})")
        return True

    url = f"{GITHUB_REST_API_BASE}/repos/{owner}/{repo}/labels"

    try:
        response = requests.post(
            url,
            json={"name": name, "color": color, "description": description},
            headers={"Authorization": f"token {os.environ.get('GITHUB_TOKEN', '')}"},
            timeout=30,
        )

        if response.status_code in (200, 201):
            log_verbose(f"Created label: {name}")
            return True
        elif response.status_code == 422:  # Label already exists
            log_verbose(f"Label already exists: {name}")
            return True
        else:
            log_error(f"Failed to create label '{name}': {response.text}")
            return False

    except requests.RequestException as e:
        log_error(f"Failed to create label '{name}': {e}")
        return False


def delete_label(owner: str, repo: str, name: str) -> bool:
    """
    Delete a label from the repository.

    Args:
        owner: Repository owner.
        repo: Repository name.
        name: Label name.

    Returns:
        True if successful (or label didn't exist), False otherwise.

    Example:
        >>> deleted = delete_label("owner", "repo", "deprecated-label")
        >>> assert deleted
    """
    if DRY_RUN:
        log_dry_run(f"Would delete label: {name}")
        return True

    url = f"{GITHUB_REST_API_BASE}/repos/{owner}/{repo}/labels/{name}"

    try:
        response = requests.delete(
            url,
            headers={"Authorization": f"token {os.environ.get('GITHUB_TOKEN', '')}"},
            timeout=30,
        )
        if response.status_code in (204, 404):
            log_verbose(f"Deleted label: {name}")
            return True
        else:
            log_error(f"Failed to delete label '{name}': {response.text}")
            return False

    except requests.RequestException as e:
        log_error(f"Failed to delete label '{name}': {e}")
        return False


def get_all_labels(owner: str, repo: str) -> List[Dict[str, Any]]:
    """
    Get all labels from the repository.

    Args:
        owner: Repository owner.
        repo: Repository name.

    Returns:
        List of label objects.

    Example:
        >>> labels = get_all_labels("owner", "repo")
        >>> for label in labels:
        ...     print(f"{label['name']}: {label['color']}")
    """
    url = f"{GITHUB_REST_API_BASE}/repos/{owner}/{repo}/labels"

    try:
        response = requests.get(
            url,
            headers={"Authorization": f"token {os.environ.get('GITHUB_TOKEN', '')}"},
            timeout=30,
        )
        response.raise_for_status()
        return response.json()  # type: ignore[return-value]

    except requests.RequestException as e:
        log_error(f"Failed to get labels: {e}")
        return []


# =============================================================================
# Project V2 Management
# =============================================================================
def project_exists(owner_id: str, title: str) -> Optional[str]:
    """
    Check if a Project V2 exists with the given name.

    Args:
        owner_id: Owner ID (user or organization).
        title: Project name.

    Returns:
        Project ID if found, None if not found.

    Example:
        >>> project_id = project_exists("U_kgDOBf1x7w", "My Project")
        >>> print(project_id)
        'PVT_xxx'
    """
    if DRY_RUN:
        log_dry_run(f"Would check if Project V2 exists: {title}")
        return "PVT_xxx"

    query = f"""
    query($ownerId:ID!, $title:String!) {{
      node(id: $ownerId) {{
        ... on User {{ projectsV2(first: 10, query: $title) {{ nodes {{ id title }} }} }}
        ... on Organization {{ projectsV2(first: 10, query: $title) {{ nodes {{ id title }} }} }}
      }}
    }}
    """

    try:
        response = requests.post(
            GITHUB_GRAPHQL_ENDPOINT,
            json={"query": query, "variables": {"ownerId": owner_id, "title": title}},
            headers={"Authorization": f"token {os.environ.get('GITHUB_TOKEN', '')}"},
            timeout=30,
        )
        response.raise_for_status()
        result = response.json()  # type: ignore[assignment]

        if "data" in result:
            node = result["data"]["node"]
            projects = node.get("projectsV2", {}).get("nodes", [])
            for project in projects:
                if project.get("title") == title:
                    log_verbose(f"Found existing Project V2: {title} (ID: {project['id']})")
                    return project["id"]

        return None

    except requests.RequestException as e:
        log_error(f"Failed to check Project V2: {e}")
        return None


def create_project(owner_id: str, title: str) -> Optional[str]:
    """
    Create a new Project V2 board.

    Args:
        owner_id: Owner ID (user or organization).
        title: Project name.

    Returns:
        The new project's ID, or None on failure.

    Example:
        >>> project_id = create_project("U_kgDOBf1x7w", "My Project")
        >>> print(project_id)
        'PVT_xxx'
    """
    if DRY_RUN:
        log_dry_run(f"Would create Project V2: {title}")
        return "PVT_xxx"  # Return a dummy ID for dry-run

    query = f"""
    mutation($title:String!, $ownerId:ID!) {{
      createProjectV2(input: {{title: $title, ownerId: $ownerId}}) {{
        projectV2 {{ id }}
      }}
    }}
    """

    try:
        response = requests.post(
            GITHUB_GRAPHQL_ENDPOINT,
            json={"query": query, "variables": {"title": title, "ownerId": owner_id}},
            headers={"Authorization": f"token {os.environ.get('GITHUB_TOKEN', '')}"},
            timeout=30,
        )
        response.raise_for_status()
        result = response.json()  # type: ignore[assignment]

        if "data" in result:
            project_id = result["data"]["createProjectV2"]["projectV2"]["id"]
            log_verbose(f"Created Project V2: {title} (ID: {project_id})")
            return project_id

        log_error(f"Failed to create Project V2: {title}")
        return None

    except requests.RequestException as e:
        log_error(f"Failed to create Project V2: {e}")
        return None


def get_project_fields(project_id: str) -> Dict[str, Any]:
    """
    Get Project V2 fields and their options.

    Args:
        project_id: Project ID.

    Returns:
        JSON response with field data.

    Example:
        >>> fields = get_project_fields("PVT_xxx")
        >>> print(fields)
    """
    query = f"""
    {{
      node(id:"{project_id}") {{
        ... on ProjectV2 {{
          fields(first:20) {{
            nodes {{
              ... on ProjectV2SingleSelectField {{
                id
                name
                options {{
                  id
                  name
                }}
              }}
              ... on ProjectV2Field {{
                id
                name
              }}
            }}
          }}
        }}
      }}
    }}
    """

    try:
        response = requests.post(
            GITHUB_GRAPHQL_ENDPOINT,
            json={"query": query},
            headers={"Authorization": f"token {os.environ.get('GITHUB_TOKEN', '')}"},
            timeout=30,
        )
        response.raise_for_status()
        return response.json()  # type: ignore[return-value]

    except requests.RequestException as e:
        log_error(f"Failed to get project fields: {e}")
        return {}


# =============================================================================
# Issue Management
# =============================================================================
def create_issue(owner: str, repo: str, title: str, body: str, labels: str = "", milestone: str = "", assignees: str = "") -> Optional[str]:
    """
    Create a GitHub issue.

    Args:
        owner: Repository owner.
        repo: Repository name.
        title: Issue title.
        body: Issue body.
        labels: Labels (comma-separated).
        milestone: Milestone number.
        assignees: Assignees (comma-separated).

    Returns:
        Issue URL or None on failure.

    Example:
        >>> issue_url = create_issue("owner", "repo", "Bug title", "Bug description", "bug,high-priority", "", "")
        >>> print(issue_url)
        'https://github.com/owner/repo/issues/123'
    """
    if DRY_RUN:
        log_dry_run(f"Would create issue: {title}")
        return f"https://github.com/{owner}/{repo}/issues/9999"  # Return a dummy URL

    url = f"{GITHUB_REST_API_BASE}/repos/{owner}/{repo}/issues"

    data: dict[str, Any] = {"title": title, "body": body}
    if labels:
        data["labels"] = labels.split(",")  # type: ignore[assignment]
    if milestone:
        data["milestone"] = milestone
    if assignees:
        data["assignees"] = assignees.split(",")  # type: ignore[assignment]

    try:
        response = requests.post(
            url,
            json=data,
            headers={"Authorization": f"token {os.environ.get('GITHUB_TOKEN', '')}"},
            timeout=30,
        )
        response.raise_for_status()
        result = response.json()  # type: ignore[assignment]

        if "html_url" in result:
            log_verbose(f"Created issue: {title} ({result['html_url']})")
            return result["html_url"]  # type: ignore[return-value]

        log_error(f"Failed to create issue '{title}'")
        return None

    except requests.RequestException as e:
        log_error(f"Failed to create issue '{title}': {e}")
        return None


def get_issue_node_id(owner: str, repo: str, number: int) -> Optional[str]:
    """
    Get issue node ID.

    Args:
        owner: Repository owner.
        repo: Repository name.
        number: Issue number.

    Returns:
        Issue node ID or None on failure.

    Example:
        >>> node_id = get_issue_node_id("owner", "repo", "123")
        >>> print(node_id)
        'I_kwDOBf1x7w'
    """
    if DRY_RUN:
        log_dry_run(f"Would get node ID for issue #{number}")
        return "I_kwDOBf1x7w"

    # Use GraphQL to get the node ID
    query = f"""{{
  repository(owner:"{owner}", name:"{repo}") {{
    issue(number: {number}) {{
      id
    }}
  }}
}}"""

    try:
        response = requests.post(
            GITHUB_GRAPHQL_ENDPOINT,
            json={"query": query},
            headers={"Authorization": f"token {os.environ.get('GITHUB_TOKEN', '')}"},
            timeout=30,
        )
        response.raise_for_status()
        result = response.json()  # type: ignore[assignment]

        if "data" in result:
            node_id = result["data"]["repository"]["issue"]["id"]
            if node_id:
                log_verbose(f"Got issue node ID: {node_id}")
                return node_id

        return None

    except requests.RequestException as e:
        log_error(f"Failed to get issue node ID: {e}")
        return None


# =============================================================================
# Project V2 Item Management
# =============================================================================
def add_issue_to_project(project_id: str, content_id: str) -> Optional[str]:
    """
    Add an issue to a Project V2.

    Args:
        project_id: Project ID.
        content_id: Issue node ID.

    Returns:
        Item ID or None on failure.

    Example:
        >>> item_id = add_issue_to_project("PVT_xxx", "I_kwDOBf1x7w")
        >>> print(item_id)
        'PVTI_xxx'
    """
    if DRY_RUN:
        log_dry_run("Would add issue to Project V2")
        return "PVTI_xxx"  # Return a dummy item ID for dry-run

    query = """
    mutation($p:ID!, $c:ID!) {
      addProjectV2ItemById(input:{projectId:$p, contentId:$c}) { item { id } }
    }
    """

    try:
        response = requests.post(
            GITHUB_GRAPHQL_ENDPOINT,
            json={"query": query, "variables": {"p": project_id, "c": content_id}},
            headers={"Authorization": f"token {os.environ.get('GITHUB_TOKEN', '')}"},
            timeout=30,
        )
        response.raise_for_status()
        result = response.json()  # type: ignore[assignment]

        if "data" in result:
            item_id = result["data"]["addProjectV2ItemById"]["item"]["id"]
            log_verbose(f"Added item to Project V2: {item_id}")
            return item_id

        log_error("Failed to add item to Project V2")
        return None

    except requests.RequestException as e:
        log_error(f"Failed to add item to Project V2: {e}")
        return None


def update_project_field(project_id: str, item_id: str, field_id: str, option_id: str) -> bool:
    """
    Update a Project V2 item field value.

    Args:
        project_id: Project ID.
        item_id: Item ID.
        field_id: Field ID.
        option_id: Option ID (for single-select fields).

    Returns:
        True if successful, False otherwise.

    Example:
        >>> updated = update_project_field("PVT_xxx", "PVTI_xxx", "F_xxx", "O_xxx")
        >>> assert updated
    """
    if DRY_RUN:
        log_dry_run("Would update Project V2 item field")
        return True

    query = """
    mutation($p:ID!, $i:ID!, $f:ID!, $o:ID!) {
      updateProjectV2ItemFieldValue(input:{
        projectId:$p, itemId:$i, fieldId:$f,
        value:{singleSelectOptionId:$o}
      }) { clientMutationId }
    }
    """

    try:
        response = requests.post(
            GITHUB_GRAPHQL_ENDPOINT,
            json={"query": query, "variables": {"p": project_id, "i": item_id, "f": field_id, "o": option_id}},
            headers={"Authorization": f"token {os.environ.get('GITHUB_TOKEN', '')}"},
            timeout=30,
        )
        response.raise_for_status()
        log_verbose("Updated Project V2 item field")
        return True

    except requests.RequestException as e:
        log_error(f"Failed to update Project V2 item field: {e}")
        return False


# =============================================================================
# Helper Functions
# =============================================================================
def get_todo_option(fields_json: Dict[str, Any]) -> Optional[str]:
    """
    Get the ID of the "To Do" option from a Project V2 Status field.

    Args:
        fields_json: Project fields JSON.

    Returns:
        Option ID or None if not found.

    Example:
        >>> todo_id = get_todo_option(fields_json)
        >>> print(todo_id)
        'O_xxx_todo'
    """
    if not fields_json or "data" not in fields_json:
        return None

    node = fields_json["data"].get("node", {})
    fields = node.get("fields", {}).get("nodes", [])

    for field in fields:
        if field.get("name") == "Status":
            options = field.get("options", [])
            for option in options:
                name = option.get("name", "").lower()
                if name in ("to do", "todo", "todo"):
                    return option.get("id")

    return None


def get_status_field_id(fields_json: Dict[str, Any]) -> Optional[str]:
    """
    Get the ID of the "Status" field from Project V2 fields.

    Args:
        fields_json: Project fields JSON.

    Returns:
        Field ID or None if not found.

    Example:
        >>> status_id = get_status_field_id(fields_json)
        >>> print(status_id)
        'PVTSSF_xxx'
    """
    if not fields_json or "data" not in fields_json:
        return None

    node = fields_json["data"].get("node", {})
    fields = node.get("fields", {}).get("nodes", [])

    for field in fields:
        if field.get("name") == "Status":
            return field.get("id")

    return None


# =============================================================================
# Issue Management Helpers (for duplicates module)
# =============================================================================
def get_all_issues(owner: str, repo: str) -> List[Dict[str, Any]]:
    """
    Get all issues from the repository.

    Args:
        owner: Repository owner.
        repo: Repository name.

    Returns:
        List of issue objects.

    Example:
        >>> issues = get_all_issues("owner", "repo")
        >>> for issue in issues:
        ...     print(f"{issue['title']}: {issue['number']}")
    """
    url = f"{GITHUB_REST_API_BASE}/repos/{owner}/{repo}/issues"

    try:
        response = requests.get(
            url,
            headers={"Authorization": f"token {os.environ.get('GITHUB_TOKEN', '')}"},
            timeout=30,
        )
        response.raise_for_status()
        return response.json()  # type: ignore[return-value]

    except requests.RequestException as e:
        log_error(f"Failed to get issues: {e}")
        return []


def delete_issue(owner: str, repo: str, number: int) -> bool:
    """
    Delete an issue from the repository.

    Args:
        owner: Repository owner.
        repo: Repository name.
        number: Issue number.

    Returns:
        True if successful (or issue didn't exist), False otherwise.

    Example:
        >>> deleted = delete_issue("owner", "repo", "123")
        >>> assert deleted
    """
    if DRY_RUN:
        log_dry_run(f"Would delete issue #{number}")
        return True

    url = f"{GITHUB_REST_API_BASE}/repos/{owner}/{repo}/issues/{number}"

    try:
        response = requests.delete(
            url,
            headers={"Authorization": f"token {os.environ.get('GITHUB_TOKEN', '')}"},
            timeout=30,
        )
        if response.status_code in (204, 404):
            log_verbose(f"Deleted issue: #{number}")
            return True
        else:
            log_error(f"Failed to delete issue #{number}: {response.text}")
            return False

    except requests.RequestException as e:
        log_error(f"Failed to delete issue #{number}: {e}")
        return False


# =============================================================================
# Issue Existence Checkers (for duplicates module)
# =============================================================================
def milestone_exists(owner: str, repo: str, title: str) -> bool:
    """
    Check if a milestone with the given title already exists.

    Args:
        owner: Repository owner.
        repo: Repository name.
        title: Milestone title.

    Returns:
        True if milestone exists, False otherwise.

    Example:
        >>> if milestone_exists("owner", "repo", "v1.0"):
        ...     print("Milestone already exists")
    """
    milestones = get_all_milestones(owner, repo)
    for milestone in milestones:
        if milestone.get("title") == title:
            return True
    return False


def label_exists(owner: str, repo: str, name: str) -> bool:
    """
    Check if a label with the given name already exists.

    Args:
        owner: Repository owner.
        repo: Repository name.
        name: Label name.

    Returns:
        True if label exists, False otherwise.

    Example:
        >>> if label_exists("owner", "repo", "bug"):
        ...     print("Label already exists")
    """
    labels = get_all_labels(owner, repo)
    for label in labels:
        if label.get("name") == name:
            return True
    return False


def issue_exists(owner: str, repo: str, title: str) -> bool:
    """
    Check if an issue with the given title already exists.

    Args:
        owner: Repository owner.
        repo: Repository name.
        title: Issue title.

    Returns:
        True if issue exists, False otherwise.

    Example:
        >>> if issue_exists("owner", "repo", "Fix bug"):
        ...     print("Issue already exists")
    """
    issues = get_all_issues(owner, repo)
    for issue in issues:
        if issue.get("title") == title:
            return True
    return False


def get_label_color(label: str) -> str:
    """
    Get label color for a specific label.

    This function is a wrapper for the config's get_label_color function.
    It returns the color code for the given label name.

    Args:
        label: Label name.

    Returns:
        6-character hex color code.

    Example:
        >>> color = get_label_color("priority:high")
        >>> assert color == "e11d21"
    """
    try:
        from gh_project_toolkit.config.milestones import get_label_color as get_label_color_impl
        return get_label_color_impl(label)
    except ImportError:
        return "ededed"


# =============================================================================
# Utility Functions
# =============================================================================
def wait_rate_limit(seconds: int = 1) -> None:
    """
    Wait with a progress indicator (for rate limiting).

    Args:
        seconds: Seconds to wait (default: 1).

    Example:
        >>> wait_rate_limit(2)
    """
    if VERBOSE:
        log_verbose(f"Waiting {seconds} second(s) for rate limit...")

    time.sleep(seconds)