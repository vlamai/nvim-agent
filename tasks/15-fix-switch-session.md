# Bug: "Failed to switch session" when selecting a session

## Context

Plugin at `/Users/q/code/experiments/nvim-agent-panel/`. When selecting a session in the sidebar, error appears: "❌ Failed to switch session".

## Files to investigate

- `lua/agent-panel/layout.lua` — `_load_session_messages` around line 224
- `lua/agent-panel/pi.lua` — `switch_session` around line 241

## Investigation steps

1. Add debug logging to see what `session_path` is being passed:
   ```lua
   -- In _load_session_messages, before calling switch_session:
   vim.notify("Switching to: " .. vim.inspect(session_path), vim.log.levels.INFO)
   ```

2. Check the response from pi RPC — log the full response object in the callback:
   ```lua
   M.client:switch_session(session_path, function(success)
     vim.notify("Switch response: " .. vim.inspect({success = success}), vim.log.levels.INFO)
   ```

3. Check if session paths from `get_entries` are absolute paths or just names

4. Check if pi RPC expects `sessionPath` or `path` or `session_path` — verify against the RPC protocol spec

## Possible causes

- Session path is empty/nil
- Session path format doesn't match what pi expects (relative vs absolute)
- Response routing mismatch: `_on_response` looks up `self._pending[event.command]` but response might have different key
- pi RPC returns error in response body that's not being logged

## Verification

```bash
cd /Users/q/code/experiments/nvim-agent-panel && LAZY_OFFLINE=1 make test
```

Manual: open panel, select a session, verify it loads without error.

## After done

Commit: `fix: handle session switch correctly`
