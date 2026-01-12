---
layout: page
title: Code Review Guidelines
permalink: /engineering_standards/code_review_guidelines/
---

# Code Review Guidelines

**Effective Date:** January 1, 2024
**Owner:** Engineering Leadership
**Audience:** All Engineers

## 1. Introduction

Code Review (CR) is the single most important mechanism we have for maintaining code quality, sharing knowledge, and building engineering culture. It is not a hurdle to clear; it is a collaborative process to make our software better.

### The "Google Standard"
We aspire to the standard set by Google and other tech giants:
> "In general, reviewers should favor approving a CL (Change List) once it is in a state that definitely improves the overall code health of the system, even if the CL isn't perfect."

---

## 2. Philosophy & Principles

### For Authors
1.  **Small is Beautiful:** The single best predictor of code review quality is the size of the Pull Request (PR). Aim for PRs that are **under 400 lines** of code.
2.  **Context is King:** Your PR description is as important as your code. Explain *why* you are making this change, not just *what* changed.
3.  **Review Yourself First:** Never open a PR without reading through the diff yourself. Catch the typos and console logs before asking for your teammate's time.

### For Reviewers
1.  **Speed Matters:** Code review velocity directly impacts shipping velocity. Aim to review code within **24 hours** (or one business day).
2.  **Be Kind:** Critique the code, not the person. "This code is buggy" is better than "You wrote a bug." "Consider using X" is better than "Why didn't you use X?"
3.  **Distinguish Blockers from Nitpicks:** Explicitly label your comments.
    *   **[BLOCKER]:** This must be fixed before merge (e.g., security flaw, major bug).
    *   **[NIT]:** Minor suggestion (e.g., variable naming, formatting). Author can ignore if they disagree.
    *   **[QUESTION]:** Asking for clarification.

---

## 3. The Code Review Checklist (General)

### Functionality
*   [ ] Does the code do what it claims to do?
*   [ ] Are there any obvious bugs?
*   [ ] Does it handle edge cases (null inputs, empty lists, network failures)?
*   [ ] Is it thread-safe (if applicable)?

### Architecture & Design
*   [ ] Is the code in the right place? (e.g., Business logic in the Service layer, not the Controller).
*   [ ] Does it follow SOLID principles?
*   [ ] Is it over-engineered? (YAGNI).
*   [ ] Does it introduce circular dependencies?

### Readability & Maintenance
*   [ ] Are variable and function names descriptive?
*   [ ] Is the logic easy to follow?
*   [ ] Are complex hacks documented with comments explaining *why*?
*   [ ] Is there any dead code or commented-out code?

### Testing
*   [ ] Are there unit tests?
*   [ ] Do the tests actually test the logic (not just mocking everything)?
*   [ ] Are the tests readable?

### Security & Performance
*   [ ] Is user input sanitized? (SQL Injection, XSS).
*   [ ] Are secrets (API keys) committed? (Check carefully!).
*   [ ] Are loops efficient? (Avoid N+1 queries).

---

## 4. Language-Specific Checklists

### Python
*   **Style:** Does it follow PEP 8? (Use `black` and `ruff`).
*   **Type Hinting:** Are type hints used for function arguments and return values?
*   **List Comprehensions:** Are they used appropriately (readable)?
*   **Context Managers:** Are `with` statements used for file/resource handling?
*   **Exceptions:** Are we catching specific exceptions (e.g., `ValueError`) rather than bare `except:`?
*   **Docstrings:** Does every public function/class have a docstring?

### JavaScript / TypeScript
*   **Async/Await:** Is `async/await` used instead of raw Promises/callbacks?
*   **Types:** Are `any` types avoided? Is the schema strictly typed?
*   **React Hooks:** Are hooks used correctly (rules of hooks)? Are dependency arrays correct?
*   **Destructuring:** Is object/array destructuring used for cleaner code?
*   **Equality:** Is `===` used instead of `==`?
*   **Console:** Are `console.log` statements removed?

