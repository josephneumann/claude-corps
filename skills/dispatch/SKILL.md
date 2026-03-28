---
name: dispatch
description: "Use when multiple tasks are ready and you want to assign them to workers. Supports parallel (worktree-isolated) and sequential (direct on branch) modes."
allowed-tools: Bash, Read, Glob, Grep, AskUserQuestion, Agent
---

# Dispatch Workers: $ARGUMENTS

You are an orchestrator dispatching workers for tasks. By default, each worker runs in its own git worktree for true filesystem isolation. With `--sequential`, workers execute directly on the current branch without worktrees.

## Parse Arguments

Arguments: `$ARGUMENTS`

Parse the following patterns:
- `--count N` — Auto-select N ready tasks
- `--sequential` — Execute tasks one at a time on the current branch (no worktree isolation, no PR per task). Use for dependent/sequential tasks that need to see each other's changes.
- `--plan-first` — Force all workers into plan approval mode
- `--no-plan` — Disable auto risk detection, all use bypassPermissions
- `--yes` — Skip dispatch confirmation (used by /auto-run for autonomous operation)
- `--model opus|sonnet` — Override model selection for all tasks
- `<task-id>` — Specific task to dispatch
- `<task-id>:"context"` — Task with custom context (e.g., `INT-15:"Use PriceCache"`)

If no arguments provided, default to `--count 3`.

## Step 1: Identify Tasks

**If `--count N` was specified (or defaulted):**

Query ready tasks: call `list_issues(state=Todo)` to get candidate tasks. For each, call `get_issue(id, includeRelations=true)` and filter to those with empty `blockedBy` arrays. These are the "ready" tasks.

Select the first N tasks that are:
- **High priority first** — Urgent > High > Normal > Low
- **Not already In Progress** — Only Todo/Backlog tasks with no blockers

**If specific tasks were provided:**

Validate each task exists by calling `get_issue(id=<task-id>, includeRelations=true)`.

## Step 2: Worktree Cleanup

**If `--sequential` was specified, skip this step** (no worktrees used).

Prune any orphaned worktrees before spawning new workers:

```bash
git worktree prune
git worktree list
```

## Step 2.1: Validate Sequential Prerequisites

**Only if `--sequential` was specified.**

```bash
CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" = "main" ] || [ "$CURRENT_BRANCH" = "master" ]; then
  echo "ERROR: Cannot use --sequential on main/master. Switch to a working branch first."
  # STOP — do not proceed
fi
echo "Sequential mode: tasks will execute directly on branch $CURRENT_BRANCH"
```

If on main/master, abort dispatch with a clear error. Sequential mode commits directly to the current branch — never to main.

## Step 2.5: Risk Assessment (Plan Mode Detection + Risk Tiers)

**Skip if `--no-plan` was specified.** If `--plan-first` was specified, mark ALL tasks `[PLAN]`.

### Risk Tier Configuration

First, check for a project-level review config:

```bash
cat .claude/review.json 2>/dev/null || cat .claude/risk-tiers.json 2>/dev/null || echo "No review config found"
```

**With review config:** Match task file paths (from issue description or related files) against tier patterns. The highest matching tier determines the task's risk level:

| Risk Tier | Dispatch Mode |
|-----------|---------------|
| critical | `[PLAN]` |
| high | `[PLAN]` |
| medium | `[AUTO]` |
| low | `[AUTO]` |

**Without review config (keyword fallback):** For each task, check its title + description (from `get_issue`) for high-risk keywords (case-insensitive):

- **Security**: `auth`, `authentication`, `authorization`, `encrypt`, `secret`, `password`, `token`, `credential`
- **Data**: `migration`, `migrate`, `schema change`, `drop table`, `delete data`
- **Financial**: `payment`, `billing`, `subscription`, `transaction`
- **Architectural**: `architecture`, `redesign`, `rewrite`, `refactor core`

Mark matching tasks `[PLAN]`, others `[AUTO]`.

## Step 2.7: Model Selection

**If `--model` flag was specified:** Use that model for ALL tasks (overrides all other logic).

**With review config:**

| Risk Tier | Model |
|-----------|-------|
| critical | opus |
| high | opus |
| medium | sonnet |
| low | sonnet |

