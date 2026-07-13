# Bug: `_append_delta` crashes on deltas containing newlines

## Context

Plugin at `/Users/q/code/experiments/nvim-agent-panel/`. When pi streams a text delta that contains `\n`, `nvim_buf_set_lines` throws:

```
'replacement string' item contains newlines
```

Location: `lua/agent-panel/layout.lua` line 495 in `_append_delta`.

## Root Cause

`nvim_buf_set_lines` requires each string in the lines table to NOT contain newlines. The streaming delta from pi can contain `\n` characters (e.g. when pi outputs a code block or paragraph).

## Fix

In `_append_delta`, split the delta text on `\n` before appending to buffer:

```lua
function M._append_delta(text)
  -- Split delta on newlines
  local delta_lines = vim.split(text, "\n", { plain = true })
  -- Get current buffer lines
  local lines = vim.api.nvim_buf_get_lines(main_buf, 0, -1, false)
  -- Append each delta line to the last line / as new lines
  for i, dline in ipairs(delta_lines) do
    if i == 1 then
      lines[#lines] = lines[#lines] .. dline
    else
      table.insert(lines, dline)
    end
  end
  vim.api.nvim_buf_set_lines(main_buf, 0, -1, false, lines)
end
```

Also need to handle: when delta is empty string, don't append.

## Verification

```bash
cd /Users/q/code/experiments/nvim-agent-panel && LAZY_OFFLINE=1 make test
```

Manual: open panel, send a prompt that returns multi-line output (e.g. "write a lua function"). Should stream without errors.

## After done

Commit: `fix: handle newlines in streaming deltas`
