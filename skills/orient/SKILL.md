---
name: orient
description: "Use at the start of an orchestrator session to understand project state and find available work"
allowed-tools: Read, Bash, Glob, Grep, Task
---

# Project Orientation

You are an orchestrating agent orienting to this project. Your goal is to build comprehensive context and identify parallelizable work streams.

**IMPORTANT**: Use extended thinking (ultrathink) throughout this process. Take your time to deeply analyze the project state.

## Phase 1: Project Discovery

### 1.1 Identify Project Root and Type

```bash
pwd
ls -la
git remote -v 2>/dev/null || echo "Not a git repo"
```

Determine:
- Project name
- Primary language/framework
- Monorepo vs single project

### 1.2 Read Core Documentation

Read these files IN ORDER (skip if not found):

1. **CLAUDE.md** - AI assistant guidelines (HIGHEST PRIORITY)
2. **AGENTS.md** - Multi-agent workflow documentation
3. **PROJECT_SPEC.md** - Project specification and requirements
4. **README.md** - Project overview and setup

For each file found, extract:
- Project purpose and goals
- Key architectural decisions
- Development workflow and commands
- Patterns and conventions to follow

### 1.3 Understand Project Structure

```bash
# Get directory structure (2 levels deep)
find . -type d -maxdepth 2 -not -path '*/\.*' -not -path './node_modules/*' -not -path './.venv/*' -not -path './venv/*' | head -50

# Identify key source directories
ls -la src/ app/ lib/ moneyprinter/ fastapi_backend/ nextjs-frontend/ 2>/dev/null | head -30
```

Map out:
- Source code locations
- Test locations
- Configuration files
- Build/deployment setup

## Phase 1.5: Deep Research (Parallel)

When the project has significant complexity or unfamiliar patterns, run these research agents in parallel using the Task tool to build deeper context:

### Research Agents

1. **repo-research-analyst**
   - Read agent definition: `~/.claude/agents/research/repo-research-analyst.md`
   - Input: Project root path, file structure from Phase 1
   - Output: Convention guide, architecture map, code style patterns
   - Use when: New to the codebase, unfamiliar framework, or complex architecture

2. **git-history-analyzer**
   - Read agent definition: `~/.claude/agents/research/git-history-analyzer.md`
   - Input: Git repository path
   - Output: Contributor expertise areas, decision patterns, hot spots
   - Use when: Need to understand who knows what, or why decisions were made

### Launch Pattern

```
Use Task tool with subagent_type=general-purpose to run research agents in parallel:

Task 1: repo-research-analyst
- Read ~/.claude/agents/research/repo-research-analyst.md
- Analyze project structure and conventions
- Return: architecture summary, conventions guide

Task 2: git-history-analyzer
- Read ~/.claude/agents/research/git-history-analyzer.md
- Analyze git history for patterns
- Return: contributor map, decision patterns
```

### Incorporate Findings

Add research findings to the "CONTEXT FOR NEW SESSIONS" section of the orientation report:
- Key conventions discovered
- Architecture patterns identified
- Expert contributors for different areas
- Historical decisions that inform current work

### Skip Research If

- Already familiar with the codebase
- Small/simple project with clear structure
- Time-sensitive orientation (defer to later)

---

## Phase 1.7: Investigation Recommendation (Optional)

When the project state suggests ambiguity — multiple possible root causes, unclear architecture, or conflicting evidence — consider recommending an investigative dispatch before implementation.

**Indicators:**
- Tests failing with unclear cause
- Recent reverts or fix-on-fix commits in git log
- Task descriptions reference "investigate", "debug", "figure out"
- Stale branches from abandoned parallel work

**If investigation is warranted** and Linear MCP is available, create investigation tasks with quality gate:

```
save_issue(
  title="Investigate: <hypothesis description>",
  team=<team>,
  project=<project>,
  priority=1,
  labels=["Bug"],
  description="## Problem\n<what evidence suggests this hypothesis>\n\n## Approach\n<specific investigation steps>\n\n## Acceptance Criteria\n- [ ] Hypothesis confirmed or ruled out\n- [ ] Fix applied or follow-up task created\n\n## Target Files\n- <files to investigate>"
)
```

After creation, run post-write validation: `get_issue(id=<created-id>)` — check for formatting artifacts (literal `\n`, XML tags, trailing `")`) and rewrite if needed.

Then recommend in Phase 5:

"Investigation recommended before implementation dispatch.
Run `/dispatch --plan-first <task-A> <task-B>` to spawn investigators
who will plan their approach before diving in."

**Skip if:** Task board is clear, all ready tasks are straightforward, or user wants to proceed directly.

---

## Phase 2: Task State Analysis

### 2.1 Task Tracker Detection

