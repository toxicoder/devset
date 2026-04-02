# Discovery Protocol

> **Purpose**: Systematic approach to understanding codebases before implementation

---

## Core Principles

- **filesystem-first**: Exhaust local file system before reaching for external tools
- **progressive depth**: Start with high-level overviews; drill down only when needed
- **hypothesis-driven**: Form explicit questions; use discovery to test/eliminate hypotheses
- **cross-reference**: Verify findings using multiple tools and sources
- **atomic evidence**: Document each finding with specific file paths, line numbers, or code snippets

---

## 4-Phase Discovery Workflow

### Phase 1: Scoping & Context

**Goal**: Establish project boundaries and high-level architecture

1. List top-level directories
2. Read `package.json`, `pyproject.toml`, `Cargo.toml`, or equivalent
3. Identify primary entry points (e.g., `main.ts`, `app.py`, `main.rs`)
4. Document tech stack from dependencies/config

**Output**: One-paragraph project summary (type, stack, directory pattern, entry points)

### Phase 2: Structural Analysis

**Goal**: Map architecture and component relationships

1. Use `search_files` with patterns like `import|from|include|require` to trace dependencies
2. List code definition names for each relevant directory
3. Identify patterns: service layers, domain models, API routes
4. Map circular dependencies or tight coupling warnings
5. Note test file locations and patterns

**Output**: Text-based architecture diagram showing layers, service boundaries, key abstractions

### Phase 3: Deep Dive

**Goal**: Understand specific implementation details required for the task

1. Read key files in target directories
2. Search for TODO, FIXME markers, documented issues
3. Check version control history (`git log`) for recent changes to relevant files
4. Identify deprecation warnings or migration needs

**Output**: Detailed implementation notes (behavior, config, environment variables, limitations, tests)

### Phase 4: External Context (When Needed)

**Goal**: Verify library versions, best practices, and API behavior

**Gate**: Only proceed if local documentation is insufficient, version unclear, or API ambiguous

1. Use `context7` for documentation queries
2. Use `crawl4ai` for official documentation fetching
3. Use `brave-search` for community best practices
4. Cross-reference with GitHub repository

**Output**: External context report (verified versions, documentation sources, caveats)

---

## MCP Tool Selection

- **filesystem-first**: `list_files`, `read_file`, `search_files` before any external tools
- **Web research**: `brave-search` for tutorials, `crawl4ai` for official docs
- **Documentation**: `context7` for library-specific queries
- **GitHub**: `github` tool for repository operations

---

## Verification Checklist

Before proceeding to implementation, verify:

- [ ] File exists and content matches expectation
- [ ] Version is current (against lock file or config)
- [ ] No conflicting patterns in related files
- [ ] Related tests found or noted as missing

For external docs:

- [ ] Official source (from official repository or domain)
- [ ] Version matches project's dependency
- [ ] At least two sources confirm same behavior

---

## Error Handling

- **MCP server unavailable**: Check `mcp.json`, verify `npx` installed, retry with delay
- **File not found**: Verify path via `list_files`, search for alternative naming
- **No search results**: Relax regex pattern, ask for requirement clarification
- **Doc timeout**: Try alternative source, verify connectivity with `curl`
- **Version ambiguity**: Check all sources, flag as technical debt

---

## Discovery Checklist

**Phase 1 (Scoping)**: Project type/purpose, tech stack with versions, directory structure (top 3 levels), entry points, config files

**Phase 2 (Structure)**: Architecture layers, key abstractions, dependency graph, test locations, circular dependencies flagged

**Phase 3 (Deep Dive)**: Target files understood, TODOs/FIXMEs documented, recent changes checked, config deps identified, tests found

**Phase 4 (External)**: Library versions verified, official docs cited, caveats noted, cross-referenced
