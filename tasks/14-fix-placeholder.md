# Bug: Input placeholder "Ask me anything..." doesn't disappear when typing

## Context

Plugin at `/Users/q/code/experiments/nvim-agent-panel/`. Input pane shows "Ask me anything..." as placeholder extmark. It should clear when user enters insert mode and types, but it stays visible.

## Files to check

`lua/agent-panel/layout.lua` — the `Placeholder` module and input pane autocmds.

## Likely cause

The `InsertEnter` autocmd calls `Placeholder.clear(buf)` but the extmark may not be getting cleared properly, or the extmark ID is not being tracked for deletion.

Check:
1. Is `Placeholder.clear()` actually finding and deleting the extmark?
2. Is the extmark being re-set by `TextChanged` autocmd firing after `InsertEnter`?
3. Is the `ns` namespace correct?

## Verification

```bash
cd /Users/q/code/experiments/nvim-agent-panel && LAZY_OFFLINE=1 make test
```

Manual: open panel, focus input — placeholder should disappear when you start typing.

## After done

Commit: `fix: clear input placeholder when typing`