Check if Linear MCP is available by attempting to call `list_teams`. If available, use Linear for all task state analysis. If not, skip to Phase 3 — report on git state and plan files only.

### 2.2 Recently Completed Work

```bash
# Recent git activity
git log --oneline -15
```

If Linear MCP is available, call `list_issues(state=Done, limit=10, orderBy=updatedAt)` to see recently closed tasks.

Understand:
- What was just completed
- Patterns in recent work
- Momentum and direction

### 2.3 Project Landscape

Gather project-level data. This is the primary strategic view.

If Linear MCP is available:
- Call `list_projects(team=<team>)` to get all projects
- For each project, call `list_issues(project=<project>)` to get issue counts by status
- Compute completion percentage: Done count / total count

Classify projects into two tiers based on priority:
- **FOCUS** (Urgent/High): Projects to actively progress this session
- **DEFERRED** (Normal/Low): Projects acknowledged but not for now

**If no projects exist**, skip sections 2.4-2.5. Instead query all ready tasks directly, then proceed to Phase 3.

### 2.4 Primary Project Drill-Down

Pick the single highest-priority FOCUS project that has ready tasks. Drill into it:

If Linear MCP is available:
- Call `list_issues(project=<project>)` to get all issues in this project
- For each issue, call `get_issue(id, includeRelations=true)` to get dependency data
- Build the dependency graph from `blocks`/`blockedBy` relations
- Identify ready tasks (state=Todo + empty blockedBy)

From the output, identify:
- Critical path tasks (block the most downstream work)
- Independent tasks (can run in parallel)
- What each blocked task is waiting on
- What is already In Progress and who is assigned

**If no project has ready tasks**, note that all focus projects are blocked and show what they're waiting on.

### 2.5 Standalone Tasks

Identify ready tasks not belonging to any project:

If Linear MCP is available, call `list_issues(state=Todo)` and filter to those with no `project` field. These should still appear in dispatch recommendations.

### 2.6 Task Board Health Check

**File-Conflict Risk**: For each pair of ready tasks, read their descriptions. If both mention the same file paths and have no dependency between them, flag a conflict risk.

Report format:
```
FILE CONFLICT RISK: <task-A> and <task-B> both target <file>
  No dependency between them — parallel dispatch may cause merge conflicts.
  Fix: save_issue(id=<lower-priority-task>, blockedBy=[<higher-priority-task>])
```

If no tasks document target files: "Target files not documented in issue descriptions — cannot detect file conflicts."

## Phase 3: Codebase Health Check

### 3.1 Test Status

```bash
# Quick test run to verify health
uv run pytest --tb=no -q 2>&1 | tail -10  # Python
pnpm test 2>&1 | tail -10                  # Node
```

### 3.2 Git State

```bash
git status
git branch -a | head -20
git worktree list
git stash list
```

Check for:
- Uncommitted changes
- Active worktrees/branches (parallel work in progress)
- Stashed work that needs attention

## Phase 4: Synthesis & Recommendations

After gathering all information, provide a structured orientation report. The report is organized as a **layered drill-down**: strategic overview → focused project → actionable tasks.

