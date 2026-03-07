# CLAUDE.md (Global)

This file provides workflow guidance for Claude Code across all projects. Project-specific details belong in each project's own `CLAUDE.md`.

## Philosophy

This codebase will outlive you. Every shortcut becomes someone else's burden. Every hack compounds into technical debt that slows the whole team down.

You are not just writing code. You are shaping the future of this project. The patterns you establish will be copied. The corners you cut will be cut again.

Fight entropy. Leave the codebase better than you found it.

> **Violating the letter of the rules is violating the spirit of the rules.** There are no valid exceptions, clever workarounds, or "spirit of the intent" arguments that justify skipping a required step.

---

1. **Parallel by default** — Multiple sessions work simultaneously in isolated git worktrees. Use `claude --worktree` for single sessions or `isolation: "worktree"` for dispatched teammates.

2. **Orchestrator + Workers** — One session orients (`/orient`) and coordinates via Agent Teams; teammates execute discrete tasks (`/start-task`) and report back with session summaries.

3. **Task-sized work** — Break work into chunks that fit comfortably in context. Big enough to be a meaningful atomic change, small enough to complete without exhausting the context window.

4. **Bounded autonomy** — Clarify requirements and define acceptance criteria before coding. Then execute autonomously within those bounds.

5. **Tests as the contract** — "Done" means tests pass. Never close a task with failing tests. The code proves itself.

6. **Human in the loop** — Humans approve PRs, prioritize tasks, and make architectural decisions. AI executes, human directs.

7. **Handoffs over context bloat** — When context grows large, the team lead spawns a replacement teammate with the prior context rather than degrading quality.

8. **Session summaries** — Every completed task outputs a detailed summary. Each session leaves breadcrumbs for the next.

9. **Save what you learn** — Save debugging insights, non-obvious solutions, and prevention strategies to auto-memory when completing tasks.

10. **Codify the routine** — Repeated patterns become skills and commands. If you do something twice, automate it.

11. **Evaluate, don't agree** — When receiving feedback, review findings, or processing reports: verify claims against evidence before acting. No performative agreement ("Great point!", "You're absolutely right!"). Fix silently or explain technical disagreement. YAGNI applies to review suggestions too.

---

## Critical Rule: Never Merge a PR Without User Confirmation

**NEVER merge a pull request without explicit confirmation from the user.** Always ask before merging, even if all checks pass and the review looks clean. The human decides when code lands.

---

## Critical Rule: Always Run `/finish-task`

**A task is NOT complete until `/finish-task` has been run.**

"Tests pass" ≠ "Done". The `/finish-task` skill creates the PR, runs code review, generates the session summary, and closes the task. Without it:
- The orchestrator has no visibility into your work
- The task remains open in beads
- No PR exists for review
- The worktree is left dangling

When your implementation is ready: **run `/finish-task <task-id>`**. No exceptions.

---

## Skills Reference

All workflow capabilities are implemented as skills in `skills/`.

### Planning Pipeline

| Skill | Purpose | When to Use |
|-------|---------|-------------|
| `/spec` | Research, plan, decompose into tasks | New idea, feature description, or goal |
| `/spec --deepen` | Enhance plan with parallel research agents | Existing plan needs more depth |

### Execution

| Skill | Purpose | When to Use |
|-------|---------|-------------|
| `/orient` | Build context, identify parallel work | Session start |
| `/start-task <id>` | Claim task, gather context, define criteria | Beginning a task |
| `/finish-task <id>` | Tests, commit, PR, cleanup, close | Task complete |
| `/dispatch` | Spawn Agent Teams teammates (with isolation verification) | Multiple ready tasks |
| `/auto-run` | Autonomous dispatch-reconcile loop | Batch processing, overnight runs |
| `/summarize-session <id>` | Progress summary (read-only) | Mid-session checkpoint |
| `/reconcile-summary` | Sync beads with implementation reality | After worker completes |

### Quality

| Skill | Purpose | Triggers |
|-------|---------|----------|
| `/multi-review` | Parallel code review with specialized agents | "thorough review", PR review, explicit |

### Utility

| Skill | Purpose | When to Use |
|-------|---------|-------------|
| `/humanizer` | Remove AI writing patterns | Text sounds like AI slop |

### Discipline

| Skill | Purpose | When to Use |
|-------|---------|-------------|
| `/verify` | Evidence before claims, anti-sycophancy | Cross-referenced by other skills; invoke when making completion claims |
| `/debug` | Systematic debugging methodology | Bug, test failure, unexpected behavior |
| `/writing-skills` | Skill authoring guidance | Creating or revising a skill definition |

---

## Research Agents

Available in `/orient` (Phase 1.5) and `/start-task` (Step 5.5) for complex tasks:

| Agent | Purpose |
|-------|---------|
| `repo-research-analyst` | Map architecture, conventions |
| `git-history-analyzer` | Historical context, contributors |
| `framework-docs-researcher` | Library docs, deprecation checks |
| `best-practices-researcher` | Industry patterns, recommendations |

---

## Agents

**Review** (`/multi-review`): `code-simplicity-reviewer`, `security-sentinel`, `api-security-reviewer`, `performance-oracle`, `pattern-recognition-specialist`, `architecture-strategist`, `agent-native-reviewer`, `data-integrity-guardian`, `data-migration-expert`. Framework-specific (`nextjs-reviewer`, `tailwind-reviewer`, `python-backend-reviewer`) auto-detect from changed files.

**Workflow**: `spec-flow-analyzer` — analyze specs for dependencies, gaps, feasibility.

---

## Project Configuration

Optional `.claude/review.json` configures risk tiers and reviewer overrides for `/multi-review` and `/dispatch`. See `docs/examples/review-fullstack.json` for examples.

---

## Commit Guidance

- **Atomic commits**: One logical change, independently passes tests, revertible
- **Message format**: `<type>: <summary>` — types: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`

---

## Workflow Cheatsheet

```bash
# Plan a new project
/spec → /spec --deepen (optional) → /orient → /dispatch

# Single session
/orient → /start-task <id> → implement → /finish-task <id>

# Parallel sessions (orchestrator via Agent Teams)
/orient → /dispatch --count 3
# Teammates auto-spawn, run /start-task, implement, run /finish-task

# Worker completes → orchestrator reconciles
/reconcile-summary → update beads → dispatch next batch

# Fully autonomous
/auto-run --through <target-task>
# Or unattended: ~/.claude/scripts/auto-run.sh --max-hours 8

# IMPORTANT: Before ending an orchestrator session, always run:
/reconcile-summary
```

---

## Beads Task Management

Tasks are managed with `bd` (beads CLI):

```bash
bd ready                    # Show tasks ready to work
bd list                     # All open tasks
bd show <id>                # Task details
bd create --title="..." --type=task --priority=2
bd update <id> --status=in_progress
bd close <id>
bd sync --flush-only        # Export to JSONL
```

---

Quality gate hooks enforce workflow discipline. See `hooks/` for implementation.

---

*Full documentation: See skill definitions in `~/.claude/skills/` or the [claude-corps repo](https://github.com/josephneumann/claude-corps).*
