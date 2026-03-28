---
name: auto-run
description: "Autonomous dispatch-reconcile loop for batch task processing. Use with /auto-run --through <id> to execute tasks unattended. Requires Linear MCP or tasks to exist. Supports --resume for checkpoint recovery and --skip-milestone-review."
allowed-tools: Bash, Read, Glob, Grep, Write, Edit, Skill, Agent, AskUserQuestion
---

# Autonomous Orchestrator Loop: $ARGUMENTS

You are an autonomous orchestrator. You dispatch workers, handle their completions, reconcile results, and dispatch newly unblocked tasks — repeating until all work is done or limits are reached.

Workers run in isolated git worktrees via the Agent tool. Each worker gets its own filesystem — no conflicts possible.

## Section 1: Argument Parsing

Arguments: `$ARGUMENTS`

Parse the following flags:
- `--max-batches N` — Stop after N dispatch rounds (default: unlimited)
- `--max-hours H` — Stop after H hours (default: unlimited)
- `--max-concurrent N` — Max parallel workers per batch (default: 3)
- `--sequential` — Execute tasks one at a time directly on the current branch (no worktrees, no PRs per task). Use for dependent/sequential tasks. Passes `--sequential` to `/dispatch`.
- `--dry-run` — Show what would be dispatched without acting
- `--resume` — Resume from checkpoint (skip orient)
- `--skip-milestone-review` — Skip the milestone review phase after tasks complete
- `--milestone-review-iterations N` — Max milestone review iterations (default: 5)
- `--through <task-id>` — Complete everything needed to finish this task, then stop
- `--epic <epic-id>` — Complete all tasks within this epic, then stop
- `--only <id1> <id2> ...` — Only dispatch these specific tasks (and their blockers)

## Section 2: Initial Setup

### Check for Checkpoint

Read checkpoint at `docs/auto-run-checkpoint.json` (resolve from main repo root via `git worktree list | head -1 | awk '{print $1}'`).

**If `--resume` AND checkpoint exists with status "running":**
1. Read checkpoint state (including scope config)
2. Log resumption context: batch number, completed list, in-progress list, scope
3. Check if any previously in-progress tasks have since completed — look for session summaries:
   ```bash
   ls docs/session_summaries/<task-id>*.txt 2>/dev/null
   ```
4. If summaries found → reconcile them first:
   Call `/reconcile-summary --yes` via Skill tool
5. Skip orient, proceed to dispatch loop (Section 3)

**If fresh start (no checkpoint or no `--resume`):**
1. Run `/orient` via Skill tool
2. Resolve scope (see Section 2.1)
3. Write initial checkpoint

Write checkpoint JSON to `docs/auto-run-checkpoint.json` with:
- `version`: 2
- `status`: "running"
- `start_time`: current ISO8601 timestamp
- `config`: parsed flags (max_batches, max_hours, max_concurrent)
- `scope`: resolved scope (see 2.1)
- `batch_number`: 0
- `tasks`: { completed: [], failed: [], in_progress: [] }
- `stats`: { total_dispatched: 0, total_completed: 0, total_failed: 0, total_batches: 0 }

### 2.1 Resolve Scope

Determine which tasks are in-scope for this auto-run:

**If `--through <task-id>`:**
Walk the dependency graph backward from `<task-id>` to find all transitive blockers. Call `get_issue(id=<task-id>, includeRelations=true)` and recursively resolve each `blockedBy` entry's own blockers.

Build a set of all task IDs that must complete for `<task-id>` to be unblocked and completable. Include `<task-id>` itself. Store as `scope.task_ids` in checkpoint. Set `scope.mode` to "through" and `scope.target` to `<task-id>`.

**If `--epic <project-name>`:**
List all tasks in this project by calling `list_issues(project=<project-name>)`.

Store all issue IDs as `scope.task_ids`. Set `scope.mode` to "epic" and `scope.target` to `<project-name>`.

**If `--only <id1> <id2> ...`:**
Use exactly those task IDs. Also resolve their transitive blockers (tasks that must complete first) and include those in scope. Store as `scope.task_ids`. Set `scope.mode` to "only".

**If no scope flags:**
`scope.task_ids` = null (all ready tasks are in scope). Set `scope.mode` to "all".

Log the resolved scope:
```
Auto-run scope: N tasks [list IDs]. Target: <task-id or epic-id or "all">
```

### First Dispatch

