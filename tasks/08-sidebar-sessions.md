# Task: Sidebar Session List

## Context

Plugin at `/Users/q/code/experiments/nvim-agent-panel/`. After tasks 06-07, we have one pi client wired to the UI.

Now the sidebar should show a list of chat sessions, and switching sessions should load different conversations.

## Goal

Sidebar shows pi sessions, selecting one switches the active chat.

## Requirements

### 1. Session List in Sidebar

Pi RPC has `get_entries` command that returns session list. Use it to populate sidebar.

Replace dummy sidebar data with real session entries:
```
  📋 Sessions
  ─────────────
  ▸ Current Chat          ← active
    Project Setup
    Code Review
    ─────────────
  + New Chat              ← creates new session
```

### 2. New Chat

- `<CR>` on "+ New Chat" → send `new_session` to pi RPC
- Clear main pane
- Update sidebar list

### 3. Switch Session

- `<CR>` on a session entry → send `switch_session` with session path
- Load messages via `get_messages` → render in main pane
- Update active indicator (▸)

### 4. Delete Session

- `dd` on a session → confirmation → delete session file → refresh list

### 5. Refresh

- `r` key in sidebar → re-fetch session list

## Pi RPC Commands Used

```json
{"type": "get_entries"}        → response with session list
{"type": "new_session"}        → creates new session
{"type": "switch_session", "sessionPath": "..."}  → switches
{"type": "get_messages"}       → get current session messages
```

## Verification

**Manual test**:
1. Open panel, sidebar should show sessions (not dummy data)
2. Type a message → it creates/uses a session
3. Create new chat → main pane clears
4. Switch back → messages restored

**Smoke test** in `tests/pi_spec.lua`:
```lua
it("get_entries returns session list", function()
  local pi = require("agent-panel.pi")
  local client = pi.new({})
  local entries = nil
  client:get_entries(function(e) entries = e end)
  vim.wait(10000, function() return entries ~= nil end, 100)
  client:dispose()
  assert.is_not_nil(entries)
end)
```

## After done

1. Test: create 2 chats, switch between them, verify messages persist
2. Run `make test`
3. Commit: `feat: sidebar session list with new/switch/delete`
