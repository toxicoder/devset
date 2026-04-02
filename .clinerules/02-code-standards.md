# Code Standards

> **Purpose**: Code quality, formatting, and security best practices

---

## Quick Rules

- **Indentation**: **4 spaces** for all files. No tabs.
- **Prettier Standard**: All code must be compatible with `esbenp.prettier-vscode`
- **Clean Code**: Prioritize readability over cleverness. Use descriptive names.

---

## Naming Conventions

| Element                      | Style                  | Examples                                   |
| :--------------------------- | :--------------------- | :----------------------------------------- |
| **Files**                    | `snake_case`           | `user_service.py`, `api_client.py`         |
| **Directories**              | `snake_case`           | `src/services`, `tests/integration`        |
| **Variables**                | `snake_case`           | `user_name`, `is_loading`, `max_retries`   |
| **Functions**                | `snake_case`           | `get_user_data()`, `handle_click()`        |
| **Classes/Types/Interfaces** | `PascalCase`           | `UserService`, `UserProfile`               |
| **Constants**                | `UPPER_SNAKE_CASE`     | `MAX_RETRIES`, `API_URL`                   |
| **Private Members**          | `_snake_case`          | `_private_method()`, `_internal_state`     |
| **Booleans**                 | `is_`, `has`, `should` | `is_loading`, `has_error`, `should_update` |

---

## Formatting Standards

### Line Length & Structure

- **Maximum line length**: 80 characters
- **Line endings**: Unix-style (`\n`)
- **Trailing whitespace**: Remove all on save
- **Blank lines**: Max 2 consecutive between sections

### Imports

Order and group:

1. Built-in modules or languages
2. External packages
3. Internal imports (absolute paths preferred)
4. Relative imports (last resort)

```python
import os
import sys
from pathlib import Path

from fastapi import FastAPI
import requests

from src.models.user import User
from src.services.auth import AuthService

from . import constants
from .utils import validate_input
```

### Quotes & Strings

- Prefer **single quotes** for string literals
- Use **double quotes** for strings containing single quotes/apostrophes
- Use **triple-quotes** for docstrings and multi-line strings
- Use f-strings for string interpolation

```python
# Single quotes preferred
text = 'Hello, World!'

# Double quotes for strings with apostrophes
text = "It's working!"

# Triple quotes for docstrings
def greet(name: str) -> str:
    """Return a greeting for the given name."""
    return f"Hello, {name}!"

# Multi-line strings
readme = '''Line one
Line two
Line three'''
```

### Spacing & Layout

- **Operators**: Space around binary operators (`=`, `+`, `-`, etc.)
- **Commas**: **Trailing commas** in multi-line collections
- **Braces**: Opening brace on **same line** as declaration
- **Empty Lines**: Max **2 consecutive** between logical sections
- **Function Invocation**: **No space** before parens

```python
# Operators with spacing
total = price + tax

# Trailing commas
config = {
    'host': 'localhost',
    'port': 8080,
    'debug': True,
}

# Opening brace on same line
class UserService:
    def __init__(self, api_url: str):
        self._api_url = api_url

# Function call: no space
result = filter(items, validate)
```

### Comments

- **Single-line**: Use `#` for inline comments
- **Multi-line**: Use triple-quotes for block comments
- **Documentation**: Use docstrings for modules, classes, functions
- **TODOs**: Format as `TODO:` or `TODO(#issue):` with description

```python
# Inline comment
max_retries = 3  # Maximum retry attempts

# TODO items
# TODO: Refactor this function to use async/await
# TODO(#42): Fix authentication token expiry issue

# Docstrings
def get_user(user_id: str) -> User:
    """Retrieve a user by their unique identifier.

    Args:
        user_id: The unique identifier of the user.

    Returns:
        The User object if found.

    Raises:
        NotFoundError: If the user does not exist.
    """
    pass
```

### File Structure

- Files should end with a **single newline**
- **Shebang** line for executable scripts: `#!/usr/bin/env python3`
- **Module docstrings** should include file purpose and author

---

## Design Principles

### SOLID Principles

- **S**: Single Responsibility — Functions/classes do one thing well
- **O**: Open/Closed — Open for extension, closed for modification
- **L**: Liskov Substitution — Subtypes interchangeable with base types
- **I**: Interface Segregation — Many specific interfaces over one general
- **D**: Dependency Inversion — Depend on abstractions, not concrete classes

