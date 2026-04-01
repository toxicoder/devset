"""
Pydantic models for GitHub Project Management Toolkit.

This module defines Pydantic data models for core entities used throughout
the toolkit, including validation, serialization, and deserialization.

Example:
    >>> from gh_project_toolkit.models import Issue, Milestone, Label
    >>> issue = Issue(title="Bug", body="Description", labels=["bug"])
    >>> print(issue.title)
    'Bug'
"""

from typing import Any, Dict, List, Optional
from pydantic import BaseModel, Field, field_validator, ConfigDict


# =============================================================================
# Issue Models
# =============================================================================

class Issue(BaseModel):
    """
    Represents a GitHub issue.

    Args:
        title: Issue title (required).
        body: Issue body/description.
        labels: List of label names to apply.
        milestone: Milestone title or number.
        assignees: List of usernames to assign.
        model_config: Pydantic configuration.

    Example:
        >>> issue = Issue(
        ...     title="Fix bug",
        ...     body="Description of the bug",
        ...     labels=["bug", "high-priority"],
        ...     milestone="v1.0",
        ...     assignees=["user1", "user2"]
        ... )
        >>> print(issue.title)
        'Fix bug'
    """

    title: str = Field(..., description="Issue title (required)")
    body: str = Field(default="", description="Issue body/description")
    labels: List[str] = Field(default_factory=list, description="List of label names")
    milestone: Optional[str] = Field(default=None, description="Milestone title or number")
    assignees: List[str] = Field(default_factory=list, description="List of assignee usernames")

    model_config = ConfigDict(extra="allow")


class IssueCreateRequest(BaseModel):
    """
    Request model for creating an issue.

    Args:
        title: Issue title.
        body: Issue body.
        labels: List of labels.
        milestone: Milestone number.
        assignees: List of assignee logins.

    Example:
        >>> req = IssueCreateRequest(
        ...     title="Bug",
        ...     body="Description",
        ...     labels=["bug"],
        ...     milestone=1,
        ...     assignees=["user1"]
        ... )
    """

    title: str = Field(..., description="Issue title")
    body: str = Field(default="", description="Issue body")
    labels: Optional[List[str]] = Field(default=None, description="List of labels")
    milestone: Optional[int] = Field(default=None, description="Milestone number")
    assignees: Optional[List[str]] = Field(default=None, description="List of assignees")


class IssueModel(BaseModel):
    """
    Model for GitHub issue data from API responses.

    Args:
        title: Issue title.
        body: Issue body.
        labels: List of label objects.
        milestone: Milestone object or None.
        assignees: List of user objects.

    Example:
        >>> issue_data = {
        ...     "title": "Bug",
        ...     "body": "Description",
        ...     "labels": [{"name": "bug", "color": "e11d21"}],
        ...     "milestone": None,
        ...     "assignees": []
        ... }
        >>> issue = IssueModel(**issue_data)
    """

    title: str
    body: str
    labels: List[Dict[str, Any]]
    milestone: Optional[Dict[str, Any]]
    assignees: List[Dict[str, Any]]


# =============================================================================
# Milestone Models
# =============================================================================

class Milestone(BaseModel):
    """
    Represents a GitHub milestone.

    Args:
        title: Milestone title (required).
        description: Milestone description.
        due_on: Due date in ISO format (YYYY-MM-DD).
        state: Milestone state ('open' or 'closed').

    Example:
        >>> milestone = Milestone(
        ...     title="v1.0",
        ...     description="Major release",
        ...     due_on="2024-12-31",
        ...     state="open"
        ... )
    """

    title: str = Field(..., description="Milestone title (required)")
    description: str = Field(default="", description="Milestone description")
    due_on: Optional[str] = Field(default=None, description="Due date in ISO format")
    state: str = Field(default="open", description="Milestone state")

    @field_validator("state")
    @classmethod
    def validate_state(cls, v: str) -> str:
        """Validate milestone state is 'open' or 'closed'."""
        if v not in ("open", "closed"):
            raise ValueError("State must be 'open' or 'closed'")
        return v