### Go (Golang)
*   **Formatting:** Is `gofmt` applied?
*   **Error Handling:** Are errors checked and handled explicitly? (No `_` for error returns).
*   **Context:** Is `context.Context` passed as the first argument to functions doing I/O?
*   **Concurrency:** Are goroutines and channels used correctly? (Check for leaks/race conditions).
*   **Naming:** Do names follow Go conventions (Short, MixedCaps)?
*   **Interfaces:** Are interfaces defined where used (consumer-side)?

---

## 5. The Process

### Step 1: The Author Opens the PR
*   **Title:** Concise and descriptive. (e.g., "Fix race condition in UserAuth").
*   **Description:**
    *   **Summary:** What changed?
    *   **Context:** Why this change? Link to Jira ticket.
    *   **Test Plan:** How did you verify this? (e.g., "Tested locally with curl").
    *   **Screenshots:** (For UI changes).
*   **Assign Reviewers:** Pick 1-2 relevant people. Don't spam the whole team.

### Step 2: The Review Loop
*   Reviewer reads the code.
*   Reviewer leaves comments (inline).
*   **Approval:** If it looks good, click "Approve."
*   **Request Changes:** If there are blockers, select "Request Changes."
*   Author responds to comments.
    *   "Done" (fixed).
    *   "Ack" (acknowledged but not fixing - explain why).
*   Author pushes new commits.
*   Reviewer re-reviews.

### Step 3: Merging
*   Once approved (and CI passes), the **Author** is responsible for merging.
*   "Squash and Merge" is the default to keep the history clean.

---

## 6. Handling Disagreements

Disagreements are healthy. Stalemate is not.

1.  **Discuss:** Use the PR comments to debate technical trade-offs.
2.  **Escalate to Sync:** If a comment thread goes back and forth more than 3 times, **stop typing**. Jump on a quick Slack huddle or Zoom call.
3.  **The "Tie-Breaker":** If you still can't agree, defer to the **Style Guide** or the **Team Lead / Architect**.
4.  **Agree to Disagree:** For non-critical issues, the Reviewer should yield to the Author's preference.

---

## 7. Examples: Good vs. Bad Reviews

### Example 1: Naming
*   **Bad:** "Change this variable name."
*   **Good:** "[NIT] `x` is a bit vague. How about `userIndex` to make it clearer what we're iterating over?"

### Example 2: Performance
*   **Bad:** "This is slow."
*   **Good:** "[BLOCKER] This loop makes a database call in every iteration (N+1 problem). This will likely time out with large datasets. Can we fetch all the data in one query beforehand?"

### Example 3: Praise (Don't forget this!)
*   **Good:** "I really like how you refactored this logic. It's much cleaner now!"
*   **Good:** "Great catch on that edge case."

---

## 8. Metrics (How we measure success)

We track these metrics not to punish, but to improve our workflow.

*   **Review Turnaround Time:** Time from "PR Opened" to "Review Submitted." Target: < 24 hours.
*   **PR Size:** Number of lines changed. Target: < 400 lines.
*   **Pick-up Time:** Time until the first comment is left.

---

## 9. Specific Scenarios

### Emergency Fixes (The "Hotfix")
Sometimes production is burning, and we can't wait 24 hours.
*   **Protocol:**
    1.  Announce in Slack: "Emergency PR incoming!"
    2.  Get a "LGTM" (Looks Good To Me) from *anyone* available (even a junior).
    3.  Merge.
    4.  **Post-Merge Review:** Do a proper deep-dive review the next day to clean up any hacks.

### Generated Code
*   Do not review generated files (e.g., `package-lock.json`, compiled JS).
*   Focus on the configuration that generated them.

### Junior vs. Senior Reviewing
*   **Seniors:** Focus on architecture, security, and scalability. Mentor juniors through comments.
*   **Juniors:** Focus on readability, logic bugs, and tests. Don't be afraid to ask "Why?".

---

*Remember: The goal of code review is to ship high-quality software while growing as a team.*
