# Workflow Cheatsheet

```bash
# Plan a new project (Phase 2.5 eng review runs automatically in /spec)
/spec → /orient → /dispatch

# Plan with full-depth interactive review
/spec → /plan-eng-review → /orient → /dispatch

# Plan a UI feature (with design review)
/product-review DESIGN → /spec → /plan-design-review → /orient → /dispatch

# Standalone reviews on existing plans
/plan-eng-review              # Full interactive engineering review
/plan-design-review           # Full 7-pass scored design review

# Single session
/orient → /start-task <id> → implement → /finish-task <id>

# Parallel sessions (worktree-isolated workers)
/orient → /dispatch --count 3
# Workers auto-spawn in isolated worktrees, run /start-task, implement, run /finish-task

# Sequential sessions (direct on branch, no worktrees)
/orient → /dispatch --sequential <task1> <task2> <task3>
# Tasks execute one at a time on current branch. Each sees previous task's commits.
# Use for dependent tasks (Phase 1 → Phase 2 → Phase 3). No PRs per task.

# Worker completes → orchestrator reconciles
/reconcile-summary → update beads → dispatch next batch

# Fully autonomous (parallel)
/auto-run --through <target-task>
# Or unattended: ~/.claude/scripts/auto-run.sh --max-hours 8
# Auto-run includes milestone review after tasks complete (skip with --skip-milestone-review)

# Fully autonomous (sequential — for dependent task chains)
/auto-run --sequential --through <target-task>

# Milestone review (standalone — on any branch with accumulated changes)
/milestone-review --base-branch main
/milestone-review --dry-run              # report findings without fixing
/milestone-review --max-iterations 3     # limit review-fix cycles

# IMPORTANT: Before ending an orchestrator session, always run:
/reconcile-summary
```

## Beads Task Management

Tasks are managed with `bd` (beads CLI):

```bash
bd ready                    # Show tasks ready to work
bd list                     # All open tasks
bd show <id>                # Task details
bd create --title="..." --type=task --priority=2 --parent <epic-id>
bd update <id> --status=in_progress
bd close <id>
bd sync --flush-only        # Export to JSONL
```

Quality gate hooks enforce workflow discipline. See `hooks/` for implementation.
