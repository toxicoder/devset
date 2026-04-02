# Cross-Language Code Patterns

> **Purpose**: Universal coding patterns applicable across programming languages

---

## Universal Principles

- **Read-Local-Before-External**: Always inspect local codebase before reaching for external documentation
- **Fallback-First-Pattern**: Define fallback values before conditional imports
- **Type-Safety-Strict-By-Default**: Enable strictest type checking available
- **ASCII-Preferred-for-Portability**: Use ASCII-compatible characters in source files

---

## Import and Fallback Patterns

### Try-Except-With-Complete-Fallbacks

When conditionally importing modules, provide fallbacks for ALL imported items:

```python
# Complete fallback pattern
try:
    from module import func_a, func_b, CONSTANT
except ImportError:
    def func_a(): pass
    def func_b(): pass
    CONSTANT = "default"
```

### Module-Level-Fallback-First

Define fallback values at module level before try/except blocks:

```python
# Define at module level first
DRY_RUN = False
VERBOSE = False

try:
    from config import DRY_RUN, VERBOSE
except ImportError:
    pass  # Use module-level defaults
```

### No-Duplicate-Definitions

Never define a function locally AND import it:

```typescript
// Wrong - duplicate definition
import { helper } from './helper';
export function helper() {}  // Error!

// Right - only import or only define
import { helper } from './helper';
// OR
export function helper() {}
```

### Clean-Unused-Imports

Remove unused imports or suppress warnings intentionally:

```python
# Clean up unused
try:
    from module import used_func
    # Don't import unused_func unless needed in fallback
except ImportError:
    def used_func(): pass
```

---

## Type Signature Rules

### Explicit-Optional-For-Nullable-Defaults

Always explicitly mark parameters with `None` default as optional:

```python
# Wrong
def func(items: List[str] = None) -> int:  # mypy error

# Right
def func(items: Optional[List[str]] = None) -> int:
    pass
```

TypeScript equivalent:

```typescript
// Wrong
function func(items: string[] = undefined) {}

// Right
function func(items: string[] | undefined = undefined) {}
```

### Match-Fallback-Signatures-Exactly

Fallback implementations must match imported function signatures exactly:

```python
# Match return type exactly
try:
    from module import create_item  # Returns Optional[str]
except ImportError:
    def create_item(...) -> Optional[str]:  # Must match!
        return None
```

### Use-Type-Aliases-For-Repeated-Signatures

Define type aliases for consistency:

```python
# Define alias
ItemId = Optional[str]

try:
    from module import create_item
except ImportError:
    def create_item(...) -> ItemId:
        return None
```

---

## Module Organization

### Export-All-Public-APIs

Functions used by other modules must be properly exported:

```python
# Module should export all public functions
def public_api_func():
    pass

# Don't leave public functions unexported
```

### Define-Central-Constants

Configuration constants should live in a central defaults module:

```python
# config/defaults.py
DEFAULT_PROJECT_NAME = "My Project"
DRY_RUN = False
VERBOSE = False
```

### Provide-Stubs-For-External-Types

For libraries without type stubs, install stub packages or use type ignores:

```python
# Option 1: Install stubs
pip install types-requests

# Option 2: Type ignore for specific imports
try:
    import requests  # type: ignore
except ImportError:
    pass
```

---

## Encoding and Portability

### ASCII-Compatibility

Replace special Unicode characters with ASCII equivalents:

| Unicode | Description      | ASCII Replacement |
|---------|------------------|-------------------|
| ×       | Multiplication   | x                 |
| ‑/–/—   | Various dashes   | -                 |
| ", "    | Smart quotes     | "                 |
| ', '    | Smart apostrophes| '                 |
| …       | Ellipsis         | ...               |

```python
# Wrong
TEXT = "4× daily + cross‑channel"  # Non-ASCII

# Right
TEXT = "4x daily + cross-channel"  # ASCII-only
```

**Verification:**

```bash
grep -P '[^\x00-\x7F]' file.py  # Find non-ASCII chars
