# Task: Pane Navigation System

## Context

Plugin at `/Users/q/code/experiments/nvim-agent-panel/`. 3-pane floating layout:
- **Sidebar** (left) — `lua/agent-panel/layout.lua` creates it
- **Main** (center) — text area
- **Input** (bottom) — user input

Pane abstraction in `lua/agent-panel/pane.lua`. Layout orchestration in `lua/agent-panel/layout.lua`.

## Goal

Smooth keyboard navigation between panes with visual feedback.

## Requirements

1. **`Ctrl+h`** — focus pane to the left (input→main→sidebar, wraps)
2. **`Ctrl+l`** — focus pane to the right (sidebar→main→input, wraps)
3. **`Ctrl+j` / `Ctrl+k`** — same as h/l (alternative for vertical preference)
4. When input pane gets focus → auto `startinsert`
5. When leaving input pane → `stopinsert`
6. Sidebar `cursorline` ON only when sidebar is focused, OFF when leaving
7. Active pane gets brighter border — use highlight groups:
   - `AgentPanelBorderActive` linked to `FloatBorder`
   - `AgentPanelBorderInactive` linked to `Comment`
   - Apply via `nvim_win_set_hl_ns` or `winhl` option on each pane

## Keymaps must be buffer-local

Set them in pane opts in `layout.lua`, not globally.

## After done

1. Run `cd /Users/q/code/experiments/nvim-agent-panel && LAZY_OFFLINE=1 make test` — all tests must pass
2. Commit: `feat: pane navigation with Ctrl+h/l and active border highlight`
