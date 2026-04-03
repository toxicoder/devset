"""
Protocol Buffer conversion helpers for GitHub Project Management Toolkit.

This module provides conversion functions between Pydantic models and
Protocol Buffer messages, allowing backward compatibility while migrating
to protobuf-based data models.

Example:
    >>> from gh_project_toolkit.protobuf_helpers import issue_to_proto, issue_from_proto
    >>> from gh_project_toolkit.models import Issue
    >>> 
    >>> # Convert Pydantic to protobuf
    >>> issue = Issue(title="Bug", body="Description", labels=["bug"])
    >>> proto = issue_to_proto(issue)
    >>> 
    >>> # Convert protobuf back to Pydantic
    >>> issue2 = issue_from_proto(proto)
"""

from typing import Any, Dict, List, Optional

# Import protobuf-generated classes
# These will be imported dynamically at runtime
# to avoid circular dependencies during development

# Type aliases for clarity
from gh_project_toolkit.models import (
    Issue, IssueCreateRequest, IssueModel,
    Milestone, MilestoneCreateRequest, MilestoneModel,
    Label, LabelCreateRequest, LabelModel,
    ProjectFieldOption, ProjectField, ProjectV2, ProjectItem,
    CreateIssueResponse, CreateMilestoneResponse, CreateLabelResponse,
)


def _import_protobuf_modules() -> Dict[str, Any]:
    """Dynamically import protobuf modules."""
    try:
        from gh_project_toolkit.protobuf import (
            common_pb2,
            issue_pb2,
            milestone_pb2,
            label_pb2,
            project_pb2,
            response_pb2,
        )
        return {
            "common": common_pb2,
            "issue": issue_pb2,
            "milestone": milestone_pb2,
            "label": label_pb2,
            "project": project_pb2,
            "response": response_pb2,
        }
    except ImportError:
        return {}


# Cache for protobuf modules
_protobuf_modules: Optional[Dict[str, Any]] = None


def _get_protobuf_modules() -> Dict[str, Any]:
    """Get or initialize protobuf modules cache."""
    global _protobuf_modules
    if _protobuf_modules is None:
        _protobuf_modules = _import_protobuf_modules()
    return _protobuf_modules


# =============================================================================
# Issue Conversions
# =============================================================================


def issue_to_proto(issue: Issue) -> Any:
    """Convert Issue Pydantic model to protobuf message.
    
    Args:
        issue: Pydantic Issue model.
        
    Returns:
        protobuf issue_pb2.Issue message.
    """
    modules = _get_protobuf_modules()
    if "issue" not in modules:
        raise ImportError("protobuf modules not found. Run protoc to generate Python code.")
    
    proto = modules["issue"].Issue()
    proto.title = issue.title
    proto.body = issue.body
    proto.labels.extend(issue.labels)
    if issue.milestone is not None:
        proto.milestone = issue.milestone
    proto.assignees.extend(issue.assignees)
    return proto


def issue_from_proto(proto: Any) -> Issue:
    """Convert protobuf message to Issue Pydantic model.
    
    Args:
        proto: protobuf issue_pb2.Issue message.
        
    Returns:
        Pydantic Issue model.
    """
    return Issue(
        title=proto.title,
        body=proto.body,
        labels=list(proto.labels),
        milestone=proto.milestone if proto.milestone else None,
        assignees=list(proto.assignees),
    )


def issue_create_request_to_proto(request: IssueCreateRequest) -> Any:
    """Convert IssueCreateRequest Pydantic model to protobuf message.
    
    Args:
        request: Pydantic IssueCreateRequest model.
        
    Returns:
        protobuf issue_pb2.IssueCreateRequest message.
    """
    modules = _get_protobuf_modules()
    if "issue" not in modules:
        raise ImportError("protobuf modules not found. Run protoc to generate Python code.")
    
    proto = modules["issue"].IssueCreateRequest()
    proto.title = request.title
    proto.body = request.body
    if request.labels is not None:
        proto.labels.extend(request.labels)
    if request.milestone is not None:
        proto.milestone = request.milestone
    if request.assignees is not None:
        proto.assignees.extend(request.assignees)
    return proto


def issue_model_to_proto(model: IssueModel) -> Any:
    """Convert IssueModel Pydantic model to protobuf message.
    
    Args:
        model: Pydantic IssueModel (raw API response format).
        
    Returns:
        protobuf issue_pb2.IssueModel message.
    """
    modules = _get_protobuf_modules()
    if "issue" not in modules:
        raise ImportError("protobuf modules not found. Run protoc to generate Python code.")
    
    proto = modules["issue"].IssueModel()
    proto.title = model.title
    proto.body = model.body
    proto.labels.extend(model.labels)
    if model.milestone is not None:
        proto.milestone.CopyFrom(model.milestone)
    proto.assignees.extend(model.assignees)
    return proto


