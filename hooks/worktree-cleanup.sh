#!/bin/bash
# Prunes orphaned git worktrees on session start.
# Workers that crash or context-exhaust before /finish-task leave
# stale worktrees on disk. This hook garbage-collects them.
#
# Runs as a SessionStart hook — cheap, automatic, prevents accumulation.
# Exit 0 always (cleanup is best-effort, never blocks session start).

# Prune git's worktree registry (removes entries for deleted directories)
git worktree prune 2>/dev/null

# Remove worktree directories older than 1 day from Claude's worktree cache
if [ -d "$HOME/.claude/worktrees" ]; then
  find "$HOME/.claude/worktrees" -maxdepth 1 -mindepth 1 -type d -mtime +1 -exec rm -rf {} + 2>/dev/null
fi

exit 0
