# Task: Scrollable Main Pane

## Context

Plugin at `/Users/q/code/experiments/nvim-agent-panel/`. Main pane is the center text area in the 3-pane layout. Created in `lua/agent-panel/layout.lua`.

Main pane currently has `G`/`gg` keymaps but no smooth scroll, no `Ctrl+d/u`, no scroll indicator.

## Goal

Main pane behaves like a proper scrollable text view.

## Requirements

1. **`j`/`k`** — scroll one line when main is focused
2. **`G`** — go to bottom, **`gg`** — go to top (already exists, verify)
3. **`Ctrl+d`** / **`Ctrl+u`** — half-page scroll down/up
4. **Scroll indicator** — show position as extmark virtual text at last line:
   ```
   ── 80% ──
   ```
   Use `nvim_buf_set_extmark` with `virt_text` and `virt_text_pos = "overlay"`. Update on every scroll.
5. **Auto-scroll to bottom** when `set_lines()` is called (new content added)
6. Window option: `scrolloff = 2` for comfortable reading

## Implementation notes

- For scroll indicator, create a function `update_scroll_pct(pane)` that calculates `(cursor_line / total_lines) * 100` and sets extmark
- Call it from `CursorMoved` autocmd on main buffer
- Namespace for extmarks: use `Config.ns` from `lua/agent-panel/config.lua`

## After done

1. Run `cd /Users/q/code/experiments/nvim-agent-panel && LAZY_OFFLINE=1 make test`
2. Commit: `feat: scrollable main pane with Ctrl+d/u and scroll indicator`