```python
# Single Responsibility: One cohesive purpose
class EmailService:
    """Handles all email-related operations."""

    def send_welcome_email(self, user: User) -> None:
        pass

class PaymentService:
    """Handles all payment-related operations."""

    def process_payment(self, order: Order) -> Payment:
        pass

# Not this (poor cohesion)
class EmailAndPaymentService:  # Multiple responsibilities
    pass
```

### Additional Principles

- **DRY**: Don't Repeat Yourself — Abstract duplications
- **KISS**: Keep It Simple, Stupid — Avoid unnecessary complexity
- **YAGNI**: You Aren't Gonna Need It — Implement only what's needed now
- **Composition over Inheritance**: Prefer composition for flexibility

```python
# Composition over inheritance
class OrderProcessor:
    def __init__(
        self,
        validator: OrderValidator,
        tax_calculator: TaxCalculator,
        payment_gateway: PaymentGateway
    ):
        self.validator = validator
        self.tax_calculator = tax_calculator
        self.payment_gateway = payment_gateway

    def process(self, order: Order) -> ProcessedOrder:
        validated = self.validator.validate(order)
        taxed = self.tax_calculator.apply(validated)
        return self.payment_gateway.charge(taxed)
```

---

## Quality & Security

### Structural Integrity

- **Type Safety**: `strict: true` always enabled; inference over implicit `any`
- **Linting**: All warnings must be addressed; no suppressions without justification
- **Testing**: Unit + integration tests; **80%+** coverage minimum for core

```python
# Type hints required for public APIs
def process_payment(
    order_id: str,
    amount: decimal.Decimal,
    currency: str = 'USD'
) -> PaymentResult:
    pass

# Type checking tools: mypy, pyright, pytype, ruff
```

### Security

- **Input Validation**: All inputs validated (server-side)
- **Authentication**: Token-based, short-lived sessions
- **Secrets**: **Never commit**; use environment variables
- **Dependencies**: Regular audits for vulnerabilities

```python
# Environment variables for secrets
from dotenv import load_dotenv
import os

load_dotenv()

DATABASE_URL = os.environ.get('DATABASE_URL')
API_KEY = os.environ.get('API_KEY')

# Input validation with pydantic
from pydantic import BaseModel, EmailStr, Field

class UserInput(BaseModel):
    email: EmailStr
    password: str = Field(..., min_length=8)
    username: str = Field(..., pattern=r'^[a-zA-Z0-9_]+$')
```

---

## Cross-Language Patterns

### Encoding & Portability

- **ASCII-preferred**: Use ASCII-compatible characters when possible
- Replace special Unicode: `×` → `x`, `‑`/`–`/`—` → `-`, smart quotes → straight quotes

### Import & Fallback Patterns

```python
# Complete fallback pattern
try:
    from module import func_a, func_b, CONSTANT
except ImportError:
    def func_a(): pass
    def func_b(): pass
    CONSTANT = "default"

# Module-level fallback first
DRY_RUN = False
VERBOSE = False

try:
    from config import DRY_RUN, VERBOSE
except ImportError:
    pass  # Use module-level defaults
```

### Type Signature Rules

```python
# Explicit Optional for None defaults
def func(items: Optional[List[str]] = None) -> int:
    pass

# Match fallback signatures exactly
try:
    from module import create_item  # Returns Optional[str]
except ImportError:
    def create_item(...) -> Optional[str]:  # Must match!
        return None
```

---

## Language-Specific Style Guides

Refer to the following for language-specific standards:

| Language       | Style Guide Path                                         |
| -------------- | -------------------------------------------------------- |
| **Python**     | `docs/style_guides/python/python_style_guide.md`         |
| **JavaScript** | `docs/style_guides/javascript/javascript_style_guide.md` |
| **TypeScript** | `docs/style_guides/typescript/typescript_style_guide.md` |
| **Go**         | `docs/style_guides/golang/golang_style_guide.md`         |
| **SQL**        | `docs/style_guides/sql/sql_style_guide.md`               |
| **Bash**       | `docs/style_guides/bash/bash_style_guide.md`             |

---

## Related Documents

- **Testing Standards**: `docs/engineering_standards/testing_standards.md`
- **Code Review**: `docs/engineering_standards/code_review_guidelines.md`
- **Security Guidelines**: `clinerules-bank/security/security-guidelines.md`
