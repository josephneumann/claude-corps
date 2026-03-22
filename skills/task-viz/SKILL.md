---
name: task-viz
description: "Generate an interactive HTML visualization of beads tasks, dependencies, and status"
allowed-tools: Read, Bash, Write, Glob, Grep
---

# Task Visualization: $ARGUMENTS

Generate a self-contained interactive HTML page visualizing all beads tasks as a dependency DAG with status colors, epic grouping, and click-for-details. Uses the visual-explainer architecture template aesthetic (IBM Plex fonts, warm terracotta/sage palette, section cards, pipeline layout).

## Parse Arguments

- `$ARGUMENTS` may contain:
  - `--no-open` — generate the HTML but do NOT open in browser (used by /orient)
  - Empty — generate and open in browser

## Step 1: Gather Task Data

### 1.1 Verify beads is available

```bash
bd list --json --limit 0 2>/dev/null
```

If this fails, output "No beads project found or bd CLI not available." and STOP.

### 1.2 Parse the task list

The JSON output is an array of objects with fields:
- `id`, `title`, `description`, `status`, `priority`, `issue_type`
- `owner`, `created_at`, `updated_at`
- `dependency_count`, `dependent_count`

Note which tasks are epics (`issue_type == "epic"`).

### 1.3 Gather dependency edges

For each task where `dependency_count > 0` OR `dependent_count > 0`, run:

```bash
bd show <task-id> --json 2>/dev/null
```

From the output, extract:
- `dependencies[]` array — each has `id`, `dependency_type` ("parent-child" or "blocks")
- `dependents[]` array — each has `id`, `dependency_type`
- `parent` field — the parent epic ID (if any)

Build three data structures:
1. **Parent map**: task ID → parent epic ID (from `parent` field or parent-child dependencies)
2. **Blocking edges**: list of `[blocker_id, blocked_id]` pairs (from "blocks" type dependencies only)
3. **Task status map**: determine effective status for each task:
   - If task has unresolved blocking dependencies → `blocked`
   - If task status is `in_progress` → `progress`
   - If task status is `closed` or `done` → `done`
   - Otherwise → `ready`

## Step 2: Organize Layout

Group tasks into visual sections:

### 2.1 Identify dependency chains

Walk blocking edges to find linear chains (A → B → C). A chain is a sequence where each task blocks the next. These render as **pipeline** rows with arrow separators.

### 2.2 Identify independent ready tasks

Tasks with no blocking dependencies and not part of a chain go into a **"Ready to Work"** grid section.

### 2.3 Group by epic

Each epic gets a **hero section card** showing its title, description, and priority. Its child tasks appear in the chain/grid sections below it.

## Step 3: Generate HTML

**Do NOT use Mermaid.** Generate pure HTML/CSS using the visual-explainer architecture template patterns.

First ensure the output directory exists:
```bash
mkdir -p ~/.agent/diagrams
```

### 3.1 Reference Template

Read the visual-explainer architecture template for styling reference:
```
~/.claude/plugins/marketplaces/visual-explainer-marketplace/plugins/visual-explainer/templates/architecture.html
```

Use its exact CSS patterns:
- **Fonts**: IBM Plex Sans (body) + IBM Plex Mono (labels/code), loaded from Google Fonts
- **Colors**: Warm palette with CSS variables for light/dark themes. Use `@media (prefers-color-scheme: dark)` + `[data-theme]` attribute for manual toggle.
- **Background**: Asymmetric radial gradients (`radial-gradient(ellipse at 20% 0%, ...)`)
- **Section cards**: `.section` with `.section--hero` (elevated) variant, colored borders via `color-mix()`, dot labels
- **Inner cards**: `.inner-card` or task cards inside sections with `var(--surface2)` background
- **Flow arrows**: Centered SVG arrows between sections with mono-font labels
- **Pipeline**: Horizontal flex layout with arrow separators for dependency chains
- **Staggered animation**: `@keyframes fadeUp` with `animation-delay: calc(var(--i, 0) * 0.06s)`
- **Callout**: Left-accent-bordered card for actionable guidance

### 3.2 Page Structure