**Without review config (keyword fallback):**
- Keywords `architecture`, `security`, `auth`, `migration`, `rewrite`, `redesign` in task title/description → `opus`
- Everything else → `sonnet`

Display the model in the dispatch summary: `[AUTO/sonnet]` or `[PLAN/opus]`.

## Step 3: Generate Context

For each task without explicit context:

1. Read the task details from `get_issue(id=<task-id>, includeRelations=true)`
2. Check what other tasks are currently in progress for situational awareness by calling `list_issues(state="In Progress")`
3. Look for related patterns in the codebase:
   - Check if similar files exist that the worker should follow
   - Look for recently completed dependencies
4. Generate a brief (1-2 sentence) context that helps the worker start faster

Example contexts:
- "Use sector_etfs.txt format from existing tickers/ directory"
- "Follow the pattern in backtesting/cache.py for data storage"
- "Depends on completed INT-14, can use its output"

## Step 4: Confirm Dispatch

Present a summary to the user:

**If `--sequential`:**
```
Ready to dispatch N tasks SEQUENTIALLY on branch <current-branch>:
(Tasks execute one at a time, directly on this branch — no worktrees, no PRs per task)

1. <task-id> (P1 <type>) [SEQ/opus]: <title>
   Context: "<generated or provided context>"

2. <task-id> (P2 <type>) [SEQ/sonnet]: <title>
   Context: "<generated or provided context>"

...
```

**If parallel (default):**
```
Ready to dispatch N workers (worktree-isolated):

1. <task-id> (P1 <type>) [PLAN/opus]: <title>
   Context: "<generated or provided context>"

2. <task-id> (P2 <type>) [AUTO/sonnet]: <title>
   Context: "<generated or provided context>"

...
```

The `[PLAN/AUTO/SEQ]` tags indicate dispatch mode. The `[opus/sonnet]` tags indicate the model selection from Step 2.7.

**If `--yes` was specified:**
Skip the AskUserQuestion confirmation and proceed directly to Step 5.

**Otherwise, use AskUserQuestion to confirm:**

Ask: "Confirm dispatch of N workers?"
- Options: "Yes, dispatch" / "No, cancel"
- multiSelect: false

**Wait for explicit user confirmation before proceeding.**

If user selects "No, cancel", abort dispatch.

## Step 5: Spawn Workers

**If `--sequential`: use the Sequential Spawn path below.**
**Otherwise: use the Parallel Spawn path (default).**

---

### Parallel Spawn (default)

Spawn each worker as a subagent with worktree isolation using the **Agent** tool. Launch all workers in a **single message** with multiple Agent tool calls for maximum parallelism.

For each task, use the Agent tool with:
- `isolation: "worktree"` — Each worker gets its own git worktree
- `run_in_background: true` — Workers run concurrently
- `mode: "bypassPermissions"` for `[AUTO]` tasks, `mode: "plan"` for `[PLAN]` tasks
- `model: "<selected>"` from Step 2.7
- `name: "<task-id>"` — Addressable by task ID

**Spawn prompt for `[AUTO]` tasks:**
```
You are an autonomous worker in your own isolated git worktree. Your task:

<task title and description from get_issue>

Context: <generated context>

Currently in progress (other workers): <list from list_issues state=In Progress, if any>

Instructions:
1. Run `/start-task <task-id>` to claim the task and verify your environment
2. Implement the task according to the acceptance criteria
3. Run `/finish-task <task-id>` when tests pass and implementation is complete

CRITICAL CONTRACT:
- You MUST run /finish-task before completing. A task without a session summary is invisible to coordination.
- If you cannot complete the task, write a partial session summary explaining why before exiting.
- Your worktree will be cleaned up automatically after you finish.
```

**Spawn prompt for `[PLAN]` tasks:**
```
You are an autonomous worker in your own isolated git worktree, spawned in PLAN MODE. Your task:

<task title and description from get_issue>

Context: <generated context>

Currently in progress (other workers): <list from list_issues state=In Progress, if any>

Instructions:
1. Run `/start-task <task-id>` to claim the task and gather context
2. Create a detailed implementation plan
3. Your plan will be reviewed before you can proceed to implementation
4. After approval, implement the task
5. Run `/finish-task <task-id>` when tests pass and implementation is complete

CRITICAL CONTRACT:
- You MUST run /finish-task before completing. A task without a session summary is invisible to coordination.
- If you cannot complete the task, write a partial session summary explaining why before exiting.
- Your worktree will be cleaned up automatically after you finish.
```

