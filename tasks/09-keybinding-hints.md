# Task: Keybinding Hints & Help

## Context

Plugin at `/Users/q/code/experiments/nvim-agent-panel/`. The 3-pane layout has different keymaps per pane but user has no way to discover them without reading code.

## Goal

User can see available keybindings at any time.

## Requirements

### 1. Status line with key hints

Add a thin (1 row) bar at the very top of the panel spanning all panes, showing context-sensitive key hints:

**When sidebar focused:**
```
  j/k: navigate  ↵: select  dd: delete  a: add  r: refresh  ?: help  q: quit
```

**When main focused:**
```
  j/k: scroll  G/gg: top/bottom  Ctrl+d/u: half-page  Ctrl+c: abort  ?: help  q: quit
```

**When input focused:**
```
  ↵: send  Shift+↵: newline  Ctrl+c: clear  Ctrl+h/l: switch pane  Esc: normal mode
```

Implementation: create one more floating window pane (`hints`) positioned above the other panes, 1 row tall, full panel width. Use `winhl` to style it dim (`Comment` highlight). Update content on `WinEnter` of any pane.

### 2. Help popup on `?`

Pressing `?` in any pane opens a floating help window showing ALL keybindings in a table:

```
┌─ Agent Panel Help ──────────────────────────┐
│                                              │
│  Global                                      │
│    q / Esc       Close panel                 │
│    ?             This help                   │
│                                              │
│  Sidebar                                     │
│    j / k         Navigate items              │
│    Enter          Select item                │
│    dd            Delete item                 │
│    a             Add item                    │
│    r             Refresh list                │
│    Ctrl+l        Focus main pane             │
│                                              │
│  Main                                        │
│    j / k         Scroll                      │
│    G / gg        Bottom / Top                │
│    Ctrl+d/u      Half page                   │
│    Ctrl+c        Abort generation            │
│    Ctrl+h        Focus sidebar               │
│                                              │
│  Input                                       │
│    Enter          Send message               │
│    Shift+Enter    Newline                    │
│    Ctrl+c        Clear input                 │
│    Ctrl+h/l      Switch pane                 │
│                                              │
└──────────────────────────────────────────────┘
```

- Opens as centered floating window, border "rounded"
- `q` or `Esc` or `?` closes it
- Buffer is scratch, not modifiable

### 3. No which-key dependency

Don't require which-key. This is self-contained.

## Files to modify

- `lua/agent-panel/layout.lua` — add hints pane, help popup logic
- `lua/agent-panel/pane.lua` — possibly add `on_focus`/`on_blur` callbacks for hints update

## Verification

1. Open panel → hints bar visible at top
2. Focus different panes → hints change
3. Press `?` → help popup appears
4. Press `q` → help closes
5. Run `make test`

## After done

Commit: `feat: keybinding hints bar and help popup`
