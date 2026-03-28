#!/bin/bash
# Blocks teammates from going idle without a session summary.
# Used as a TeammateIdle hook — fires when any teammate is about to go idle.
#
# Only enforces for task-assigned teammates (name contains hyphen like "INT-14").
# Non-task teammates (research, investigative, manually-spawned) pass through.
#
# Exit 0 = allow idle, Exit 2 = block with feedback on stderr

INPUT=$(cat)
TEAMMATE_NAME=$(echo "$INPUT" | jq -r '.teammate_name // empty')

# Safety: can't determine teammate → allow idle
[ -n "$TEAMMATE_NAME" ] || exit 0

# Only enforce for task-assigned teammates (name contains hyphen like "INT-14")
echo "$TEAMMATE_NAME" | grep -q '-' || exit 0

# Find main repo root (summaries live there, not in worktrees)
MAIN_REPO=$(git worktree list 2>/dev/null | head -1 | awk '{print $1}')
[ -n "$MAIN_REPO" ] || exit 0

# If project doesn't use session summaries dir, don't enforce
[ -d "$MAIN_REPO/docs/session_summaries" ] || exit 0

# Check for session summary file
if ls "$MAIN_REPO"/docs/session_summaries/${TEAMMATE_NAME}_*.txt >/dev/null 2>&1; then
  exit 0
fi

echo "No session summary found for task '${TEAMMATE_NAME}'." >&2
echo "Run /finish-task ${TEAMMATE_NAME} before stopping." >&2
echo "If blocked, message the team lead explaining why." >&2
exit 2