# =============================================================================
# Milestone Conversions
# =============================================================================


def milestone_to_proto(milestone: Milestone) -> Any:
    """Convert Milestone Pydantic model to protobuf message.
    
    Args:
        milestone: Pydantic Milestone model.
        
    Returns:
        protobuf milestone_pb2.Milestone message.
    """
    modules = _get_protobuf_modules()
    if "milestone" not in modules:
        raise ImportError("protobuf modules not found. Run protoc to generate Python code.")
    
    proto = modules["milestone"].Milestone()
    proto.title = milestone.title
    proto.description = milestone.description
    if milestone.due_on is not None:
        proto.due_on = milestone.due_on
    proto.state = milestone.state
    return proto


def milestone_from_proto(proto: Any) -> Milestone:
    """Convert protobuf message to Milestone Pydantic model.
    
    Args:
        proto: protobuf milestone_pb2.Milestone message.
        
    Returns:
        Pydantic Milestone model.
    """
    return Milestone(
        title=proto.title,
        description=proto.description,
        due_on=proto.due_on if proto.due_on else None,
        state=proto.state,
    )


def milestone_create_request_to_proto(request: MilestoneCreateRequest) -> Any:
    """Convert MilestoneCreateRequest Pydantic model to protobuf message.
    
    Args:
        request: Pydantic MilestoneCreateRequest model.
        
    Returns:
        protobuf milestone_pb2.MilestoneCreateRequest message.
    """
    modules = _get_protobuf_modules()
    if "milestone" not in modules:
        raise ImportError("protobuf modules not found. Run protoc to generate Python code.")
    
    proto = modules["milestone"].MilestoneCreateRequest()
    proto.title = request.title
    proto.description = request.description
    if request.due_on is not None:
        proto.due_on = request.due_on
    return proto


def milestone_model_to_proto(model: MilestoneModel) -> Any:
    """Convert MilestoneModel Pydantic model to protobuf message.
    
    Args:
        model: Pydantic MilestoneModel (raw API response format).
        
    Returns:
        protobuf milestone_pb2.MilestoneModel message.
    """
    modules = _get_protobuf_modules()
    if "milestone" not in modules:
        raise ImportError("protobuf modules not found. Run protoc to generate Python code.")
    
    proto = modules["milestone"].MilestoneModel()
    proto.number = model.number
    proto.title = model.title
    proto.description = model.description
    proto.state = model.state
    if model.due_on is not None:
        proto.due_on = model.due_on
    proto.open_issues = model.open_issues
    proto.closed_issues = model.closed_issues
    return proto


def milestone_model_from_proto(proto: Any) -> MilestoneModel:
    """Convert protobuf message to MilestoneModel Pydantic model.
    
    Args:
        proto: protobuf milestone_pb2.MilestoneModel message.
        
    Returns:
        Pydantic MilestoneModel model.
    """
    return MilestoneModel(
        number=proto.number,
        title=proto.title,
        description=proto.description,
        state=proto.state,
        due_on=proto.due_on if proto.due_on else None,
        open_issues=proto.open_issues,
        closed_issues=proto.closed_issues,
    )


# =============================================================================
# Label Conversions
# =============================================================================


def label_to_proto(label: Label) -> Any:
    """Convert Label Pydantic model to protobuf message.
    
    Args:
        label: Pydantic Label model.
        
    Returns:
        protobuf label_pb2.Label message.
    """
    modules = _get_protobuf_modules()
    if "label" not in modules:
        raise ImportError("protobuf modules not found. Run protoc to generate Python code.")
    
    proto = modules["label"].Label()
    proto.name = label.name
    proto.color = label.color
    proto.description = label.description
    return proto


def label_from_proto(proto: Any) -> Label:
    """Convert protobuf message to Label Pydantic model.
    
    Args:
        proto: protobuf label_pb2.Label message.
        
    Returns:
        Pydantic Label model.
    """
    return Label(
        name=proto.name,
        color=proto.color,
        description=proto.description,
    )


def label_create_request_to_proto(request: LabelCreateRequest) -> Any:
    """Convert LabelCreateRequest Pydantic model to protobuf message.
    
    Args:
        request: Pydantic LabelCreateRequest model.
        
    Returns:
        protobuf label_pb2.LabelCreateRequest message.
    """
    modules = _get_protobuf_modules()
    if "label" not in modules:
        raise ImportError("protobuf modules not found. Run protoc to generate Python code.")
    
    proto = modules["label"].LabelCreateRequest()
    proto.name = request.name
    proto.color = request.color
    proto.description = request.description
    return proto