---

### Sequential Spawn (`--sequential`)

Execute tasks **one at a time, in order**, directly on the current branch. Each worker sees the previous worker's commits.

**For each task in order**, use the Agent tool with:
- **NO** `isolation` parameter — worker shares the orchestrator's filesystem
- `run_in_background: false` — orchestrator waits for completion before starting the next task
- `mode: "bypassPermissions"` (sequential tasks are pre-approved by dispatch confirmation)
- `model: "<selected>"` from Step 2.7
- `name: "<task-id>"` — Addressable by task ID

**Sequential spawn prompt:**
```
EXECUTION_MODE: sequential
BRANCH: <current branch name>

You are an autonomous worker executing DIRECTLY on branch <current-branch>. No worktree isolation — your changes are immediately visible to the orchestrator and subsequent workers.

Your task:

<task title and description from get_issue>

Context: <generated context>

Instructions:
1. Run `/start-task <task-id>` to claim the task and verify your environment
   - You are already on the correct branch. Do NOT create a new task branch.
2. Implement the task according to the acceptance criteria
3. Run `/finish-task <task-id> --direct` when tests pass and implementation is complete
   - The --direct flag skips PR creation — your commits go directly to this branch.

CRITICAL CONTRACT:
- You MUST run /finish-task with the --direct flag before completing.
- If you encounter merge conflicts or cannot complete the task, STOP immediately and report why. Do NOT retry merge strategies.
- Your commits accumulate on this branch for later review via /milestone-review.
```

**After each sequential worker completes:**
1. Verify the worker exited successfully (check return value)
2. If the worker failed: **STOP the chain**. Report which task failed and which tasks remain. Do not dispatch the next task.
3. If the worker succeeded: proceed to the next task in the list.

**If all sequential tasks complete successfully:**
Proceed to Step 6.

---

## Step 6: Post-Dispatch Summary

**If `--sequential`:**

```
Sequential dispatch complete: N tasks executed on branch <current-branch>

Tasks completed:
1. <task-id> [SEQ/sonnet]: <title> ✓
2. <task-id> [SEQ/sonnet]: <title> ✓
...

All commits are on branch <current-branch>.
No PRs created — review accumulated changes with /milestone-review.

IMPORTANT: Before ending this session, run /reconcile-summary to sync
all worker results with the task board.
```

**If parallel (default):**

After all workers are spawned, provide a summary:

```
Dispatch complete: N workers spawned (worktree-isolated)

Workers:
1. <task-id> [AUTO/sonnet]: <title>
2. <task-id> [PLAN/opus]: <title>
...

Each worker has its own git worktree — no filesystem conflicts possible.

Workers will:
1. Run /start-task to claim the task
2. Implement the task
3. Run /finish-task when tests pass (creates PR, session summary)

Workers are running in the background. You will be notified as each completes.
After all workers finish, run /reconcile-summary to process their results.

IMPORTANT: Before ending this session, run /reconcile-summary to sync
all worker results with the task board.
```

## Error Handling

- **No ready tasks**: Suggest running `/orient` first to identify work
- **Task doesn't exist**: Skip it, warn the user, continue with valid tasks
- **All tasks invalid**: Abort with clear error message
- **Worker spawn fails**: Report the error, continue with remaining tasks
- **Sequential on main branch**: Abort with clear error — must be on a working branch
- **Sequential mid-chain failure**: Stop chain, report failed task and remaining tasks

## Examples

**Auto-select 3 tasks (default — parallel, worktree-isolated):**
```
/dispatch
```

**Auto-select specific count:**
```
/dispatch --count 5
```

**Specific tasks:**
```
/dispatch INT-15 INT-16
```

**With custom context:**
```
/dispatch INT-15:"Use existing ticker format"
```

**Force all tasks to use Opus:**
```
/dispatch --count 3 --model opus
```

**Sequential execution (tasks run one at a time on current branch):**
```
/dispatch --sequential INT-14 INT-15 INT-16
```

**Sequential with auto-run (autonomous):**
```
/dispatch --sequential --count 3 --yes
```
