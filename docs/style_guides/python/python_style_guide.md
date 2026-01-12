# Python Style Guide

This document outlines the coding standards and best practices for Python development within this project. Adhering to these guidelines ensures code consistency, readability, and maintainability across our growing codebase. We aim for "Pythonic" code that is idiomatic, clean, and robust.

## Table of Contents

1. [General Principles](#general-principles)
2. [Code Layout & Formatting](#code-layout--formatting)
3. [Naming Conventions](#naming-conventions)
4. [Documentation and Docstrings](#documentation-and-docstrings)
5. [Type Hinting & Static Analysis](#type-hinting--static-analysis)
6. [Imports](#imports)
7. [Functions & Arguments](#functions--arguments)
8. [Data Structures & Algorithms](#data-structures--algorithms)
9. [Classes & Object Oriented Programming](#classes--object-oriented-programming)
10. [Error Handling & Exceptions](#error-handling--exceptions)
11. [Testing](#testing)
12. [Concurrency & Parallelism](#concurrency--parallelism)
13. [Modern Python Features](#modern-python-features)
14. [Tooling & Enforcement](#tooling--enforcement)

## General Principles

*   **PEP 8 is the Baseline:** We follow [PEP 8](https://peps.python.org/pep-0008/) strictly, unless otherwise specified here.
*   **Explicit is Better than Implicit:** Avoid "magic" code that is hard to debug. Code should explain itself.
*   **Readability Counts:** Code is read 10x more often than it is written. Optimize for the reader, not the writer.
*   **Fail Fast:** Errors should be raised immediately at the source, not propagated silently.
*   **Zen of Python:** when in doubt, run `import this` in your REPL.

## Code Layout & Formatting

We use automated formatters ([Black](https://github.com/psf/black) or [Ruff](https://github.com/astral-sh/ruff)) to enforce layout, so manual formatting debates are minimized.

### Line Length
*   **Limit:** 88 characters. This is the default for Black and strikes a good balance between readability and screen real estate.
*   **Exceptions:** URLs or long string literals that cannot be easily broken.

### Indentation
*   Use **4 spaces** per indentation level.
*   Never use tabs.
*   **Continuation Lines:** Indent to align with the opening delimiter, or use a hanging indent.

### Whitespace
*   **Surround binary operators** with a single space on either side: `x = y + 1`.
*   **No space** around keyword argument assignments: `def func(key=value):`.
*   **Blank Lines:**
    *   2 blank lines before top-level class or function definitions.
    *   1 blank line before method definitions inside a class.
    *   Use blank lines sparingly within functions to separate logical blocks.

**Bad:**
```python
def  my_function ( x,y ):
    return x+y
```

**Good:**
```python
def my_function(x, y):
    return x + y
```

### Quotes
*   Use **double quotes** `"` by default (enforced by Black).
*   Use single quotes `'` only if the string contains double quotes, to avoid backslash escaping.
*   Use triple double quotes `"""` for docstrings.

## Naming Conventions

Naming is one of the most important aspects of code readability. Names should be descriptive and unambiguous.

| Type | Convention | Examples |
| :--- | :--- | :--- |
| **Modules** | `snake_case` | `my_module.py`, `utils.py` |
| **Packages** | `snake_case` | `my_package/` |
| **Classes** | `CapWords` (PascalCase) | `UserAccount`, `HttpRequest` |
| **Exceptions** | `CapWords` (Ends with `Error`) | `ValidationError`, `DatabaseConnectionError` |
| **Functions** | `snake_case` | `calculate_total`, `fetch_user` |
| **Variables** | `snake_case` | `user_id`, `is_active` |
| **Constants** | `UPPER_CASE` | `MAX_RETRIES`, `DEFAULT_TIMEOUT` |
| **Protected** | `_leading_underscore` | `_internal_helper` |
| **Private** | `__double_underscore` | `__very_private_method` (Use sparingly) |

### Specific Naming Rules
*   **Avoid single-letter names** except for counters (`i`, `j`) or standard math variables (`x`, `y`).
*   **Boolean variables** should ask a question: `is_enabled`, `has_permission`, `can_edit`.
*   **Getters/Setters:** Python prefers direct attribute access or `@property`. Avoid `get_value()` unless it involves expensive computation.

## Documentation and Docstrings

Every public module, class, and function must have a docstring. We use the **Google Style** docstring format.

### Module Docstrings
Place at the very top of the file.

```python
"""
User Authentication Module.

This module handles user login, registration, and token management.
It interfaces with the PostgreSQL database and the Redis cache.
"""
```

### Function/Method Docstrings
Must include `Args`, `Returns`, and `Raises` (if applicable).

**Bad:**
```python
def connect(host, port):
    # Connects to the server
    pass
```

**Good:**
```python
def connect_to_server(host: str, port: int = 8080) -> bool:
    """Establishes a TCP connection to the remote server.

    Args:
        host: The hostname or IP address of the server.
        port: The port number. Defaults to 8080.

    Returns:
        True if the connection was successful, False otherwise.

    Raises:
        ConnectionTimeoutError: If the server does not respond within 5s.
        ValueError: If the port number is invalid.
    """
    pass
```

### Comments
*   **Explain Why, Not What:** The code shows *what* is happening. The comment should explain *why* you chose this approach.
*   **Keep Updated:** Incorrect comments are worse than no comments. Delete them if they are stale.
*   **TODOs:** format as `# TODO(username): Description`.

## Type Hinting & Static Analysis

We are a **strictly typed** codebase. Type hints are mandatory for all new code. They serve as documentation and allow `mypy` to catch bugs before runtime.

### Rules
*   Annotate **all arguments** and **return values**.
*   Use built-in types (`list`, `dict`, `tuple`, `set`) in Python 3.9+ instead of `typing.List`.
*   Use `|` for unions in Python 3.10+ instead of `Union`.
*   Use `Optional[T]` or `T | None` for values that can be None.
*   **Avoid `Any`**: It disables the type checker. If you must use it, add a `# type: ignore` comment with an explanation.

**Bad:**
```python
def process(data):
    return data['id']
```

**Good:**
```python
from typing import Any

def process(data: dict[str, Any]) -> int:
    return int(data['id'])
```

### Generics
Use TypeVars for generic functions.

```python
from typing import TypeVar, Sequence

T = TypeVar("T")

def first_element(items: Sequence[T]) -> T | None:
    return items[0] if items else None
```

## Imports

Imports should be clean and organized.

### Grouping Order
1.  **Standard Library** (`os`, `sys`, `typing`)
2.  **Third-Party Libraries** (`requests`, `pandas`)
3.  **Local Application Imports** (`from myapp.models import User`)

### Style
*   **Absolute imports** are preferred: `from myapp.core import utils`.
*   **Avoid wildcard imports** (`from module import *`). They pollute the namespace and make code hard to read.
*   **Multiline imports:** Use parentheses.

```python
from myapp.services import (
    UserService,
    EmailService,
    PaymentGateway,
)
```

## Functions & Arguments

*   **Small Functions:** Functions should do **one thing**. If a function is longer than 50 lines, consider breaking it up.
*   **Limit Arguments:** Aim for 4 or fewer arguments. If you need more, consider using a Dataclass or a configuration object.
*   **Keyword Arguments:** Use keyword-only arguments for boolean flags or optional params to avoid confusion.

```python
# Hard to read: what does True mean?
create_user("john", "doe", True, False)

# Better
def create_user(first: str, last: str, *, is_admin: bool = False, send_email: bool = True):
    ...

# Usage
create_user("john", "doe", is_admin=True)
```

## Data Structures & Algorithms

*   **List Comprehensions:** Use them for simple mapping/filtering. Use standard loops for complex logic.
*   **Generators:** Use `yield` for processing large streams of data to save memory.
*   **Sets:** Use `set` for O(1) membership testing (`if x in my_set`).
*   **Dictionaries:** Use `.get()` to avoid `KeyError` if a default is acceptable.

**Bad:**
```python
result = []
for x in range(10):
    if x % 2 == 0:
        result.append(x * x)
```

**Good:**
```python
result = [x * x for x in range(10) if x % 2 == 0]
```

## Classes & Object Oriented Programming

*   **Composition over Inheritance:** Inheriting from deep class hierarchies creates tight coupling. Prefer composing objects with smaller responsibilities.
*   **Dataclasses:** Use `@dataclass` for classes that primarily store data. It automates `__init__`, `__repr__`, and `__eq__`.
*   **Mixins:** Use Mixins to share behavior across unrelated classes.
*   **Abstract Base Classes:** Use `abc.ABC` to define interfaces.

```python
from dataclasses import dataclass

@dataclass(frozen=True)
class Point:
    x: float
    y: float

    def distance_to(self, other: "Point") -> float:
        ...
```

## Error Handling & Exceptions

*   **Be Specific:** Never catch raw `Exception`. Catch only what you expect (e.g., `ValueError`, `NetworkError`).
*   **Raise Custom Exceptions:** Define domain-specific exceptions for your application logic.
*   **Cleanup:** Use `try...finally` or Context Managers (`with` statement) to ensure resources (files, sockets) are closed.
*   **Don't Swallow Errors:** Avoid `pass` in an `except` block unless you explicitly intend to suppress the error (and comment why).

**Bad:**
```python
try:
    do_something()
except:
    pass
```

**Good:**
```python
class PaymentFailedError(Exception):
    pass

try:
    charge_card()
except StripeError as e:
    logger.error(f"Stripe failed: {e}")
    raise PaymentFailedError("Could not process payment") from e
```

## Testing

We use **Pytest** as our testing framework.

*   **File Naming:** `test_*.py`
*   **Function Naming:** `test_scenario_expected_behavior`
*   **Fixtures:** Use `conftest.py` and fixtures for setup/teardown data. Avoid helper functions in classes.
*   **Mocking:** Use `unittest.mock` or `pytest-mock`. Only mock external dependencies (API calls, DB), not your own internal logic if possible.
*   **Coverage:** Aim for 80%+ code coverage.

```python
def test_calculate_total_with_discount():
    # Arrange
    cart = [Item(price=100)]

    # Act
    total = calculate_total(cart, discount=0.1)

    # Assert
    assert total == 90.0
```

## Concurrency & Parallelism

*   **I/O Bound:** Use `asyncio` (coroutines) for network requests and DB queries.
*   **CPU Bound:** Use `multiprocessing` to bypass the GIL.
*   **Threading:** Use `threading` sparingly; prefer `asyncio` for modern I/O code.

```python
async def fetch_all(urls: list[str]):
    tasks = [fetch_url(url) for url in urls]
    results = await asyncio.gather(*tasks)
    return results
```

## Modern Python Features

We encourage the use of modern Python features (3.10+).

*   **f-strings:** Always use f-strings for formatting. `f"Hello {name}"`.
*   **Walrus Operator (`:=`):** Use carefully. Good for regex matches or while loops.
*   **Pattern Matching (`match/case`):** Use for structural matching, not just as a switch statement.

```python
match data:
    case {"type": "user", "id": uid}:
        process_user(uid)
    case {"type": "admin", "id": uid}:
        process_admin(uid)
    case _:
        raise ValueError("Unknown type")
```

## Tooling & Enforcement

Our CI/CD pipeline enforces these standards automatically.

*   **Formatter:** `black`
*   **Linter:** `ruff` (replaces flake8, isort)
*   **Type Checker:** `mypy`
*   **Security:** `bandit`
*   **Pre-commit:** All developers must install `pre-commit` hooks to run these checks locally before pushing.

```bash
# Install hooks
pip install pre-commit
pre-commit install
```

## Related Interview Questions

*   **[Python Interview Questions](../../interview_questions/python.md)**: Test your knowledge of these concepts.
