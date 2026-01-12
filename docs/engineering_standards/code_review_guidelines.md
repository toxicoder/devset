---
layout: page
title: Code Review Guidelines
permalink: /engineering_standards/code_review_guidelines/
---

## Code Review Guidelines: The Handbook

Code review is the single most important mechanism for maintaining high
engineering standards at our company. It is not just about catching bugs; it is
about knowledge sharing, mentorship, and collective ownership of the codebase.

This document serves as the comprehensive guide for both authors and reviewers.
It defines our philosophy, etiquette, and best practices.

## 1. The Philosophy of Code Review

### 1.1. Code is a Liability

Every line of code we write is a liability. It must be read, understood, tested,
debugged, and maintained. Therefore, the best code is no code. Code review is
the gatekeeping process where we ask: "Is this liability worth the value it
provides?"

### 1.2. Collective Ownership

Once code is merged, it belongs to the team, not the individual. The "blame" for
a bug found in production lies with the team that reviewed and merged it, not
just the author. When you approve a PR, you are co-signing the mortgage on that
code.

### 1.3. Mentorship Over Gatekeeping

Code review is a teaching moment. Senior engineers should use it to mentor
juniors on architecture and design patterns. Junior engineers should use it to
learn from seniors' code and ask "why." It should never be used to flex
intellectual superiority.

### 1.4. Speed vs. Quality

We optimize for "velocity over time," not "speed today." Merging bad code
quickly slows us down next week. However, perfect is the enemy of good. We aim
for _maintainable_ code, not _perfect_ code.

---

## 2. For Authors: Preparing a PR

A Code Review starts _before_ you open the Pull Request.

### 2.1. The "15-Minute Rule"

A PR should be reviewable in under 15 minutes. If it takes longer, the
reviewer's attention wanes, and bugs slip through.

- **Target:** < 400 lines of code changed.
- **Strategy:** Break large features into stackable PRs (e.g.,
  `Part 1: Database Schema`, `Part 2: API Endpoint`, `Part 3: UI`).

### 2.2. The Description Template

A PR without a description is a black box. You must provide context.

- **What:** Briefly describe the changes.
- **Why:** Link to the Jira ticket or Tech Spec. Explain the business value.
- **How:** Explain any non-obvious technical decisions (e.g., "I chose Redis
  over Memcached because...").
- **Screenshots/GIFs:** Mandatory for UI changes. A picture is worth 1000 lines
  of code.

### 2.3. The Self-Review Checklist

Before assigning reviewers, go through this checklist:

1.  [ ] Did I run the tests locally?
2.  [ ] Did I lint the code?
3.  [ ] Did I remove all `console.log` or print statements?
4.  [ ] Did I add comments for complex logic?
5.  [ ] Did I read the diff myself on GitHub/GitLab to catch unintended files?

---

## 3. For Reviewers: How to Review

### 3.1. The Hierarchy of Feedback

Not all comments are created equal. Focus on what matters.

1.  **Correctness:** Does the code do what it's supposed to do? Are there bugs?
2.  **Security:** Are there vulnerabilities (XSS, SQLi, IDOR)?
3.  **Readability:** Can a new hire understand this without asking you?
4.  **Architecture:** Does this fit into the broader system design?
5.  **Performance:** Are there N+1 queries or memory leaks?
6.  **Style:** (Lowest priority) Indentation, variable naming. _Let the linter
    handle this._

### 3.2. Commenting Etiquette

How you say it is as important as what you say.

- **Ask, Don't Command:**
  - _Bad:_ "Rename this variable to `user_id`."
  - _Good:_ "What do you think about renaming this to `user_id` to match the
    schema?"
- **Critique the Code, Not the Person:**
  - _Bad:_ "You forgot to close the connection."
  - _Good:_ "It looks like the connection might stay open here. Should we add a
    `defer.close()`?"
- **Explain "Why":**
  - _Bad:_ "Change this to a Set."
  - _Good:_ "Using a Set here would make the lookup O(1) instead of O(n)."

### 3.3. Speed Expectations

- **SLA:** 24 hours. Code review shouldn't block progress.
- **Urgent PRs:** If a PR is blocking a release, review it immediately.
- **Acknowledgement:** If you can't review it today, comment "I'll get to this
  tomorrow morning" so the author isn't left hanging.

---

## 4. Standard Comment Prefixes

To make reviews more efficient, we use prefixes to denote the severity of a
comment.

- **[BLOCKER]:** This issue must be fixed before merging. (e.g., Bug, Security
  flaw).
- **[MAJOR]:** Strong recommendation. I will likely re-review. (e.g.,
  Performance issue, confusing logic).
- **[MINOR]:** Suggestion. You can merge without fixing, but consider it. (e.g.,
  Variable naming, slight refactor).
- **[NIT]:** Nitpick. Tiny detail. (e.g., Typo in comment).
- **[QUESTION]:** I don't understand this. Please explain. (Doesn't necessarily
  need a code change).
- **[PRAISE]:** This is really good! (e.g., "Elegant solution!", "Great test
  coverage!").

---

## 5. Handling Disagreements

Disagreements are healthy. They show we care. But they must be resolved
professionally.

### 5.1. The "Two-Comment Rule"

If you go back and forth more than twice on a single comment thread, **stop
typing**.

- Hop on a call (Slack Huddle / Zoom).
- Discuss it synchronously.
- Post the resolution as a comment on the PR for history.

### 5.2. Tie-Breakers

If the author and reviewer cannot agree:

1.  **Style Guide:** Consult the written style guide. If it's not there, add it.
2.  **Tech Lead:** Escalate to the Staff Engineer or Tech Lead for a deciding
    vote.
3.  **Data:** Run a benchmark or POC to prove which approach is better.

---

## 6. Language-Specific Checklists

### 6.1. Python

- [ ] Are type hints (`mypy`) used for all function arguments and return values?
- [ ] Are list comprehensions used appropriately (readable)?
- [ ] Are context managers (`with`) used for file/network resources?
- [ ] Are exceptions handled specifically (no bare `except:` or
      `except Exception:`)?

### 6.2. JavaScript / TypeScript

- [ ] Is `const` used over `let` wherever possible? (`var` is forbidden).
- [ ] Are `async/await` used instead of raw Promises?
- [ ] Is strict equality (`===`) used?
- [ ] Are React hooks used correctly (dependency arrays)?

### 6.3. Go

- [ ] Are errors handled explicitly (no `_` for error returns)?
- [ ] Are goroutines managed (waitgroups, channels) to prevent leaks?
- [ ] Is the `context` passed down for cancellation/timeouts?
- [ ] Does it follow `gofmt`?

---

## 7. Metrics & Success

We measure the health of our code review process using the following metrics:

1.  **Review Turnaround Time:** Median time from "Open" to "Merged". (Target: <
    48 hours).
2.  **Review Depth:** Average number of comments per PR. (Too low = rubber
    stamping; Too high = nitpicking or bad requirements).
3.  **Merge Frequency:** Number of PRs merged per dev per week. (Target: > 3).

## 8. Final Thoughts

Code review is a service we perform for our team. Treat it with the same care
and professionalism as you would writing production code. A good code review can
save days of debugging and thousands of dollars. Be kind, be thorough, and keep
shipping.