def label_model_to_proto(model: LabelModel) -> Any:
    """Convert LabelModel Pydantic model to protobuf message.
    
    Args:
        model: Pydantic LabelModel (raw API response format).
        
    Returns:
        protobuf label_pb2.LabelModel message.
    """
    modules = _get_protobuf_modules()
    if "label" not in modules:
        raise ImportError("protobuf modules not found. Run protoc to generate Python code.")
    
    proto = modules["label"].LabelModel()
    proto.name = model.name
    proto.color = model.color
    proto.description = model.description
    proto.default = model.default
    return proto


def label_model_from_proto(proto: Any) -> LabelModel:
    """Convert protobuf message to LabelModel Pydantic model.
    
    Args:
        proto: protobuf label_pb2.LabelModel message.
        
    Returns:
        Pydantic LabelModel model.
    """
    return LabelModel(
        name=proto.name,
        color=proto.color,
        description=proto.description,
        default=proto.default,
    )


# =============================================================================
# Project V2 Conversions
# =============================================================================


def project_field_option_to_proto(option: ProjectFieldOption) -> Any:
    """Convert ProjectFieldOption Pydantic model to protobuf message.
    
    Args:
        option: Pydantic ProjectFieldOption model.
        
    Returns:
        protobuf common_pb2.ProjectFieldOption message.
    """
    modules = _get_protobuf_modules()
    if "common" not in modules:
        raise ImportError("protobuf modules not found. Run protoc to generate Python code.")
    
    proto = modules["common"].ProjectFieldOption()
    proto.id = option.id
    proto.name = option.name
    return proto


def project_field_option_from_proto(proto: Any) -> ProjectFieldOption:
    """Convert protobuf message to ProjectFieldOption Pydantic model.
    
    Args:
        proto: protobuf common_pb2.ProjectFieldOption message.
        
    Returns:
        Pydantic ProjectFieldOption model.
    """
    return ProjectFieldOption(
        id=proto.id,
        name=proto.name,
    )


def project_field_to_proto(field: ProjectField) -> Any:
    """Convert ProjectField Pydantic model to protobuf message.
    
    Args:
        field: Pydantic ProjectField model.
        
    Returns:
        protobuf project_pb2.ProjectField message.
    """
    modules = _get_protobuf_modules()
    if "project" not in modules:
        raise ImportError("protobuf modules not found. Run protoc to generate Python code.")
    
    proto = modules["project"].ProjectField()
    proto.id = field.id
    proto.name = field.name
    for option in field.options:
        proto_option = proto.options.add()
        proto_option.id = option.id
        proto_option.name = option.name
    return proto


def project_field_from_proto(proto: Any) -> ProjectField:
    """Convert protobuf message to ProjectField Pydantic model.
    
    Args:
        proto: protobuf project_pb2.ProjectField message.
        
    Returns:
        Pydantic ProjectField model.
    """
    return ProjectField(
        id=proto.id,
        name=proto.name,
        options=[ProjectFieldOption(id=opt.id, name=opt.name) for opt in proto.options],
    )


def project_v2_to_proto(project: ProjectV2) -> Any:
    """Convert ProjectV2 Pydantic model to protobuf message.
    
    Args:
        project: Pydantic ProjectV2 model.
        
    Returns:
        protobuf project_pb2.ProjectV2 message.
    """
    modules = _get_protobuf_modules()
    if "project" not in modules:
        raise ImportError("protobuf modules not found. Run protoc to generate Python code.")
    
    proto = modules["project"].ProjectV2()
    proto.id = project.id
    proto.title = project.title
    proto.number = project.number
    proto.state = project.state
    return proto


def project_v2_from_proto(proto: Any) -> ProjectV2:
    """Convert protobuf message to ProjectV2 Pydantic model.
    
    Args:
        proto: protobuf project_pb2.ProjectV2 message.
        
    Returns:
        Pydantic ProjectV2 model.
    """
    return ProjectV2(
        id=proto.id,
        title=proto.title,
        number=proto.number,
        state=proto.state,
    )


def project_item_to_proto(item: ProjectItem) -> Any:
    """Convert ProjectItem Pydantic model to protobuf message.
    
    Args:
        item: Pydantic ProjectItem model.
        
    Returns:
        protobuf project_pb2.ProjectItem message.
    """
    modules = _get_protobuf_modules()
    if "project" not in modules:
        raise ImportError("protobuf modules not found. Run protoc to generate Python code.")
    
    proto = modules["project"].ProjectItem()
    proto.id = item.id
    proto.content_id = item.content_id
    proto.project_id = item.project_id
    return proto


def project_item_from_proto(proto: Any) -> ProjectItem:
    """Convert protobuf message to ProjectItem Pydantic model.
    
    Args:
        proto: protobuf project_pb2.ProjectItem message.
        
    Returns:
        Pydantic ProjectItem model.
    """
    return ProjectItem(
        id=proto.id,
        content_id=proto.content_id,
        project_id=proto.project_id,
    )


