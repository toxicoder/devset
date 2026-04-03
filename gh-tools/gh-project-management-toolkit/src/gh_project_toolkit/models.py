"""
Pydantic models for GitHub Project Management Toolkit.

This module defines Pydantic data models for core entities used throughout
the toolkit, including validation, serialization, and deserialization.

The models now use Protocol Buffers as the underlying data store for
efficient serialization and API communication, while maintaining Pydantic
for validation and schema definition.

Example:
    >>> from gh_project_toolkit.models import Issue, Milestone, Label
    >>> issue = Issue(title="Bug", body="Description", labels=["bug"])
    >>> print(issue.title)
    'Bug'
"""

from typing import Any, Dict, List, Optional

from pydantic import BaseModel, Field, field_validator

# Protobuf modules imported for Bazel-native builds
# In Bazel builds, these are provided via py_proto_library targets
# For non-Bazel development (e.g., pip install -e .), we fall back gracefully
_protobuf_modules: Optional[Dict[str, Any]] = None


def _get_protobuf_modules() -> Dict[str, Any]:
    """
    Get the protobuf modules, supporting both Bazel and pip builds.
    
    Bazel builds wire the py_proto_library targets to the package,
    making these directly importable from gh_project_toolkit.
    """
    global _protobuf_modules
    if _protobuf_modules is None:
        try:
            from gh_project_toolkit import (
                common_pb2,
                issue_pb2,
                label_pb2,
                milestone_pb2,
                project_pb2  # type: ignore  # Bazel generates these
                ,
                response_pb2,
            )
            _protobuf_modules = {
                "common": common_pb2,
                "issue": issue_pb2,
                "milestone": milestone_pb2,
                "label": label_pb2,
                "project": project_pb2,
                "response": response_pb2,
            }
        except ImportError:
            _protobuf_modules = {}
    return _protobuf_modules