```
Page Header (h1 "Task Board", subtitle with date + theme toggle)
├── KPI Row (4 cards: Ready, In Progress, Blocked, Done — large numbers with colored dots)
├── For each epic:
│   ├── Hero Section Card (epic title, description, priority)
│   ├── Flow Arrow ("dependency chain")
│   ├── Section Card: Dependency Chain (pipeline layout with → arrows)
│   ├── Flow Arrow ("independent tasks")
│   └── Section Card: Ready to Work (grid of task cards)
├── Callout (next step guidance with command suggestions)
└── Detail Overlay (backdrop + slide-in panel, hidden until task card clicked)
```

### 3.3 KPI Cards

Top row of 4 cards showing counts with large numbers (28px+) and colored status dots:
- **Ready**: teal — tasks with no blocking deps, open status
- **In Progress**: amber/orange — tasks with `in_progress` status
- **Blocked**: terracotta/red — tasks with unresolved blocking deps
- **Done**: green — closed/done tasks

### 3.4 Task Cards

Each task renders as an interactive card with:
- **Task ID**: mono font, colored by status (teal=ready, orange=blocked, etc.)
- **Title**: 13px semibold
- **Tags**: status badge (with dot indicator), priority, type
- **Click handler**: `onclick="showDetail('task-id')"`
- **Hover**: subtle border highlight + shadow + translateY(-1px)
- **Active**: accent-colored border when selected

Status color mapping for task card IDs and tags:
- `ready` → teal (`--ready: #0d9488`)
- `progress` → amber (`--progress: #b45309`)
- `blocked` → terracotta (`--blocked: #c2410c`)
- `done` → sage green (`--done: #4d7c0f`)

### 3.5 Detail Panel

An overlay with backdrop that slides in from the right when a task card is clicked:
- **Backdrop**: semi-transparent black, click to dismiss
- **Panel**: 420px wide, slides in with `cubic-bezier(0.16, 1, 0.3, 1)` easing
- **Content**: Task ID (mono, accent color), full title (20px bold), status/priority/type tags, full description (pre-wrap), blocked-by list, blocks list, owner, created date
- **Dependency items**: Cards with mono-font ID + title, hover highlight
- **Close**: X button + Escape key

### 3.6 JavaScript

Embed all task data as a `const taskData = { ... }` object in a `<script>` tag. Include:
- `showDetail(taskId)` — populates and opens the detail panel
- `closePanel()` — hides the overlay
- `toggleTheme()` — flips `data-theme` attribute between `light` and `dark`
- `esc(str)` — HTML-escape function using `document.createElement('div').textContent`
- Keyboard listener for Escape to close panel
- Active card highlight management (add/remove `.active` class)

### 3.7 Callout

At the bottom, a callout card suggesting next actions:
- If ready tasks exist: suggest `/dispatch` for parallel workers
- If a dependency chain exists: suggest `/dispatch --sequential` with the chain task IDs

## Step 4: Write and Open

1. Write the complete HTML to `~/.agent/diagrams/task-board.html` using the Write tool
2. If `--no-open` was NOT passed, open in browser:
   ```bash
   open ~/.agent/diagrams/task-board.html
   ```
3. Output: `"Task board generated: ~/.agent/diagrams/task-board.html"`

## Edge Cases

- **Zero tasks**: Generate valid HTML with a centered message: "No tasks found. Create tasks with `bd create`."
- **Single task, no deps**: Render one task card in a "Ready to Work" section. No pipeline.
- **Multiple epics**: Repeat the epic → chain → grid pattern for each epic. Separate with flow arrows.
- **Task title with special chars**: The `esc()` JS function handles HTML escaping. For task data embedded in JS, escape quotes and backslashes.
- **Very long descriptions**: Detail panel has `overflow-y: auto`.
- **Mixed open/closed tasks**: Show all. Done tasks use green styling.
- **Orphan tasks (no parent epic)**: Group under a "Standalone Tasks" section (no hero card).
- **No dependency chains**: Skip the pipeline section, show all tasks in the grid.
- **Multiple independent chains in one epic**: Show each chain as a separate pipeline row.
