#!/bin/bash
# Blocks task completion without a session summary.
# Used as a TaskCompleted hook — fires when a task is marked completed.
#
# Uses teammate_name (which is the task ID set by /dispatch) rather than
# the Agent Teams internal numeric task_id.
#
# Only enforces for task-assigned teammates (name contains hyphen like "INT-14").
# If teammate_name is absent (lead's own task, or non-team), allows completion.
#
# Exit 0 = allow completion, Exit 2 = block with feedback on stderr

INPUT=$(cat)
TEAMMATE_NAME=$(echo "$INPUT" | jq -r '.teammate_name // empty')

# No teammate context (lead's own task, or non-team) → allow
[ -n "$TEAMMATE_NAME" ] || exit 0
echo "$TEAMMATE_NAME" | grep -q '-' || exit 0

MAIN_REPO=$(git worktree list 2>/dev/null | head -1 | awk '{print $1}')
[ -n "$MAIN_REPO" ] || exit 0
[ -d "$MAIN_REPO/docs/session_summaries" ] || exit 0

if ls "$MAIN_REPO"/docs/session_summaries/${TEAMMATE_NAME}_*.txt >/dev/null 2>&1; then
  exit 0
fi

echo "Cannot complete task: no session summary for '${TEAMMATE_NAME}'." >&2
echo "Run /finish-task ${TEAMMATE_NAME} first." >&2
exit 2
