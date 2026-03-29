# Workflow Cheatsheet

```bash
# Explore UI directions before committing to a plan
/design-shotgun → /product-review DESIGN → /spec → /orient → /dispatch

# Plan a new project (review runs automatically for all plans in Phase 2.5)
/spec → /orient → /dispatch

# Plan a UI feature (product review explores scope before spec)
/product-review DESIGN → /spec → /orient → /dispatch

# Deep-dive reviews on existing plans (standalone — for extra depth beyond Phase 2.5)
/plan-eng-review              # Full interactive engineering review (4 sections)
/plan-design-review           # Full 7-pass scored design review

# Single session
/orient → /start-task <id> → implement → /finish-task <id>

# Optional release-confidence pass before closing risky work
/qa → /finish-task <id>

# Validate a performance claim with measured evidence
/benchmark "pnpm test:bench"

# Parallel sessions (worktree-isolated workers)
/orient → /dispatch --count 3
# Workers auto-spawn in isolated worktrees, run /start-task, implement, run /finish-task

# Sequential sessions (direct on branch, no worktrees)
/orient → /dispatch --sequential <task1> <task2> <task3>
# Tasks execute one at a time on current branch. Each sees previous task's commits.
# Use for dependent tasks (Phase 1 → Phase 2 → Phase 3). No PRs per task.

# Worker completes → orchestrator reconciles
/reconcile-summary → update task board → dispatch next batch

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

## Task Tracking

### With Linear (if MCP connected)

Tasks are managed via Linear MCP tools:

```
list_issues(state=Todo)                          # Ready tasks (filter by empty blockedBy)
get_issue(id=INT-14, includeRelations=true)      # Task details with dependencies
save_issue(title=..., team=..., project=...)     # Create issue
save_issue(id=INT-14, state="In Progress")       # Claim task
save_issue(id=INT-14, state=Done)                # Close task
save_issue(id=INT-15, blockedBy=[INT-14])        # Set dependency (append-only)
save_comment(issueId=INT-14, body="...")          # Add session summary
```

### Without Linear (plan-file workflow)

No task tracker needed. `/spec` writes plan files to `docs/plans/`. Execute directly from the plan:

```bash
/spec "feature description"    # Writes docs/plans/<plan>.md
# Read the plan, implement each section
/finish-task                   # Tests, commit, PR (skips task tracking)
```

Quality gate hooks enforce workflow discipline. See `hooks/` for implementation.
