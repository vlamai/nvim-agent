# Task: Pi RPC Client Module

## Context

Plugin at `/Users/q/code/experiments/nvim-agent-panel/`. Need to integrate pi (the coding agent) via its RPC mode.

**RPC protocol**: spawn `pi --mode rpc --no-session`, send JSON commands to stdin, receive JSONL events from stdout.

## Goal

Create `lua/agent-panel/pi.lua` — a Lua module that manages one pi RPC process and provides a clean API.

## API Design

```lua
local pi = require("agent-panel.pi")

-- Spawn a new pi process, returns client handle
local client = pi.new({ name = "my-session" })

-- Send a prompt, returns immediately, streams via callback
client:prompt("Hello!", {
  on_delta = function(text) end,     -- streaming text chunks
  on_settled = function() end,       -- agent fully done
  on_error = function(err) end,      -- error
})

-- Abort current generation
client:abort()

-- Get conversation history
client:get_messages(function(messages) end)

-- Kill the process
client:dispose()
```

## Implementation Requirements

1. **Spawn**: `vim.system({ "pi", "--mode", "rpc", "--no-session" }, { stdin = true })` or use `vim.loop.new_pipe` for stdin/stdout
2. **Read stdout**: split on `\n` only (NOT `\r\n` or unicode line separators), parse each line as JSON
3. **Write stdin**: `pipe:write(json_string .. "\n")`
4. **Event routing**: route events to callbacks based on type:
   - `message_update` with `assistantMessageEvent.type == "text_delta"` → `on_delta(delta)`
   - `agent_settled` → `on_settled()`
   - `response` with `success == false` → `on_error(error)`
5. **State tracking**: track current state (idle/streaming/error) to prevent double-prompts
6. **Cleanup**: `client:dispose()` kills process, closes pipes

## Verification

After implementing, create a test script at `tests/pi_spec.lua`:

```lua
---@module 'luassert'
local pi = require("agent-panel.pi")

describe("pi client", function()
  it("spawns and responds to prompt", function()
    local client = pi.new({})
    assert.is_not_nil(client)

    local result = {}
    client:prompt("Reply with just the word 'test'", {
      on_delta = function(text)
        table.insert(result, text)
      end,
      on_settled = function()
        result.done = true
      end,
      on_error = function(err)
        result.error = err
      end,
    })

    -- Wait up to 30s for response
    vim.wait(30000, function() return result.done or result.error end, 100)

    client:dispose()
    assert.is_true(result.done)
    assert.is_nil(result.error)
    assert.is_true(#result > 0)
  end)
end)
```

**Manual verification** (agent can run this):
```bash
# Quick smoke test: spawn pi RPC and send a command
echo '{"type":"prompt","message":"say hi"}' | pi --mode rpc --no-session 2>/dev/null | head -20
```

**Run tests**:
```bash
cd /Users/q/code/experiments/nvim-agent-panel && LAZY_OFFLINE=1 nvim -l tests/minit.lua --minitest tests/pi_spec.lua
```

## After done

1. Run tests — must pass
2. Commit: `feat: pi RPC client module with spawn, prompt, streaming`
