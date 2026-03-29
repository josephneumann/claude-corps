---
name: debug
description: "Use when facing a bug, test failure, or unexpected behavior that isn't immediately obvious"
allowed-tools: Read, Bash, Glob, Grep, Edit, Write, AskUserQuestion, WebSearch
---

# Systematic Debugging

**Iron Law**: NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST.

## Phase 1: Reproduce & Isolate

- Reproduce the failure reliably before anything else
- Isolate the smallest failing case
- If you can't reproduce it, you can't fix it
- Record the exact command, input, and output that demonstrates the failure

## Phase 2: Gather Evidence

Before forming hypotheses, collect facts:

- Read the actual code path from input to failure point. Don't guess from memory.
- Check recent changes: `git log --oneline -10 -- <file>`
- Add temporary logging or assertions at key points to trace data flow
- Collect the full error message, stack trace, and relevant log output
- If a stack trace exists, trace backward through the call chain to the origin

**Known bug patterns — check these first:**

| Pattern | Signature |
|---------|-----------|
| Race condition | Intermittent failure, timing-dependent, works in debugger |
| Nil/null propagation | `undefined is not a function`, `NoMethodError`, `NoneType` |
| State corruption | Works first time, fails on second; stale data after mutation |
| Integration failure | Works in isolation, fails with real dependency (DB, API, queue) |
| Configuration drift | Works locally, fails in CI/staging; env var mismatch |
| Stale cache | Old behavior persists after code change; hard refresh fixes it |
| Off-by-one / boundary | Fails at 0, 1, max, or empty input; pagination edge cases |

If the bug matches a known pattern, state which one and focus investigation there.

## Phase 3: Hypothesize & Test

- Form a specific hypothesis: "The root cause is X because evidence Y"
- Predict the outcome BEFORE running each test
- Test one variable at a time
- If your prediction is wrong, update your mental model — don't just try the next thing

**"5 Whys" drill-down** — when the cause isn't obvious, ask why iteratively:
1. Why did the request fail? → The handler returned null
2. Why did it return null? → The query returned no rows
3. Why did the query return no rows? → The ID was from a different tenant
4. Why was the ID from a different tenant? → The session wasn't scoped to tenant
5. Why wasn't the session scoped? → **Root cause: middleware ordering**

Keep asking why until you reach something you can fix directly.

## Phase 4: Fix & Verify

1. **Write a regression test** that fails without the fix and passes with it. This is not optional.
2. Fix the root cause, not the symptom
3. Keep the diff minimal — only change what's needed to fix the bug
4. Run the original failing test to confirm the fix
5. Run the full test suite to check for regressions

## Three-Strikes Rule

If 3 hypotheses have failed, STOP. You are likely wrong about the root cause.

- Go back to Phase 2 and re-read the code path from scratch
- Question your assumptions about the architecture
- Use AskUserQuestion to escalate: describe what you've tried, what you've ruled out, and where you're stuck
- Optionally WebSearch for the error message or pattern — someone may have hit this before

**Escalation is not failure.** Bad work is worse than no work. Stop guessing.

## Red Flags

If you catch yourself thinking any of these, STOP:

- "Let me just try..." — You're guessing, not tracing.
- "Maybe if I..." — Form a hypothesis and predict the outcome first.
- "This might work..." — Why would it work? What's your evidence?
- "It's probably this..." — Probably based on what? State the evidence.

## Anti-Rationalization Table

| Excuse | Reality |
|--------|---------|
| "Let me try a quick fix first" | Quick fixes without root cause analysis create new bugs. |
| "I know what the problem is" | Then state your hypothesis and predict the test outcome. |
| "It works now after my change" | Correlation is not causation. Verify your fix addresses the root cause. |
| "The test is flaky, not my code" | Reproduce it 3 times. If it fails 2/3, it's your code. |
| "I'll add better error handling" | Error handling hides bugs. Fix the cause, not the symptom. |

## Debug Report

After resolution, output a structured report:

```
═══════════════════════════════════════════
DEBUG REPORT
═══════════════════════════════════════════
Status: DONE / DONE_WITH_CONCERNS / BLOCKED
Symptom: [what was observed]
Root Cause: [what was actually wrong]
Pattern: [known pattern match, if any]
Fix: [what was changed and why]
Regression Test: [test name and what it verifies]
Evidence: [how you confirmed the fix addresses the root cause]
Hypotheses Tested: N (list failed ones if >1)
═══════════════════════════════════════════
```

- **DONE** — Root cause identified, fix applied, regression test passes, full suite green
- **DONE_WITH_CONCERNS** — Fixed, but related issues discovered. Note them for follow-up.
- **BLOCKED** — Cannot resolve. Document what was tried and what's needed to proceed.

If the root cause was non-obvious, save debugging insights to auto-memory.

*Evolved from obra/superpowers systematic-debugging skill with patterns from garrytan/gstack and community best practices.*
