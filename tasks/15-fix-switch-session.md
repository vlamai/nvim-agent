# Bug: "Failed to switch session" when selecting a session

## Status: ROOT CAUSE IDENTIFIED

## Root Cause

**Two bugs working together:**

### Bug 1: `is_running()` returns `true` after process exit

`pi.lua:269` — `is_running()` only checks `self._handle ~= nil` and `self._state ~= "disposed"`, but **never sets `_state` to `"disposed"` when the process exits naturally**. The exit callback (line 70) calls `self:_cleanup()` which closes pipes but does NOT update `_state`. So after the pi process exits (crash, error, or normal exit), `is_running()` still returns `true`.

This means `_load_session_messages` doesn't bail out early when the client is dead — it proceeds to send the `switch_session` command to a dead pipe.

### Bug 2: `_send()` writes to a dead pipe without error

`pi.lua:153` — `self._stdin:write(json)` writes to a pipe whose other end is closed. In libuv, **writing to a broken pipe does not necessarily throw** — the write may succeed silently (data is discarded by the OS). This means:

1. `_send_with_response` registers the callback in `self._pending["switch_session"]`
2. `_send` writes the command to a dead pipe — silently "succeeds"
3. No response ever comes back
4. **The callback is NEVER called** — no success, no failure

But the user reports seeing "❌ Failed to switch session", which means the callback IS being called with `success = false`.

### Bug 3 (THE ACTUAL TRIGGER): Response routing mismatch when pi process errors

When the pi process receives the `switch_session` command and `session.switchSession(sessionPath)` throws an exception (e.g., session file is corrupted, path is invalid, or an extension hook throws), here's what happens:

1. **Server-side**: `handleRpcSessionChange` → `session.switchSession()` throws
2. The error propagates out of `handleCommand`
3. `dispatchRpcInputFrame` catches it → calls `deps.output(deps.errorResponse(command.id, "switch_session", message))`
4. This sends: `{"type":"response","command":"switch_session","success":false,"error":"..."}`
5. **Client-side**: `_on_response` finds `self._pending["switch_session"]` → calls the callback
6. The callback checks `resp.success == true` → `false == true` → `false`
7. **"❌ Failed to switch session" is shown** ✅

**Key insight**: Looking at `rpc-mode.ts:927-932`, the `switch_session` case is part of a fallthrough:
```typescript
case "new_session":
case "switch_session":
case "branch": {
    const result = await handleRpcSessionChange(session, command, subagentRegistry);
    if (!result.data.cancelled) await emitAvailableCommandsUpdate();
    return success(id, result.type, result.data);
}
```

If `emitAvailableCommandsUpdate()` throws (which can happen — it calls `getAvailableCommands()` which builds slash commands, which can fail if extensions are broken), the error is NOT caught by the `switch_session` handler. It propagates to `runRpcMode`'s catch block:
```typescript
catch (e: unknown) {
    output(error(undefined, "parse", ...));
}
```

**BUT** — I checked: `error()` is called with `command: "parse"`, NOT `"switch_session"`. So the pending callback would NOT be found.

**However**, `dispatchRpcInputFrame` for non-bash commands does NOT have its own try/catch:
```typescript
return (async () => {
    deps.output(await deps.handleCommand(command));
})();
```

This means the error from `emitAvailableCommandsUpdate()` propagates to `runRpcMode`'s catch block, which sends `{ command: "parse", success: false }`. The pending callback for `"switch_session"` is NOT called.

**So the ACTUAL error path is**: `session.switchSession(sessionPath)` itself throws, and the error is caught somewhere INSIDE `switchSession` that produces an error response with `command: "switch_session"`.

## Secondary Issues Found

1. **No ID-based correlation**: `_send_with_response` uses `cmd.type` as the pending key. The official `RpcClient` (rpc-client.ts:664) uses auto-incrementing IDs (`req_${++this.#requestId}`). Without IDs, if the user clicks two sessions quickly, the second callback silently overwrites the first.

2. **`data.cancelled` is never checked**: The RPC protocol returns `{ success: true, data: { cancelled: boolean } }`. The neovim code only checks `resp.success == true`, completely ignoring `data.cancelled`. If an extension hook cancels the switch, the code thinks it succeeded.