1. Query ready tasks: call `list_issues(state=Todo)`, then for each call `get_issue(includeRelations=true)` and filter to those with empty `blockedBy` arrays
2. Filter ready tasks to only those in `scope.task_ids` (if set; if null, use all)
3. If no in-scope ready tasks:
   - Check if target task is already closed → exit with completion report
   - Otherwise report "No ready tasks in scope" and exit
4. If ready tasks exist:
   - Calculate count = min(ready_count, max_concurrent)
   - **If `--sequential`:** Call `/dispatch --sequential <specific-task-ids> --no-plan --yes` via Skill tool. This dispatches tasks one at a time in foreground (no worktrees). The orchestrator blocks until each task completes.
   - **If parallel (default):** Call `/dispatch <specific-task-ids> --count <count> --no-plan --yes` via Skill tool, passing only in-scope task IDs
5. Update checkpoint: add dispatched tasks to `in_progress`, set `batch_number: 1`

## Section 3: Main Loop

**If `--sequential`:** The loop is synchronous. Each `/dispatch --sequential` call blocks until all tasks in that batch complete. After completion, proceed directly to Step B (Reconcile) → Step B.5 (Pull) → Step D (Dispatch Next). No background notifications needed.

**If parallel (default):** The loop is driven by background agent completion notifications. When a worker finishes (you are notified of its completion), process the result:

### Step A — Identify Completion

When notified of a worker's completion, extract the task ID from the worker's name or result. Check for session summary:
```bash
ls docs/session_summaries/<task-id>*.txt 2>/dev/null
```

### Step B — Reconcile

**If summary exists:**
Call `/reconcile-summary <task-id> --yes` via Skill tool.

After reconciliation, check if the completed task touched frontend files:
```bash
# Check the session summary for frontend file extensions
grep -E '\.(tsx|jsx|vue|svelte|html|css|scss)' docs/session_summaries/<task-id>*.txt 2>/dev/null
```

If frontend files were modified, note for milestone review:
```
Frontend changes detected in <task-id> — Playwright browser verification will run during milestone review.
```

**If no summary (worker may have failed):**
1. Check the worker's return value for error information
2. Mark as failed
3. If Linear MCP is available, create investigation task with quality gate:
   ```
   save_issue(
     title="Investigate: <task-id> failed",
     team=<team>,
     priority=1,
     project=<project>,
     labels=["Bug"],
     description="## Problem\n<what the worker was attempting and how it failed>\n\n## Approach\nInvestigate root cause: check worker logs, git state, and error output.\n\n## Acceptance Criteria\n- [ ] Root cause identified\n- [ ] Fix applied or follow-up task created\n\n## Target Files\n- <files the failed task was working on>"
   )
   ```
   After creation, run post-write validation: `get_issue(id=<created-id>)` — check for formatting artifacts and rewrite if needed.

Update checkpoint: move task from `in_progress` to `completed` (or `failed`).

**Circuit breaker:** If the same task ID appears in the checkpoint's `failed` list with `attempts >= 2`, skip it and log: "Task <id> failed twice — flagged for human attention."

### Step B.5 — Pull and Clean Up

After reconciliation, pull changes so subsequent dispatches see the latest code:

**If `--sequential`:** No worktree prune needed (no worktrees created). Workers already committed directly to this branch, so `git pull` may not be necessary — but run it to sync with any remote changes:

```bash
git pull origin $(git branch --show-current) --rebase 2>/dev/null || true
```

**If parallel (default):** Prune completed worktrees and pull the worker's merged changes:

```bash
git worktree prune
git pull origin $(git branch --show-current)
```

### Step C — Check Limits

- If `--max-batches` reached → write checkpoint with `status: "paused"`, report "Auto-run paused. N tasks remain.", exit.
- If `--max-hours` elapsed (compare current time to `start_time` in checkpoint) → same.

### Step D — Dispatch Next Batch

1. Query ready tasks (same pattern as First Dispatch: list_issues + get_issue filter)
2. Filter to in-scope tasks only (if `scope.task_ids` is set in checkpoint)
3. Calculate `available_slots = max_concurrent - current_in_progress_count`

**If in-scope ready tasks AND available_slots > 0:**
- **If `--sequential`:** Call `/dispatch --sequential <specific-task-ids> --no-plan --yes` via Skill tool. This blocks until all tasks complete.
- **If parallel (default):** Call `/dispatch <specific-task-ids> --no-plan --yes` via Skill tool (pass only in-scope IDs, limited to available_slots)
- Increment `batch_number` in checkpoint
- Add dispatched tasks to `in_progress` in checkpoint