class MilestoneCreateRequest(BaseModel):
    """
    Request model for creating a milestone.

    Args:
        title: Milestone title.
        description: Milestone description.
        due_on: Due date in ISO format.

    Example:
        >>> req = MilestoneCreateRequest(
        ...     title="v1.0",
        ...     description="Major release",
        ...     due_on="2024-12-31"
        ... )
    """

    title: str = Field(..., description="Milestone title")
    description: str = Field(default="", description="Milestone description")
    due_on: Optional[str] = Field(default=None, description="Due date in ISO format")


class MilestoneModel(BaseModel):
    """
    Model for GitHub milestone data from API responses.

    Args:
        number: Milestone number.
        title: Milestone title.
        description: Milestone description.
        state: Milestone state.
        due_on: Due date.
        open_issues: Number of open issues.
        closed_issues: Number of closed issues.

    Example:
        >>> milestone_data = {
        ...     "number": 1,
        ...     "title": "v1.0",
        ...     "description": "Major release",
        ...     "state": "open",
        ...     "due_on": "2024-12-31T00:00:00Z",
        ...     "open_issues": 5,
        ...     "closed_issues": 10
        ... }
        >>> milestone = MilestoneModel(**milestone_data)
    """

    number: int
    title: str
    description: str
    state: str
    due_on: Optional[str] = None
    open_issues: int = 0
    closed_issues: int = 0


# =============================================================================
# Label Models
# =============================================================================

class Label(BaseModel):
    """
    Represents a GitHub label.

    Args:
        name: Label name (required).
        color: 6-character hex color code.
        description: Label description.

    Example:
        >>> label = Label(
        ...     name="bug",
        ...     color="e11d21",
        ...     description="Something isn't working"
        ... )
    """

    name: str = Field(..., description="Label name (required)")
    color: str = Field(..., description="6-character hex color code")
    description: str = Field(default="", description="Label description")

    @field_validator("color")
    @classmethod
    def validate_color(cls, v: str) -> str:
        """Validate color is a 6-character hex code."""
        if not (len(v) == 6 and all(c in "0123456789abcdefABCDEF" for c in v)):
            raise ValueError("Color must be a 6-character hex code")
        return v


class LabelCreateRequest(BaseModel):
    """
    Request model for creating a label.

    Args:
        name: Label name.
        color: 6-character hex color code.
        description: Label description.

    Example:
        >>> req = LabelCreateRequest(
        ...     name="bug",
        ...     color="e11d21",
        ...     description="Something isn't working"
        ... )
    """

    name: str = Field(..., description="Label name")
    color: str = Field(..., description="6-character hex color code")
    description: str = Field(default="", description="Label description")


class LabelModel(BaseModel):
    """
    Model for GitHub label data from API responses.

    Args:
        name: Label name.
        color: 6-character hex color code.
        description: Label description.
        default: Whether this is a default GitHub label.

    Example:
        >>> label_data = {
        ...     "name": "bug",
        ...     "color": "e11d21",
        ...     "description": "Something isn't working",
        ...     "default": True
        ... }
        >>> label = LabelModel(**label_data)
    """

    name: str
    color: str
    description: str
    default: bool = False


# =============================================================================
# Project V2 Models
# =============================================================================

class ProjectFieldOption(BaseModel):
    """
    Represents an option for a Project V2 single-select field.

    Args:
        id: The option ID.
        name: The option name.

    Example:
        >>> option = ProjectFieldOption(id="O_xxx", name="To Do")
    """

    id: str = Field(..., description="The option ID")
    name: str = Field(..., description="The option name")


