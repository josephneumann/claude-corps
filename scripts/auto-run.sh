#!/bin/bash
# Autonomous orchestrator wrapper — restarts claude across context exhaustions.
#
# Uses `expect` to allocate a pty for interactive Claude Code sessions.
# The wrapper spawns Claude interactively via expect, sends the /auto-run
# command, and waits for the process to exit. Workers run as subagents
# with worktree isolation (no Agent Teams dependency).
#
# Usage:
#   scripts/auto-run.sh [--through <id>] [--epic <id>] [--only <ids>]
#                       [--max-hours H] [--max-batches N] [--max-concurrent N]
#
# Prerequisites: expect (brew install expect / apt install expect)

set -euo pipefail

# Verify expect is available
if ! command -v expect &>/dev/null; then
  echo "Error: 'expect' is required but not installed."
  echo "Install with: brew install expect (macOS) or apt install expect (Linux)"
  exit 1
fi

# Note: Linear MCP is checked by the /auto-run skill itself.
# No CLI dependency check needed here.

SKILL_ARGS=""
LOG_DIR="docs/auto-run-logs"
CHECKPOINT="docs/auto-run-checkpoint.json"
ITERATION=0
START_TIME=$(date +%s)

# Pass all arguments through to the /auto-run skill
SKILL_ARGS="$*"

mkdir -p "$LOG_DIR"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_DIR/auto-run.log"
}

has_remaining_work() {
  # Check checkpoint file for task state — the /auto-run skill tracks this
  if [ -f "$CHECKPOINT" ]; then
    local status
    status=$(jq -r '.status // "unknown"' "$CHECKPOINT" 2>/dev/null)
    [ "$status" = "running" ]
  else
    # No checkpoint means first run — assume work exists
    true
  fi
}

checkpoint_status() {
  if [ -f "$CHECKPOINT" ]; then
    jq -r '.status // "unknown"' "$CHECKPOINT" 2>/dev/null
  else
    echo "none"
  fi
}

log "=== Auto-run wrapper started ==="
log "Args: $SKILL_ARGS"

while true; do
  ITERATION=$((ITERATION + 1))

  # Check if there's remaining work
  if ! has_remaining_work; then
    log "No remaining work. All done."
    break
  fi

  # Check checkpoint status — stop if completed or paused
  STATUS=$(checkpoint_status)
  if [ "$STATUS" = "completed" ] || [ "$STATUS" = "paused" ]; then
    log "Checkpoint status is '$STATUS'. Stopping."
    break
  fi

  ITER_LOG="$LOG_DIR/iteration-${ITERATION}.log"
  log "=== Iteration $ITERATION starting ==="

  # Build the command — first iteration uses raw args, subsequent use --resume
  if [ "$ITERATION" -eq 1 ]; then
    COMMAND="/auto-run $SKILL_ARGS"
  else
    COMMAND="/auto-run --resume $SKILL_ARGS"
  fi

  # Launch Claude in a pty via expect, send /auto-run command
  # timeout -1 means wait indefinitely for Claude to exit naturally
  expect <<EXPECT_EOF 2>&1 | tee "$ITER_LOG" || true
    set timeout -1
    spawn claude --dangerously-skip-permissions
    sleep 2
    send "$COMMAND\r"
    expect eof
EXPECT_EOF

  # Let file writes settle
  sleep 3
  log "=== Iteration $ITERATION complete ==="

  # Safety: check if checkpoint was set to errored
  STATUS=$(checkpoint_status)
  if [ "$STATUS" = "errored" ]; then
    log "Checkpoint status is 'errored'. Stopping for human review."
    break
  fi
done

ELAPSED=$(( ($(date +%s) - START_TIME) / 60 ))
log "Auto-run wrapper finished after $ITERATION iteration(s)"
log "Elapsed: ${ELAPSED} minutes"
log "Final checkpoint status: $(checkpoint_status)"