# =============================================================================
# Response Conversions
# =============================================================================


def create_issue_response_to_proto(response: CreateIssueResponse) -> Any:
    """Convert CreateIssueResponse Pydantic model to protobuf message.
    
    Args:
        response: Pydantic CreateIssueResponse model.
        
    Returns:
        protobuf response_pb2.CreateIssueResponse message.
    """
    modules = _get_protobuf_modules()
    if "response" not in modules:
        raise ImportError("protobuf modules not found. Run protoc to generate Python code.")
    
    proto = modules["response"].CreateIssueResponse()
    proto.html_url = response.html_url
    proto.number = response.number
    proto.id = response.id
    return proto


def create_issue_response_from_proto(proto: Any) -> CreateIssueResponse:
    """Convert protobuf message to CreateIssueResponse Pydantic model.
    
    Args:
        proto: protobuf response_pb2.CreateIssueResponse message.
        
    Returns:
        Pydantic CreateIssueResponse model.
    """
    return CreateIssueResponse(
        html_url=proto.html_url,
        number=proto.number,
        id=proto.id,
    )


def create_milestone_response_to_proto(response: CreateMilestoneResponse) -> Any:
    """Convert CreateMilestoneResponse Pydantic model to protobuf message.
    
    Args:
        response: Pydantic CreateMilestoneResponse model.
        
    Returns:
        protobuf response_pb2.CreateMilestoneResponse message.
    """
    modules = _get_protobuf_modules()
    if "response" not in modules:
        raise ImportError("protobuf modules not found. Run protoc to generate Python code.")
    
    proto = modules["response"].CreateMilestoneResponse()
    proto.number = response.number
    proto.title = response.title
    proto.description = response.description
    if response.due_on is not None:
        proto.due_on = response.due_on
    return proto


def create_milestone_response_from_proto(proto: Any) -> CreateMilestoneResponse:
    """Convert protobuf message to CreateMilestoneResponse Pydantic model.
    
    Args:
        proto: protobuf response_pb2.CreateMilestoneResponse message.
        
    Returns:
        Pydantic CreateMilestoneResponse model.
    """
    return CreateMilestoneResponse(
        number=proto.number,
        title=proto.title,
        description=proto.description,
        due_on=proto.due_on if proto.due_on else None,
    )


def create_label_response_to_proto(response: CreateLabelResponse) -> Any:
    """Convert CreateLabelResponse Pydantic model to protobuf message.
    
    Args:
        response: Pydantic CreateLabelResponse model.
        
    Returns:
        protobuf response_pb2.CreateLabelResponse message.
    """
    modules = _get_protobuf_modules()
    if "response" not in modules:
        raise ImportError("protobuf modules not found. Run protoc to generate Python code.")
    
    proto = modules["response"].CreateLabelResponse()
    proto.id = response.id
    proto.node_id = response.node_id
    proto.name = response.name
    proto.color = response.color
    proto.description = response.description
    return proto


def create_label_response_from_proto(proto: Any) -> CreateLabelResponse:
    """Convert protobuf message to CreateLabelResponse Pydantic model.
    
    Args:
        proto: protobuf response_pb2.CreateLabelResponse message.
        
    Returns:
        Pydantic CreateLabelResponse model.
    """
    return CreateLabelResponse(
        id=proto.id,
        node_id=proto.node_id,
        name=proto.name,
        color=proto.color,
        description=proto.description,
    )


# =============================================================================
# List Conversions
# =============================================================================


def list_issues_to_proto(issues: List[Issue]) -> List[Any]:
    """Convert list of Issue Pydantic models to protobuf messages.
    
    Args:
        issues: List of Pydantic Issue models.
        
    Returns:
        List of protobuf issue_pb2.Issue messages.
    """
    return [issue_to_proto(issue) for issue in issues]


def list_milestones_to_proto(milestones: List[Milestone]) -> List[Any]:
    """Convert list of Milestone Pydantic models to protobuf messages.
    
    Args:
        milestones: List of Pydantic Milestone models.
        
    Returns:
        List of protobuf milestone_pb2.Milestone messages.
    """
    return [milestone_to_proto(milestone) for milestone in milestones]


def list_labels_to_proto(labels: List[Label]) -> List[Any]:
    """Convert list of Label Pydantic models to protobuf messages.
    
    Args:
        labels: List of Pydantic Label models.
        
    Returns:
        List of protobuf label_pb2.Label messages.
    """
    return [label_to_proto(label) for label in labels]


def list_project_fields_to_proto(fields: List[ProjectField]) -> List[Any]:
    """Convert list of ProjectField Pydantic models to protobuf messages.
    
    Args:
        fields: List of Pydantic ProjectField models.
        
    Returns:
        List of protobuf project_pb2.ProjectField messages.
    """
    return [project_field_to_proto(field) for field in fields]