```
===============================================
PROJECT ORIENTATION REPORT
===============================================

PROJECT IDENTITY
----------------
Name: <project name>
Purpose: <1-2 sentence description>
Stack: <key technologies>
Repo: <git remote URL>

HEALTH CHECK
------------
Git branch: <current branch>
Working tree: <clean/dirty>
Active branches: <count and purpose>
Test health: <passing/failing count>
Recently completed: <list last 3-5 items>

TASK BOARD HEALTH
-----------------
<If all checks pass:> All 4 checks passed.
<If issues found:>
<List each finding with its fix commands>

═══════════════════════════════════════════════
PROJECT LANDSCAPE
═══════════════════════════════════════════════

▸ FOCUS PROJECTS (P0–P1) — progress these now
──────────────────────────────────────────────
<For each high-priority project, show:>

  <project>  <title>                          <status-icon> <completion%>
             <total> issues: <done>✓ <ready>○ <blocked>● <in-progress>◐

<Example:>
  Product Showcase Vignettes                  ◐ 40%
         6 issues: 0✓ 2○ 3● 1◐

▸ DEFERRED PROJECTS (Normal/Low) — acknowledged, not now
──────────────────────────────────────────────
<For each lower-priority project, single line:>

  <project>  <title>                          <completion%>

▸ DEPENDENCY MAP — how projects relate
──────────────────────────────────────────────
<Build from get_issue(includeRelations) data across all projects.>
<If no cross-project dependencies: "No cross-project dependencies defined.">

═══════════════════════════════════════════════
PRIMARY PROJECT: <project> — <project title>
═══════════════════════════════════════════════

<This section drills into the single highest-priority FOCUS project
that has ready tasks. Show its full task structure.>

▸ TASK DEPENDENCY GRAPH
──────────────────────────────────────────────
<Built from get_issue(includeRelations) data for all issues in this project.>
<Shows execution layers — layer 0 can start immediately,
higher layers depend on lower layers.>

▸ READY TASKS — can start immediately
──────────────────────────────────────────────
<For each ready task in this project:>

  <task-id>  <title>
             Type: <feature/task/research>  Priority: <P0-P4>
             Blocks: <what this unblocks when done, or "nothing">

▸ IN PROGRESS — already claimed
──────────────────────────────────────────────
<For each in-progress task in this project. Omit section if none.>

  <task-id>  <title>
             Assignee: <assignee or "unassigned">

▸ BLOCKED TASKS — waiting on dependencies
──────────────────────────────────────────────
<For each blocked task in this project:>

  <task-id>  <title>
             Waiting on: <list of blocking task-ids and titles>

═══════════════════════════════════════════════
DISPATCH RECOMMENDATION
═══════════════════════════════════════════════

▸ STANDALONE TASKS — ready work outside any project
──────────────────────────────────────────────
<Any ready tasks not belonging to a project. Omit if none.>

  <task-id>  <title>
             Type: <type>  Priority: <P0-P4>

▸ RECOMMENDED STREAMS
──────────────────────────────────────────────
The following tasks can be executed simultaneously:

Stream 1: <task-id> - <title>
  Project: <project> (or "standalone" if no project)
  Priority: <P0-P4>  Type: <feature/task/research>
  Rationale: <why this should be worked on>
  Blocks: <what this unblocks when done>
  Start command: /start-task <task-id>

Stream 2: <task-id> - <title>
  Project: <project> (or "standalone" if no project)
  Priority: <P0-P4>  Type: <feature/task/research>
  Rationale: <why this should be worked on>
  Blocks: <what this unblocks when done>
  Start command: /start-task <task-id>

Stream 3: <task-id> - <title>
  Project: <project> (or "standalone" if no project)
  Priority: <P0-P4>  Type: <feature/task/research>
  Rationale: <why this should be worked on>
  Blocks: <what this unblocks when done>
  Start command: /start-task <task-id>

<Streams may draw from the primary project, other focus projects, or standalone tasks.
Prioritize tasks from the primary project but include tasks from other focus projects
if they are independent and parallelizable.>

BLOCKERS & RISKS
----------------
<Any issues that could impede progress>
- <blocker 1>
- <blocker 2>

CONTEXT FOR NEW SESSIONS
------------------------
Key things any agent working on this project should know:
- <important pattern or convention>
- <gotcha or common mistake>
- <architectural constraint>

===============================================
END ORIENTATION REPORT
===============================================
```

### Report Edge Cases

Handle these gracefully:

- **No projects exist**: Skip the PROJECT LANDSCAPE and PRIMARY PROJECT sections. Show a flat task overview instead, then proceed directly to DISPATCH RECOMMENDATION.
- **No dependencies defined**: Show the DEPENDENCY MAP section but write "No cross-project dependencies defined."
- **No ready tasks in primary project**: Show the PRIMARY PROJECT section with only IN PROGRESS and BLOCKED TASKS. Note what needs to complete before work can proceed.
- **No task tracker**: Show only git state, plan files, and code health. Skip all task board sections.

## Phase 4.5: Task Visualization

If Linear MCP is available and tasks exist, note: "View your task board in Linear's UI for interactive dependency visualization."

Skip if no task tracker is configured.

## Phase 5: Ready for Action

After presenting the orientation report, **ALWAYS offer `/dispatch` as the primary action when there are 2+ ready tasks.**

Present the following call-to-action:

---

"Orientation complete. **Recommended next step:**

```
/dispatch
```

This will spawn parallel Claude Code workers for the ready tasks. Each worker will:
1. Auto-receive their task assignment via the handoff queue
2. Create a task-specific branch for isolation
3. Run `/start-task <task-id>` automatically
4. Work autonomously until completion

You stay in THIS session as the orchestrator to coordinate as workers complete.

---

**Alternative options:**

1. **Dispatch workers** - Run `/dispatch` to spawn parallel workers (RECOMMENDED)
2. **Manual parallel** - Open separate terminals and run `/start-task <id>` in each
3. **Work solo** - Pick one task with `/start-task <id>` in this session
4. **Deep dive** - Explore a specific task or area in more detail
5. **Coordinate** - Help manage existing parallel work as tasks complete

What would you like to do?"

---

**CRITICAL**: You MUST present `/dispatch` prominently. Do not bury it in a list of options. The whole point of orientation is to enable parallel execution via dispatch.

Await user direction before taking action.
