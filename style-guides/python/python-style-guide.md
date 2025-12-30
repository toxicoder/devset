# Python Style Guide

This document outlines the coding standards and best practices for Python development within this project. Adhering to these guidelines ensures code consistency, readability, and maintainability.

## Table of Contents

1. [General Principles](#general-principles)
2. [Code Layout](#code-layout)
3. [Naming Conventions](#naming-conventions)
4. [Documentation](#documentation)
5. [Type Hinting](#type-hinting)
6. [Imports](#imports)
7. [Error Handling](#error-handling)
8. [Testing](#testing)
9. [Modern Python Features](#modern-python-features)
10. [Recommended Tools](#recommended-tools)

## General Principles

- **PEP 8**: Adhere to [PEP 8](https://peps.python.org/pep-0008/) for style guide rules unless otherwise specified.
- **Readability**: Code is read much more often than it is written. Prioritize clarity over cleverness.
- **Explicit is better than implicit**: Avoid magic behavior.
- **Simplicity**: Simple is better than complex.

## Code Layout

- **Indentation**: Use 4 spaces per indentation level. Do not use tabs.
- **Line Length**: Limit all lines to a maximum of 88 characters (consistent with Black formatter).
- **Blank Lines**:
    - Top-level functions and classes: 2 blank lines.
    - Method definitions inside a class: 1 blank line.
    - Use blank lines sparingly inside functions to separate logical sections.
- **Whitespace**: Avoid extraneous whitespace.
    - Immediately inside parentheses, brackets, or braces.
    - Immediately before a comma, semicolon, or colon.

## Naming Conventions

- **Variables/Functions**: `snake_case`
- **Classes/Exceptions**: `CapWords` (PascalCase)
- **Constants**: `UPPER_CASE_WITH_UNDERSCORES`
- **Protected Members**: `_single_leading_underscore`
- **Private Members**: `__double_leading_underscore` (use sparingly)
- **Modules/Packages**: `snake_case` (short, all lowercase prefered)

## Documentation

- **Docstrings**: All modules, classes, and functions (public) must have a docstring.
- **Format**: Use the [Google Style](https://google.github.io/styleguide/pyguide.html#38-comments-and-docstrings) for docstrings.

```python
def fetch_data(url: str, timeout: int = 10) -> dict:
    """Fetches data from a given URL.

    Args:
        url: The URL to fetch data from.
        timeout: The timeout in seconds. Defaults to 10.

    Returns:
        A dictionary containing the JSON response.

    Raises:
        ValueError: If the URL is invalid.
        TimeoutError: If the request times out.
    """
    pass
```

## Type Hinting

- Use type hints for all function arguments and return values.
- Use `typing` module or built-in types (Python 3.9+).
- Use `Optional` or `X | None` for values that can be None.
- Use `Any` only when absolutely necessary and explain why in a comment.

```python
from typing import List, Dict, Optional

def process_items(items: List[str]) -> Dict[str, int]:
    ...
```

## Imports

- **Order**:
    1. Standard library imports.
    2. Related third-party imports.
    3. Local application/library specific imports.
- **Style**:
    - Absolute imports are recommended over relative imports.
    - Avoid wildcard imports (`from module import *`).

```python
# Good
import os
import sys

import requests

from myproject.models import User
```

## Error Handling

- Use specific exceptions, not broad `Exception`.
- Use `try/except` blocks to handle expected errors.
- Keep `try` blocks as small as possible.

```python
# Bad
try:
    process_data()
except Exception:
    pass

# Good
try:
    process_data()
except ValueError as e:
    logger.error(f"Invalid data: {e}")
```

## Testing

- All new code should include unit tests.
- Use `pytest` as the testing framework.
- Test names should be descriptive (e.g., `test_function_returns_true_on_valid_input`).
- Aim for high test coverage, but prioritize testing critical paths and edge cases.

## Modern Python Features

- **f-strings**: Use f-strings for string interpolation.
- **Dataclasses**: Use `@dataclass` for classes that primarily store data.
- **Walrus Operator**: Use `:=` sparingly and only when it improves readability.

```python
# f-strings
name = "World"
print(f"Hello, {name}!")

# dataclasses
from dataclasses import dataclass

@dataclass
class Point:
    x: float
    y: float
```

## Recommended Tools

- **Formatter**: `black` or `ruff` (configured to mimic black).
- **Linter**: `ruff` or `pylint`.
- **Type Checker**: `mypy`.
- **Sort Imports**: `isort` or `ruff`.
