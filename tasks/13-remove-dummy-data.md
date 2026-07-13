# Task: Remove all dummy data

## Context

Plugin at `/Users/q/code/experiments/nvim-agent-panel/`. `lua/agent-panel/layout.lua` contains hardcoded dummy data that clutters the UI:

- `dummy_sidebar` / `default_sidebar_items` — fake session list
- `dummy_main` — fake chat messages with ASCII boxes
- `get_dummy_sidebar()` function

## Goal

Clean slate — empty panels when opening. Content comes only from real pi interaction.

## Requirements

1. Remove `dummy_sidebar`, `default_sidebar_items`, `get_dummy_sidebar()` from `layout.lua`
2. Remove `dummy_main` table
3. Sidebar opens empty (just header if any, or fully empty)
4. Main pane opens empty
5. Input pane: keep placeholder ("Ask me anything...")
6. Update any tests that depend on dummy data being present — they should pass with empty buffers

## Verification

```bash
cd /Users/q/code/experiments/nvim-agent-panel && LAZY_OFFLINE=1 make test
```

Manual: open panel — should be empty. No "Conversations", no "Agent: Hello!", just blank panes.

## After done

Commit: `refactor: remove dummy data, start with empty panels`
