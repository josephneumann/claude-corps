#!/bin/bash
# Claude Config Installation Script
# Creates symlinks from ~/.claude/ to this repo

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"

echo "Installing Claude config from: $SCRIPT_DIR"
echo "Target directory: $CLAUDE_DIR"
echo ""

# Create ~/.claude if it doesn't exist
mkdir -p "$CLAUDE_DIR"

# Function to create symlink with backup
create_symlink() {
    local source="$1"
    local target="$2"
    local name="$(basename "$target")"

    if [ -L "$target" ]; then
        # Already a symlink - check if it points to the right place
        current_target="$(readlink "$target")"
        if [ "$current_target" = "$source" ]; then
            echo "✓ $name already linked correctly"
            return 0
        else
            echo "→ $name symlink exists but points elsewhere, updating..."
            rm "$target"
        fi
    elif [ -d "$target" ]; then
        # Directory exists - back it up
        backup="${target}.backup.$(date +%Y%m%d-%H%M%S)"
        echo "→ Backing up existing $name to $backup"
        mv "$target" "$backup"
    elif [ -e "$target" ]; then
        # Something else exists
        echo "✗ $target exists and is not a directory or symlink"
        return 1
    fi

    ln -s "$source" "$target"
    echo "✓ Linked $name → $source"
}

# Create symlinks
create_symlink "$SCRIPT_DIR/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
create_symlink "$SCRIPT_DIR/hooks" "$CLAUDE_DIR/hooks"
create_symlink "$SCRIPT_DIR/agents" "$CLAUDE_DIR/agents"
create_symlink "$SCRIPT_DIR/skills" "$CLAUDE_DIR/skills"
create_symlink "$SCRIPT_DIR/docs" "$CLAUDE_DIR/docs"
create_symlink "$SCRIPT_DIR/scripts" "$CLAUDE_DIR/scripts"

# Clean up legacy commands symlink if present
if [ -L "$CLAUDE_DIR/commands" ]; then
    rm "$CLAUDE_DIR/commands"
    echo "✓ Removed legacy commands symlink (migrated to skills)"
fi

# Register hooks in settings.json
SETTINGS_FILE="$CLAUDE_DIR/settings.json"

if [ -f "$SETTINGS_FILE" ]; then
    # Helper to register a hook if not already present
    register_hook() {
        local event="$1"
        local check_pattern="$2"
        local jq_expr="$3"
        local label="$4"

        if ! jq -e "$check_pattern" "$SETTINGS_FILE" > /dev/null 2>&1; then
            jq "$jq_expr" "$SETTINGS_FILE" > "${SETTINGS_FILE}.tmp" && mv "${SETTINGS_FILE}.tmp" "$SETTINGS_FILE"
            echo "✓ Registered $label"
        else
            echo "✓ $label already registered"
        fi
    }

    # PreToolUse: guard-main-branch
    register_hook "PreToolUse" \
        '.hooks.PreToolUse[] | select(.hooks[].command | test("guard-main-branch"))' \
        '.hooks.PreToolUse += [{"matcher": "Bash", "hooks": [{"type": "command", "command": "~/.claude/hooks/guard-main-branch.sh", "statusMessage": "Checking branch safety..."}]}]' \
        "PreToolUse guard-main-branch hook"

    # WorktreeCreate: worktree-setup
    register_hook "WorktreeCreate" \
        '.hooks.WorktreeCreate' \
        '.hooks.WorktreeCreate = [{"matcher": "", "hooks": [{"type": "command", "command": "~/.claude/hooks/worktree-setup.sh", "statusMessage": "Setting up worktree environment..."}]}]' \
        "WorktreeCreate hook"

    # TeammateIdle: teammate-idle-guard
    register_hook "TeammateIdle" \
        '.hooks.TeammateIdle' \
        '.hooks.TeammateIdle = [{"matcher": "", "hooks": [{"type": "command", "command": "~/.claude/hooks/teammate-idle-guard.sh", "statusMessage": "Checking session summary..."}]}]' \
        "TeammateIdle hook"

    # TaskCompleted: task-completed-guard
    register_hook "TaskCompleted" \
        '.hooks.TaskCompleted' \
        '.hooks.TaskCompleted = [{"matcher": "", "hooks": [{"type": "command", "command": "~/.claude/hooks/task-completed-guard.sh", "statusMessage": "Verifying task completion..."}]}]' \
        "TaskCompleted hook"

    # Stop: reconcile-reminder
    register_hook "Stop" \
        '.hooks.Stop' \
        '.hooks.Stop = [{"matcher": "", "hooks": [{"type": "command", "command": "~/.claude/hooks/reconcile-reminder.sh", "statusMessage": "Checking for unreconciled summaries..."}]}]' \
        "Stop reconcile-reminder hook"

else
    echo "⚠ No settings.json found at $SETTINGS_FILE — skipping hook registration"
    echo "  Create settings.json manually or run Claude Code to generate it"
fi

echo ""
echo "Installation complete!"
echo ""
echo "Verify with:"
echo "  ls -la ~/.claude/CLAUDE.md"
echo "  ls -la ~/.claude/hooks"
echo "  ls -la ~/.claude/agents"
echo "  ls -la ~/.claude/skills"
echo "  ls -la ~/.claude/docs"
echo "  ls -la ~/.claude/scripts"