**Completion checks:**
- If `--through` target task is now closed → all done → go to Section 4 (Completion)
- If `--epic` and all epic children closed → all done → go to Section 4
- If no in-scope ready AND no in-progress → all done → go to Section 4
- If no in-scope ready BUT tasks still in-progress → wait for more completions (background agents will notify you when they finish; in `--sequential` mode this does not apply since dispatch blocks)

### Step E — Context Self-Monitoring

After every 3 reconciliation cycles, assess context health. If you notice degradation (losing track of state, responses feeling truncated, difficulty recalling earlier context):
1. Write checkpoint with `status: "running"` (preserving all current state)
2. Log: "Context limit approaching. Exiting for wrapper restart."
3. Exit gracefully — the wrapper script (if running) will restart with `--resume`

## Section 4: Completion

When no ready tasks AND no in-progress tasks (all work done):

1. **Final reconciliation:** Call `/reconcile-summary --yes` via Skill tool

### Step 1.5: Milestone Review Phase

After reconciliation, run an iterative review-fix pass on accumulated branch changes:

1. If `--skip-milestone-review` was passed: skip, log "Milestone review skipped by flag"
2. Detect milestone branch:
   ```bash
   git branch -r --list 'origin/milestone/*' | sort -V | tail -1
   ```
3. If no milestone branch found: skip, log "No milestone branch found — skipping milestone review"
4. Update checkpoint: `milestone_review.status: "in_progress"`
5. Dispatch a review worker using Agent tool:
   - `isolation: "worktree"`
   - `mode: "bypassPermissions"`
   - Prompt: Check out the milestone branch, run `/milestone-review --max-iterations <N> --base-branch main` (use `--milestone-review-iterations` value or default 5)
   - The worker pushes fixes directly to the milestone branch (no separate PR — the milestone-to-main PR is the human review checkpoint)
6. Wait for worker completion
7. Read the worker's report/session summary
8. Update checkpoint: `milestone_review.status: "completed"` with stats from the worker's report

2. **Write checkpoint** with `status: "completed"` and final stats
3. **Final report:**

```
═══════════════════════════════════════════
AUTO-RUN COMPLETE
═══════════════════════════════════════════
Duration: <elapsed time>
Batches: <count>
Completed: <count> tasks
Failed: <count> tasks

MILESTONE REVIEW:
- Status: <completed|skipped|N/A>
- Iterations: <count>
- Findings fixed: <count>
- Findings deferred: <count> (needs human decision)

COMPLETED:
- <task-id>: <title>
- ...

FAILED:
- <task-id>: <title> — <reason>
- ...

REMAINING (if any):
- <task-id>: <title>
- ...

═══════════════════════════════════════════
```

4. If Linear MCP is available, call `list_issues` to show final board state.

## Checkpoint Schema

File: `docs/auto-run-checkpoint.json`

```json
{
  "version": 2,
  "status": "running|completed|paused|errored",
  "start_time": "ISO8601",
  "last_updated": "ISO8601",
  "config": {
    "max_batches": null,
    "max_hours": null,
    "max_concurrent": 3,
    "execution_mode": "parallel|sequential"
  },
  "scope": {
    "mode": "all|through|epic|only",
    "target": "INT-14",
    "task_ids": ["INT-12", "INT-13", "INT-14"]
  },
  "batch_number": 2,
  "session_count": 1,
  "tasks": {
    "completed": [{ "id": "INT-12", "title": "...", "completed_at": "...", "batch": 1 }],
    "failed": [{ "id": "INT-14", "title": "...", "reason": "...", "attempts": 1 }],
    "in_progress": [{ "id": "INT-13", "title": "...", "dispatched_at": "...", "batch": 2 }]
  },
  "stats": {
    "total_dispatched": 4,
    "total_completed": 1,
    "total_failed": 0,
    "total_batches": 2
  },
  "milestone_review": {
    "status": "pending|in_progress|completed|skipped",
    "iterations": 0,
    "findings_fixed": 0,
    "findings_deferred": 0
  }
}
```

## Error Handling

- **Failed tasks**: If Linear MCP available, create investigation issues; otherwise log and continue
- **Circuit breaker**: Same task failing twice → skip and flag for human attention
- **No task tracker**: If Linear MCP is not available, exit with "No task tracker configured. Connect Linear MCP or use /dispatch manually."
- **Checkpoint corruption**: If checkpoint can't be parsed, start fresh (warn user)