class ProjectField(BaseModel):
    """
    Represents a Project V2 field.

    Args:
        id: The field ID.
        name: The field name.
        options: List of options for single-select fields.

    Example:
        >>> field = ProjectField(
        ...     id="F_xxx",
        ...     name="Status",
        ...     options=[ProjectFieldOption(id="O_xxx", name="To Do")]
        ... )
    """

    id: str = Field(..., description="The field ID")
    name: str = Field(..., description="The field name")
    options: List[ProjectFieldOption] = Field(default_factory=list, description="Field options")  # type: ignore[assignment]


class ProjectV2(BaseModel):
    """
    Represents a GitHub Project V2.

    Args:
        id: The project ID.
        title: Project title.
        number: Project number.
        state: Project state ('OPEN' or 'CLOSED').

    Example:
        >>> project = ProjectV2(
        ...     id="PVT_xxx",
        ...     title="My Project",
        ...     number=1,
        ...     state="OPEN"
        ... )
    """

    id: str = Field(..., description="The project ID")
    title: str = Field(..., description="Project title")
    number: int = Field(..., description="Project number")
    state: str = Field(default="OPEN", description="Project state")


class ProjectItem(BaseModel):
    """
    Represents an item in a Project V2.

    Args:
        id: The item ID.
        content_id: The content node ID (issue or PR).
        project_id: The project ID.

    Example:
        >>> item = ProjectItem(id="PVTI_xxx", content_id="I_kwDOBf1x7w", project_id="PVT_xxx")
    """

    id: str = Field(..., description="The item ID")
    content_id: str = Field(..., description="The content node ID")
    project_id: str = Field(..., description="The project ID")


# =============================================================================
# Response Models
# =============================================================================

class GitHubResponse(BaseModel):
    """
    Base model for GitHub API responses.

    Args:
        data: Response data.
        errors: List of errors (if any).
        message: Error message (if any).

    Example:
        >>> response = GitHubResponse(data={"key": "value"})
    """

    data: Optional[Dict[str, Any]] = Field(default=None, description="Response data")
    errors: Optional[List[Dict[str, Any]]] = Field(default=None, description="List of errors")
    message: Optional[str] = Field(default=None, description="Error message")


class CreateIssueResponse(BaseModel):
    """
    Response model for issue creation.

    Args:
        html_url: URL to the created issue.
        number: Issue number.
        id: Issue node ID.

    Example:
        >>> response = CreateIssueResponse(
        ...     html_url="https://github.com/owner/repo/issues/123",
        ...     number=123,
        ...     id="I_kwDOBf1x7w"
        ... )
    """

    html_url: str = Field(..., description="URL to the created issue")
    number: int = Field(..., description="Issue number")
    id: str = Field(..., description="Issue node ID")


class CreateMilestoneResponse(BaseModel):
    """
    Response model for milestone creation.

    Args:
        number: Milestone number.
        title: Milestone title.
        description: Milestone description.
        due_on: Due date.

    Example:
        >>> response = CreateMilestoneResponse(
        ...     number=1,
        ...     title="v1.0",
        ...     description="Major release",
        ...     due_on="2024-12-31T00:00:00Z"
        ... )
    """

    number: int = Field(..., description="Milestone number")
    title: str = Field(..., description="Milestone title")
    description: str = Field(default="", description="Milestone description")
    due_on: Optional[str] = Field(default=None, description="Due date")


class CreateLabelResponse(BaseModel):
    """
    Response model for label creation.

    Args:
        id: Label ID.
        node_id: Label node ID.
        name: Label name.
        color: Label color.
        description: Label description.

    Example:
        >>> response = CreateLabelResponse(
        ...     id=1,
        ...     node_id="MDU6TGFiZWwx",
        ...     name="bug",
        ...     color="e11d21",
        ...     description="Something isn't working"
        ... )
    """

    id: int = Field(..., description="Label ID")
    node_id: str = Field(..., description="Label node ID")
    name: str = Field(..., description="Label name")
    color: str = Field(..., description="Label color")
    description: str = Field(default="", description="Label description")