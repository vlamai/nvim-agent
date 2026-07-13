# Bug: Input pane stops accepting input after first submit

## Context

Plugin at `/Users/q/code/experiments/nvim-agent-panel/`. After submitting a message from the input pane, it becomes non-modifiable — typing does nothing.

## Root Cause

In `lua/agent-panel/layout.lua`, function `_submit_input` around line 440:

```lua
-- Clear input
vim.bo[input_pane.buf].modifiable = true
vim.api.nvim_buf_set_lines(input_pane.buf, 0, -1, false, { "" })
vim.bo[input_pane.buf].modifiable = false  -- ← BUG: input should stay modifiable
```

Same issue in `<C-c>` insert keymap in the input pane definition:
```lua
["<C-c>"] = function(pane)
    vim.bo[pane.buf].modifiable = true
    vim.api.nvim_buf_set_lines(pane.buf, 0, -1, false, { "" })
    vim.bo[pane.buf].modifiable = false  -- ← same bug
```

## Fix

1. In `_submit_input`: remove `vim.bo[input_pane.buf].modifiable = false` after clearing input buffer. Input pane is always modifiable.

2. In `<C-c>` keymap: same — remove `vim.bo[pane.buf].modifiable = false`.

3. Update test `_submit_input shows placeholder after submit` — it currently sets `modifiable = false` before submit and expects it after. The buffer should be modifiable after submit.

## Verification

```bash
cd /Users/q/code/experiments/nvim-agent-panel && LAZY_OFFLINE=1 make test
```

All tests must pass. Then manual test: open panel, type message, submit, type again — should work.

## After done

Commit: `fix: keep input pane modifiable after submit`
