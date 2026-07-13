# Bug: Replace ASCII box art with plain markdown in main pane

## Context

Plugin at `/Users/q/code/experiments/nvim-agent-panel/`. Main pane shows messages with ASCII box art:

```
  ┌─ Agent ─────────────────────
  │
  │  Hello! I'm your AI assistant.
  │
  └──────────────────────────────
```

This is hard to maintain, looks bad with different message lengths, and doesn't match markdown style.

## Fix

Replace all message formatting with simple markdown-like format:

**Before:**
```
  ┌─ You ────────────────────────
  │
  │  Show me how to create a
  │  floating window in Neovim.
  │
  └──────────────────────────────
```

**After:**
```
## You

Show me how to create a
floating window in Neovim.

---

## Agent

Here's a basic example...
```

## Files to modify

### 1. `lua/agent-panel/layout.lua`

- `dummy_main` table: replace ASCII boxes with markdown headers + horizontal rules
- `_submit_input` function: change the box-building code to simple format:
  ```lua
  -- Instead of building a box, just append:
  -- ## You
  -- 
  -- <text>
  -- 
  -- ---
  ```

### 2. `tests/layout_spec.lua`

Update any tests that check for box characters (`┌`, `└`, `│`, `─`) to check for markdown format (`##`, `---`).

## Verification

```bash
cd /Users/q/code/experiments/nvim-agent-panel && LAZY_OFFLINE=1 make test
```

Manual: open panel, submit a message, verify it shows as markdown not ASCII art.

## After done

Commit: `fix: replace ASCII box art with markdown format in main pane`