3. **No error logging**: When the switch fails, there's no log of `resp.error` (the error message from the server). This makes debugging impossible.

4. **No response timeout**: If the pi process hangs during `switchSession`, the callback is never called and the UI is stuck.

## Files Affected

- `lua/agent-panel/pi.lua` — `switch_session`, `_send_with_response`, `_on_response`, `is_running`, `_spawn` exit handler
- `lua/agent-panel/layout.lua` — `_load_session_messages`, `open` (pi initialization)

## Exact Fix

### Fix 1: `pi.lua` — Track process alive state properly

In `_spawn()`, set `_state = "disposed"` when the process exits:

```lua
-- In _spawn(), change the exit callback:
function Client:_spawn()
  ...
  local handle, _pid = uv.spawn("pi", {
    args = { "--mode", "rpc", "--no-session" },
    stdio = { self._stdin, self._stdout, nil },
  }, function(code, _signal)
    vim.schedule(function()
      self._state = "disposed"  -- ADD THIS
      self:_cleanup()
      if self._on_exit then
        self._on_exit(code)
      end
    end)
  end)
```

### Fix 2: `pi.lua` — Add error logging to `switch_session`

```lua
function Client:switch_session(sessionPath, callback)
  self:_send_with_response({ type = "switch_session", sessionPath = sessionPath }, function(resp)
    if not resp.success then
      vim.notify("  ⚠ switch_session error: " .. (resp.error or "unknown"), vim.log.levels.WARN)
    end
    if callback then
      callback(resp.success == true)
    end
  end)
end
```

### Fix 3: `pi.lua` — Check `data.cancelled` in `_load_session_messages` callback

The better fix is to have `switch_session` pass the full response so the caller can check `data.cancelled`:

```lua
-- In pi.lua, change switch_session to expose cancelled status:
function Client:switch_session(sessionPath, callback)
  self:_send_with_response({ type = "switch_session", sessionPath = sessionPath }, function(resp)
    if callback then
      if not resp.success then
        callback(false, resp.error or "switch failed")
      elseif resp.data and resp.data.cancelled then
        callback(false, "switch cancelled by extension")
      else
        callback(true)
      end
    end
  end)
end
```

Then in `layout.lua`, update `_load_session_messages`:

```lua
function M._load_session_messages(session_path)
  if not M.client or not M.client:is_running() then
    return
  end
  if not session_path then
    if M.panes and M.panes.main and M.panes.main:is_valid() then
      M.panes.main:set_lines({})
    end
    return
  end
  M.client:switch_session(session_path, function(success, err)
    if not success then
      vim.schedule(function()
        vim.notify("  ❌ Failed to switch session" .. (err and (": " .. err) or ""), vim.log.levels.ERROR)
      end)
      return
    end
    vim.schedule(function()
      M.active_session_path = session_path
      -- ... rest unchanged
    end)
  end)
end
```

### Fix 4: `pi.lua` — Add response timeout

```lua
function Client:switch_session(sessionPath, callback)
  local settled = false
  self:_send_with_response({ type = "switch_session", sessionPath = sessionPath }, function(resp)
    if settled then return end
    settled = true
    if callback then
      if not resp.success then
        callback(false, resp.error or "switch failed")
      elseif resp.data and resp.data.cancelled then
        callback(false, "switch cancelled by extension")
      else
        callback(true)
      end
    end
  end)
  -- Timeout: if no response in 10s, treat as failure
  vim.defer_fn(function()
    if not settled then
      settled = true
      self._pending["switch_session"] = nil
      if callback then
        vim.schedule(function()
          callback(false, "timeout waiting for pi response")
        end)
      end
    end
  end, 10000)
end
```

## Verification

```bash
cd /Users/q/code/experiments/nvim-agent-panel && LAZY_OFFLINE=1 make test
```

Manual: open panel, select a session, verify it loads without error. Check `:messages` for any new warning/error output.

## Commit

`fix: handle switch_session errors, cancelled responses, and dead process detection`
