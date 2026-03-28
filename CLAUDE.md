# CLAUDE.md (Global)

> **Violating the letter of the rules is violating the spirit of the rules.** There are no valid exceptions, clever workarounds, or "spirit of the intent" arguments that justify skipping a required step.

1. **Parallel by default, sequential when needed** — Independent tasks run simultaneously in isolated git worktrees (`isolation: "worktree"`). Dependent tasks run sequentially on the branch (`--sequential`). Use the right mode for the dependency structure.
2. **Orchestrator + Workers** — One session orients (`/orient`) and dispatches workers; workers execute discrete tasks (`/start-task`) and report back with session summaries.
3. **Task-sized work** — Break work into chunks that fit comfortably in context. Big enough to be a meaningful atomic change, small enough to complete without exhausting the context window.
4. **Bounded autonomy** — Clarify requirements and define acceptance criteria before coding. Then execute autonomously within those bounds.
5. **Tests as the contract** — "Done" means tests pass. Never close a task with failing tests. The code proves itself.
6. **Human in the loop** — Humans approve PRs, prioritize tasks, and make architectural decisions. AI executes, human directs.
7. **Handoffs over context bloat** — When context grows large, the orchestrator spawns a replacement worker with the prior context rather than degrading quality.
8. **Session summaries** — Every completed task outputs a detailed summary. Each session leaves breadcrumbs for the next.
9. **Save what you learn** — Save debugging insights, non-obvious solutions, and prevention strategies to auto-memory when completing tasks.
10. **Codify the routine** — Repeated patterns become skills and commands. If you do something twice, automate it.
11. **Evaluate, don't agree** — When receiving feedback, review findings, or processing reports: verify claims against evidence before acting. No performative agreement ("Great point!", "You're absolutely right!"). Fix silently or explain technical disagreement. YAGNI applies to review suggestions too.

## Critical Rule: Never Merge a PR Without User Confirmation

**NEVER merge a pull request without explicit confirmation from the user.** Always ask before merging, even if all checks pass and the review looks clean. The human decides when code lands.

## Task Tracking

If the Linear MCP server is connected (test: `list_teams` tool is available), use Linear for all task operations — creating issues, updating status, querying ready tasks, managing dependencies.

If Linear MCP is **not** available, skip all task tracking steps in skills silently. Continue with implementation work. Plan files in `docs/plans/` are always the primary deliverable.

**Task tracking is advisory, not a gate.** Never block implementation on a task-tracking failure. If a Linear call fails, log a warning and continue.

### Linear Config

When using Linear, reference these workspace details:

- **Detection**: Check if `list_teams` or `list_issues` tools are available
- **"Ready" tasks**: `list_issues(state=Todo)` → filter to those with empty `blockedBy` via `get_issue(includeRelations=true)`
- **Status mapping**: open → Todo, in_progress → In Progress, closed → Done
- **Relations**: `blocks`/`blockedBy` on `save_issue` (append-only — remove via Linear UI)
- **Hierarchy**: `parentId` on `save_issue` for sub-issues; Linear projects for grouping (projects are NOT issues)
- **Agent delegation**: `delegate` field on `save_issue` to assign to named agents
- **Comments**: `save_comment` for session summaries, reconciliation notes
- **Issue creation authority**: Only orchestrator-facing skills (`/spec`, `/reconcile-summary`, `/orient`, `/auto-run`) may call `save_issue` to create new issues. Worker skills (`/finish-task`, `/multi-review`) must document discovered work in the session summary's DISCOVERED WORK section instead. The orchestrator proposes new issues for user approval at reconciliation boundaries.
- **Quality gate**: Every `save_issue` creating a new issue must include: structured description (Problem/Approach/Acceptance Criteria/Target Files sections), priority, at least one label, and project. After creation, run post-write validation (`get_issue` to check for formatting artifacts).

## Critical Rule: Always Run `/finish-task`

**A task is NOT complete until `/finish-task` has been run.** No exceptions.

## Don'ts

- Don't amend published commits — create new commits
- Don't skip hooks (`--no-verify`, `--no-gpg-sign`) — investigate and fix the underlying issue
- Don't create new files when editing existing ones suffices
- Don't add error handling, validation, or abstractions for scenarios that can't happen
- Don't add comments, docstrings, or type annotations to code you didn't change
- Don't force-push to main/master
- Don't use `git add -A` or `git add .` — stage specific files by name

## Commit Guidance

- **Atomic commits**: One logical change, independently passes tests, revertible
- **Message format**: `<type>: <summary>` — types: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`

## Orchestrator Reminder

Before ending an orchestrator session, always run `/reconcile-summary`.

## Reference

@docs/reference.md
@docs/workflow-cheatsheet.md
