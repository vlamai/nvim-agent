# Bug: Sessions not loading — M.sessions is always empty

## Context

Plugin at `/Users/q/code/experiments/nvim-agent-panel/`. Sidebar shows no sessions even though `~/.pi/agent/sessions/--Users-q-code-experiments-nvim-agent-panel--/` contains 15+ session files.

Debug output shows `sessions: 0` — `M.sessions` is never populated.

## Root Cause Investigation

`refresh_sessions()` is called via `vim.defer_fn` 500ms after panel opens. It calls `get_session_dir()` which does:

```lua
local cwd = vim.fn.getcwd()
local session_dir_name = "--" .. cwd:gsub("/", "-") .. "--"
local base_dir = vim.fn.expand("~/.pi/agent/sessions")
local session_dir = base_dir .. "/" .. session_dir_name
```

**Possible issues:**

1. `vim.fn.getcwd()` returns different path in floating window context vs main editor
2. The `gsub("/", "-")` doesn't match the actual directory naming convention of pi
3. `vim.defer_fn` callback runs in a context where `M.panes.sidebar:is_valid()` is false, so `_render_sidebar` bails out
4. `refresh_sessions` runs but `M.sessions` gets reset somewhere after

## Debug Steps

Add to `refresh_sessions()`:
```lua
function M.refresh_sessions()
  local session_dir = get_session_dir()
  vim.notify("DEBUG session_dir: " .. vim.inspect(session_dir), vim.log.levels.INFO)
  vim.notify("DEBUG cwd: " .. vim.fn.getcwd(), vim.log.levels.INFO)
  ...
```

## Files to modify

- `lua/agent-panel/layout.lua` — `get_session_dir()`, `refresh_sessions()`

## Verification

```bash
cd /Users/q/code/experiments/nvim-agent-panel && LAZY_OFFLINE=1 make test
```

Manual: open panel, check `:messages` for debug output, verify sessions appear in sidebar.

## After done

Commit: `fix: load sessions from correct directory`
