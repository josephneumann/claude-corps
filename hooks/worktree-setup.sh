#!/bin/bash
# Runs automatically when any worktree is created (native or manual)
# Registered as a WorktreeCreate hook in ~/.claude/settings.json
# Receives JSON on stdin with: name, cwd

INPUT=$(cat)
WORKTREE_DIR=$(echo "$INPUT" | jq -r '.cwd')
MAIN_REPO=$(cd "$WORKTREE_DIR" && git worktree list | head -1 | awk '{print $1}')

# 1. Symlink .env files from main repo
for envfile in "$MAIN_REPO"/.env "$MAIN_REPO"/.env.*; do
  if [ -f "$envfile" ]; then
    filename=$(basename "$envfile")
    [ ! -e "$WORKTREE_DIR/$filename" ] && ln -sf "$envfile" "$WORKTREE_DIR/$filename"
  fi
done

# 2. Ensure .claude/worktrees/ is in .gitignore
if [ -f "$MAIN_REPO/.gitignore" ]; then
  grep -q '\.claude/worktrees/' "$MAIN_REPO/.gitignore" || \
    echo ".claude/worktrees/" >> "$MAIN_REPO/.gitignore"
fi

exit 0
