# Workflow: Reflect and Learn

## Purpose

Capture insights from debugging sessions, back-and-forth with users, or trial-and-error problem solving to create self-learned rules that help avoid the same mistakes in future tasks.

## Trigger Detection (Cline Must Detect These)

YOU MUST detect these conditions and execute this workflow:
- **Multiple tool calls** for the same task (3+ attempts with mixed results)
- **Tool errors** that reveal a new pattern or constraint
- **User corrections** that identify recurring mistakes
- **Pattern recognition** during task execution (e.g., "I notice you keep making X mistake")
- **Myself asking for clarification** about patterns or best practices

## Execution (Cline Must Take Over)

### Step 1: Detect Trigger
YOU MUST scan the conversation for trigger conditions. When detected:
1. Identify the specific pattern or mistake
2. Note the original issue/error
3. Document what failed attempts were made

### Step 2: Analyze Conversation
YOU MUST analyze the chat history to extract:
1. The root cause of the problem
2. The simplest working solution
3. The pattern that should be avoided

### Step 3: Create or Update Self-Learned Rule
YOU MUST create or update a rule in `.airules/` folder:

**Location**: Save to `.airules/` folder (NOT `.airules/workflows/`)

**Naming**: Use format `sl-XX-description` where:
- `sl` = "self learned"
- `XX` = incrementing number (01, 02, 03, etc.)
- `description` = dash-separated topic (e.g., `mermaid-error-prevention`)

**Examples**:
- `sl-01-mermaid-error-prevention`
- `sl-02-avoid-escape-issues`
- `sl-03-special-character-handling`

**Rule Content Template**:
```markdown
# [Rule Title]

## Summary

[What problem this rule solves]

## Key Learnings

### What NOT to do:

- [Pattern that causes errors]

### What TO do:

- [Simplest working solution]

## Example

[Before/After code showing the fix]
```

**Update Existing Rules**: If a similar rule exists (check `.airules/sl-*`), UPDATE it with new information rather than creating duplicates.

### Step 4: Verify
YOU MUST verify the rule was created/updated by:
1. Checking the file exists in `.airules/`
2. Confirming the content matches the extracted pattern
3. Reporting back what rule was created or updated

## Execution Verification

Workflow is complete when:
1. Rule file exists in `.airules/` with `sl-XX-` prefix
2. Rule content captures the key insight from the conversation
3. You report back: "Created/updated rule: sl-XX-description.md"

## Key Principles

### Rule Placement

- Self-learned rules go in `.airules/` folder
- Workflow files go in `.airules/workflows/` folder
- Don't confuse the two locations

### Rule Naming

- Use `sl-XX-description` for self-learned rules
- Use `XX-description` for workflow files
- Keep descriptions concise and descriptive

### Rule Evolution

- Rules can and should be updated as understanding improves
- Updates to existing `sl-*` files are encouraged when needed
- Focus on accuracy and clarity over keeping outdated information