# Task: Connect Pi Client to UI

## Context

Plugin at `/Users/q/code/experiments/nvim-agent-panel/`. After task 06, we have `lua/agent-panel/pi.lua` that can spawn and communicate with pi.

Now wire it into the layout: input sends to pi, streaming text goes to main pane.

## Goal

User types in input → presses Enter → pi processes → response streams into main pane.

## Requirements

### 1. Input → Pi

In `lua/agent-panel/layout.lua`, modify the input submit handler:
- On `<CR>` submit: get text from input buffer
- Append "You: <text>" to main pane (using chat bubble format)
- Call `client:prompt(text, callbacks)`
- Clear input
- Show a "thinking" indicator in main pane (e.g., "  ⏳ Agent is thinking...")

### 2. Pi → Main Pane

During streaming:
- Append streaming text to main pane in real-time
- Use `vim.schedule()` to update buffer from callback (events may fire from different context)
- Remove "thinking" indicator when first delta arrives

On settle:
- Add blank line after response
- Auto-scroll main to bottom

On error:
- Show error in main pane: "  ❌ Error: <message>"

### 3. Session Lifecycle

- On plugin open: spawn one pi client
- On plugin close: `client:dispose()`
- Store client in layout state: `layout.client`
- One client per plugin instance for now (single chat)

### 4. Abort Support

- Add keymap `<C-c>` in main pane: abort current generation
- Send `client:abort()` to pi
- Show "  ⚠ Aborted" in main

## Verification

**Manual test** (agent can do this):
1. Open Neovim with plugin
2. Toggle panel (`<leader>ap`)
3. Type "say hello" in input, press Enter
4. Verify response appears in main pane
5. Press `q` to close

**Automated smoke test** in `tests/pi_spec.lua`:
```lua
it("prompt updates main pane buffer", function()
  -- setup plugin
  local agent_panel = require("agent-panel")
  agent_panel.setup({})
  agent_panel.open()

  -- simulate input submit
  local Layout = require("agent-panel.layout")
  Layout.client = require("agent-panel.pi").new({})
  
  local main_buf = Layout.panes.main.buf
  Layout.client:prompt("say just the word 'ok'", {
    on_delta = function(text) end,
    on_settled = function()
      local lines = vim.api.nvim_buf_get_lines(main_buf, 0, -1, false)
      local content = table.concat(lines, " ")
      assert.is_truthy(content:find("ok"))
    end,
  })

  vim.wait(30000, function() return Layout.client.state == "idle" end, 100)
  agent_panel.close()
end)
```

## After done

1. Open nvim, toggle panel, send a message, verify response streams
2. Run `make test`
3. Commit: `feat: wire pi client to UI, input→pi→main pane streaming`