def _get_pb2_module(name: str) -> Any:
    """Get a protobuf module by name."""
    modules = _get_protobuf_modules()
    return modules.get(name)


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

    Example:
        >>> issue = Issue(
        ...     title="Fix bug",
        ...     body="Description of the bug",
        ...     labels=["bug", "high-priority"],
        ...     milestone="v1.0",
        ...     assignees=["user1", "user2"]
        ... )
        >>> print(issue.title)
        'Bug'
    """

    title: str = Field(..., description="Issue title (required)")
    body: str = Field(default="", description="Issue body/description")
    labels: List[str] = Field(default_factory=list,
                              description="List of label names")
    milestone: Optional[str] = Field(
        default=None, description="Milestone title or number")
    assignees: List[str] = Field(
        default_factory=list, description="List of assignee usernames")

    def to_proto(self) -> Any:
        """Convert to protobuf message."""
        modules = _get_protobuf_modules()
        if "issue" not in modules:
            raise ImportError(
                "protobuf modules not found. Run protoc to generate Python code.")
        proto = modules["issue"].Issue()
        proto.title = self.title
        proto.body = self.body
        proto.labels.extend(self.labels)
        if self.milestone is not None:
            proto.milestone = self.milestone
        proto.assignees.extend(self.assignees)
        return proto

    @classmethod
    def from_proto(cls, proto: Any) -> "Issue":
        """Create Issue from protobuf message."""
        return cls(
            title=proto.title,
            body=proto.body,
            labels=list(proto.labels),
            milestone=proto.milestone if proto.milestone else None,
            assignees=list(proto.assignees),
        )


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
    labels: Optional[List[str]] = Field(
        default=None, description="List of labels")
    milestone: Optional[int] = Field(
        default=None, description="Milestone number")
    assignees: Optional[List[str]] = Field(
        default=None, description="List of assignees")

    def to_proto(self) -> Any:
        """Convert to protobuf message."""
        modules = _get_protobuf_modules()
        if "issue" not in modules:
            raise ImportError(
                "protobuf modules not found. Run protoc to generate Python code.")
        proto = modules["issue"].IssueCreateRequest()
        proto.title = self.title
        proto.body = self.body
        if self.labels is not None:
            proto.labels.extend(self.labels)
        if self.milestone is not None:
            proto.milestone = self.milestone
        if self.assignees is not None:
            proto.assignees.extend(self.assignees)
        return proto


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

    def to_proto(self) -> Any:
        """Convert to protobuf message."""
        modules = _get_protobuf_modules()
        if "issue" not in modules:
            raise ImportError(
                "protobuf modules not found. Run protoc to generate Python code.")
        proto = modules["issue"].IssueModel()
        proto.title = self.title
        proto.body = self.body
        for label in self.labels:
            proto.labels.add().CopyFrom(label)
        if self.milestone:
            proto.milestone.CopyFrom(self.milestone)
        for assignee in self.assignees:
            proto.assignees.add().CopyFrom(assignee)
        return proto


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
    due_on: Optional[str] = Field(
        default=None, description="Due date in ISO format")
    state: str = Field(default="open", description="Milestone state")

    @field_validator("state")
    @classmethod
    def validate_state(cls, v: str) -> str:
        """Validate milestone state is 'open' or 'closed'."""
        if v not in ("open", "closed"):
            raise ValueError("State must be 'open' or 'closed'")
        return v

    def to_proto(self) -> Any:
        """Convert to protobuf message."""
        modules = _get_protobuf_modules()
        if "milestone" not in modules:
            raise ImportError(
                "protobuf modules not found. Run protoc to generate Python code.")
        proto = modules["milestone"].Milestone()
        proto.title = self.title
        proto.description = self.description
        if self.due_on is not None:
            proto.due_on = self.due_on
        proto.state = self.state
        return proto

    @classmethod
    def from_proto(cls, proto: Any) -> "Milestone":
        """Create Milestone from protobuf message."""
        return cls(
            title=proto.title,
            description=proto.description,
            due_on=proto.due_on if proto.due_on else None,
            state=proto.state,
        )


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
    due_on: Optional[str] = Field(
        default=None, description="Due date in ISO format")

    def to_proto(self) -> Any:
        """Convert to protobuf message."""
        modules = _get_protobuf_modules()
        if "milestone" not in modules:
            raise ImportError(
                "protobuf modules not found. Run protoc to generate Python code.")
        proto = modules["milestone"].MilestoneCreateRequest()
        proto.title = self.title
        proto.description = self.description
        if self.due_on is not None:
            proto.due_on = self.due_on
        return proto


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

    def to_proto(self) -> Any:
        """Convert to protobuf message."""
        modules = _get_protobuf_modules()
        if "milestone" not in modules:
            raise ImportError(
                "protobuf modules not found. Run protoc to generate Python code.")
        proto = modules["milestone"].MilestoneModel()
        proto.number = self.number
        proto.title = self.title
        proto.description = self.description
        proto.state = self.state
        if self.due_on is not None:
            proto.due_on = self.due_on
        proto.open_issues = self.open_issues
        proto.closed_issues = self.closed_issues
        return proto

    @classmethod
    def from_proto(cls, proto: Any) -> "MilestoneModel":
        """Create MilestoneModel from protobuf message."""
        return cls(
            number=proto.number,
            title=proto.title,
            description=proto.description,
            state=proto.state,
            due_on=proto.due_on if proto.due_on else None,
            open_issues=proto.open_issues,
            closed_issues=proto.closed_issues,
        )


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

    def to_proto(self) -> Any:
        """Convert to protobuf message."""
        modules = _get_protobuf_modules()
        if "label" not in modules:
            raise ImportError(
                "protobuf modules not found. Run protoc to generate Python code.")
        proto = modules["label"].Label()
        proto.name = self.name
        proto.color = self.color
        proto.description = self.description
        return proto

    @classmethod
    def from_proto(cls, proto: Any) -> "Label":
        """Create Label from protobuf message."""
        return cls(
            name=proto.name,
            color=proto.color,
            description=proto.description,
        )


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

    def to_proto(self) -> Any:
        """Convert to protobuf message."""
        modules = _get_protobuf_modules()
        if "label" not in modules:
            raise ImportError(
                "protobuf modules not found. Run protoc to generate Python code.")
        proto = modules["label"].LabelCreateRequest()
        proto.name = self.name
        proto.color = self.color
        proto.description = self.description
        return proto


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

    def to_proto(self) -> Any:
        """Convert to protobuf message."""
        modules = _get_protobuf_modules()
        if "label" not in modules:
            raise ImportError(
                "protobuf modules not found. Run protoc to generate Python code.")
        proto = modules["label"].LabelModel()
        proto.name = self.name
        proto.color = self.color
        proto.description = self.description
        proto.default = self.default
        return proto

    @classmethod
    def from_proto(cls, proto: Any) -> "LabelModel":
        """Create LabelModel from protobuf message."""
        return cls(
            name=proto.name,
            color=proto.color,
            description=proto.description,
            default=proto.default,
        )


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

    def to_proto(self) -> Any:
        """Convert to protobuf message."""
        modules = _get_protobuf_modules()
        if "common" not in modules:
            raise ImportError(
                "protobuf modules not found. Run protoc to generate Python code.")
        proto = modules["common"].ProjectFieldOption()
        proto.id = self.id
        proto.name = self.name
        return proto

    @classmethod
    def from_proto(cls, proto: Any) -> "ProjectFieldOption":
        """Create ProjectFieldOption from protobuf message."""
        return cls(
            id=proto.id,
            name=proto.name,
        )


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
    options: List["ProjectFieldOption"] = Field(
        default_factory=list, description="Field options")

    def to_proto(self) -> Any:
        """Convert to protobuf message."""
        modules = _get_protobuf_modules()
        if "project" not in modules:
            raise ImportError(
                "protobuf modules not found. Run protoc to generate Python code.")
        proto = modules["project"].ProjectField()
        proto.id = self.id
        proto.name = self.name
        for option in self.options:
            proto_option = proto.options.add()
            proto_option.id = option.id
            proto_option.name = option.name
        return proto

    @classmethod
    def from_proto(cls, proto: Any) -> "ProjectField":
        """Create ProjectField from protobuf message."""
        return cls(
            id=proto.id,
            name=proto.name,
            options=[ProjectFieldOption(id=opt.id, name=opt.name)
                     for opt in proto.options],
        )


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

    def to_proto(self) -> Any:
        """Convert to protobuf message."""
        modules = _get_protobuf_modules()
        if "project" not in modules:
            raise ImportError(
                "protobuf modules not found. Run protoc to generate Python code.")
        proto = modules["project"].ProjectV2()
        proto.id = self.id
        proto.title = self.title
        proto.number = self.number
        proto.state = self.state
        return proto

    @classmethod
    def from_proto(cls, proto: Any) -> "ProjectV2":
        """Create ProjectV2 from protobuf message."""
        return cls(
            id=proto.id,
            title=proto.title,
            number=proto.number,
            state=proto.state,
        )


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

    def to_proto(self) -> Any:
        """Convert to protobuf message."""
        modules = _get_protobuf_modules()
        if "project" not in modules:
            raise ImportError(
                "protobuf modules not found. Run protoc to generate Python code.")
        proto = modules["project"].ProjectItem()
        proto.id = self.id
        proto.content_id = self.content_id
        proto.project_id = self.project_id
        return proto

    @classmethod
    def from_proto(cls, proto: Any) -> "ProjectItem":
        """Create ProjectItem from protobuf message."""
        return cls(
            id=proto.id,
            content_id=proto.content_id,
            project_id=proto.project_id,
        )


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

    data: Optional[Dict[str, Any]] = Field(
        default=None, description="Response data")
    errors: Optional[List[Dict[str, Any]]] = Field(
        default=None, description="List of errors")
    message: Optional[str] = Field(default=None, description="Error message")

    def to_proto(self) -> Any:
        """Convert to protobuf message."""
        modules = _get_protobuf_modules()
        if "response" not in modules:
            raise ImportError(
                "protobuf modules not found. Run protoc to generate Python code.")
        proto = modules["response"].GitHubResponse()
        if self.data:
            proto.data.CopyFrom(self.data)
        if self.errors:
            for error in self.errors:
                proto.errors.add().CopyFrom(error)
        if self.message:
            proto.message = self.message
        return proto


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

    def to_proto(self) -> Any:
        """Convert to protobuf message."""
        modules = _get_protobuf_modules()
        if "response" not in modules:
            raise ImportError(
                "protobuf modules not found. Run protoc to generate Python code.")
        proto = modules["response"].CreateIssueResponse()
        proto.html_url = self.html_url
        proto.number = self.number
        proto.id = self.id
        return proto

    @classmethod
    def from_proto(cls, proto: Any) -> "CreateIssueResponse":
        """Create CreateIssueResponse from protobuf message."""
        return cls(
            html_url=proto.html_url,
            number=proto.number,
            id=proto.id,
        )


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

    def to_proto(self) -> Any:
        """Convert to protobuf message."""
        modules = _get_protobuf_modules()
        if "response" not in modules:
            raise ImportError(
                "protobuf modules not found. Run protoc to generate Python code.")
        proto = modules["response"].CreateMilestoneResponse()
        proto.number = self.number
        proto.title = self.title
        proto.description = self.description
        if self.due_on is not None:
            proto.due_on = self.due_on
        return proto

    @classmethod
    def from_proto(cls, proto: Any) -> "CreateMilestoneResponse":
        """Create CreateMilestoneResponse from protobuf message."""
        return cls(
            number=proto.number,
            title=proto.title,
            description=proto.description,
            due_on=proto.due_on if proto.due_on else None,
        )


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

    def to_proto(self) -> Any:
        """Convert to protobuf message."""
        modules = _get_protobuf_modules()
        if "response" not in modules:
            raise ImportError(
                "protobuf modules not found. Run protoc to generate Python code.")
        proto = modules["response"].CreateLabelResponse()
        proto.id = self.id
        proto.node_id = self.node_id
        proto.name = self.name
        proto.color = self.color
        proto.description = self.description
        return proto

    @classmethod
    def from_proto(cls, proto: Any) -> "CreateLabelResponse":
        """Create CreateLabelResponse from protobuf message."""
        return cls(
            id=proto.id,
            node_id=proto.node_id,
            name=proto.name,
            color=proto.color,
            description=proto.description,
        )
