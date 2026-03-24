# Skills & Agents Reference

All workflow capabilities are implemented as skills in `skills/`.

## Planning Pipeline

| Skill | Purpose | When to Use |
|-------|---------|-------------|
| `/product-review` | Product-taste review: EXPAND / HOLD / REDUCE / DESIGN modes | Before `/spec` for greenfield features, or standalone. Use DESIGN for UI-heavy features. |
| `/spec` | Research, plan, decompose into tasks | New idea, feature description, or goal |
| `/spec --deepen` | Enhance plan with parallel research agents | Existing plan needs more depth |
| `/plan-eng-review` | Interactive engineering plan review: architecture, code quality, tests, performance. One issue per question. | Core checks (scope, tests, failure modes) run automatically in `/spec` Phase 2.5. Use standalone for full-depth deep-dive on any plan. |
| `/plan-design-review` | Scored design plan review: 7 UI/UX dimensions rated 0-10 with fixes | Core checks (interaction states, AI slop risk) run automatically in `/spec` Phase 2.5 for UI plans. Use standalone for full 7-pass deep-dive. |

## Execution

| Skill | Purpose | When to Use |
|-------|---------|-------------|
| `/orient` | Build context, identify parallel work | Session start |
| `/start-task <id>` | Claim task, gather context, define criteria | Beginning a task |
| `/finish-task <id> [--direct]` | Tests, commit, PR, cleanup, close. `--direct` skips PR for sequential tasks. | Task complete |
| `/dispatch [--sequential]` | Spawn workers. Default: parallel (worktree-isolated). `--sequential`: one at a time on current branch. | Multiple ready tasks |
| `/auto-run [--sequential]` | Autonomous dispatch-reconcile loop. `--sequential` for dependent task chains. | Batch processing, overnight runs |
| `/milestone-review` | Iterative review-fix loop for branch changes | After milestone tasks complete, or manually |
| `/summarize-session <id>` | Progress summary (read-only) | Mid-session checkpoint |
| `/reconcile-summary` | Sync beads with implementation reality | After worker completes |

## Quality

| Skill | Purpose | Triggers |
|-------|---------|----------|
| `/multi-review` | Parallel code review with specialized agents | "thorough review", PR review, explicit |

## Utility

| Skill | Purpose | When to Use |
|-------|---------|-------------|
| `/retro` | Git-based engineering retrospective with trend tracking | Weekly review, shipping metrics, work patterns |
| `/humanizer` | Remove AI writing patterns | Text sounds like AI slop |
| `/claudemd-audit` | Audit CLAUDE.md for bloat, staleness, architecture | Reviewing CLAUDE.md quality, new project setup |
| Playwright MCP | Workflow-based browser testing (cache clear, diff inference, interaction, persistence checks) | `/finish-task`, `/multi-review`, `/milestone-review` — see `docs/browser-testing-protocol.md` |

## Discipline

| Skill | Purpose | When to Use |
|-------|---------|-------------|
| `/verify` | Evidence before claims, anti-sycophancy | Cross-referenced by other skills; invoke when making completion claims |
| `/debug` | Systematic debugging methodology | Bug, test failure, unexpected behavior |
| `/writing-skills` | Skill authoring guidance | Creating or revising a skill definition |

## Research Agents

Available in `/orient` (Phase 1.5) and `/start-task` (Step 5.5) for complex tasks:

| Agent | Purpose |
|-------|---------|
| `repo-research-analyst` | Map architecture, conventions |
| `git-history-analyzer` | Historical context, contributors |
| `framework-docs-researcher` | Library docs, deprecation checks |
| `best-practices-researcher` | Industry patterns, recommendations |

## Review Agents

**Review** (`/multi-review`): `code-simplicity-reviewer`, `security-sentinel`, `api-security-reviewer`, `performance-oracle`, `pattern-recognition-specialist`, `architecture-strategist`, `agent-native-reviewer`, `data-integrity-guardian`, `data-migration-expert`. Framework-specific (`nextjs-reviewer`, `tailwind-reviewer`, `python-backend-reviewer`, `ux-reviewer`, `frontend-performance-reviewer`) auto-detect from changed files.

**Workflow**: `spec-flow-analyzer` — analyze specs for dependencies, gaps, feasibility.

## Project Configuration

Optional `.claude/review.json` configures risk tiers and reviewer overrides for `/multi-review` and `/dispatch`. See `docs/examples/review-fullstack.json` for examples.
