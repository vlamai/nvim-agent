# Task: Sidebar List Navigation

## Context

Plugin at `/Users/q/code/experiments/nvim-agent-panel/`. Sidebar is the left pane. Currently shows dummy lines including headers and separators.

Dummy data in `layout.lua`:
```lua
local dummy_sidebar = {
  "  📋 Conversations",
  "  ─────────────",
  "  ▸ Current Chat",
  "    Earlier Today",
  ...
}
```

## Goal

Sidebar behaves like a selectable list — navigate items, skip headers, select with Enter.

## Requirements

1. **`j`/`k`** — move cursor through list items
2. **Skip non-item lines**: lines that are empty, or match `^%s*[─]+$` (separators), or match `^%s*[📋⚙]` (headers) should be jumped over
3. **`<CR>`** on an item → callback. For now just `vim.notify("Selected: " .. item_text)`
4. **Visual**: selected item highlighted with extmark or rely on `cursorline` (which should be ON only when sidebar focused — handled by task 01)
5. **`dd`** — delete item from list with confirmation:
   - Show confirmation in input pane or use `vim.ui.select({"yes","no"})`
   - Remove line from buffer on confirm
6. **`a`** — add new item (placeholder: prompt via `vim.ui.input`, append to list)

## Implementation notes

- Wrap `j`/`k` in a function that checks if next line is a "skip" line, and keeps moving until it finds an item
- Store items as a table in layout state for easier manipulation, re-render on change

## After done

1. Run `cd /Users/q/code/experiments/nvim-agent-panel && LAZY_OFFLINE=1 make test`
2. Commit: `feat: sidebar list navigation with item selection and skip logic`
