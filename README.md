# nvim-agent-panel

A floating panel for Neovim with integrated [pi](https://github.com/mariozechner/pi-coding-agent) AI agent. 3-pane layout: sidebar for sessions, main area for chat, input for prompts.

## Features

- 3-pane floating window layout (sidebar / main / input)
- Pi agent integration via RPC (streaming responses)
- Keyboard-driven navigation between panes
- Scrollable main pane with position indicator
- Sidebar with selectable list items
- Input with placeholder, auto-grow, submit to agent
- Context-sensitive keybinding hints bar
- Help popup (`?`)

## Requirements

- Neovim ≥ 0.12
- [pi](https://github.com/mariozechner/pi-coding-agent) installed and in PATH

## Installation

### lazy.nvim

```lua
{
  "your-username/nvim-agent-panel",
  opts = {
    width = 0.8,           -- ratio of editor width (0-1) or absolute cols
    height = 0.8,          -- ratio of editor height or absolute rows
    border = "rounded",    -- "none", "single", "double", "rounded", "solid", "shadow"
    sidebar_width = 0.25,  -- ratio of panel width
    input_height = 3,      -- initial rows
  },
  keys = {
    { "<leader>ap", "<cmd>AgentPanel toggle<cr>", desc = "Toggle Agent Panel" },
  },
}
```

For development (local clone):

```lua
{
  dir = "~/code/experiments/nvim-agent-panel",
  opts = {},
  keys = {
    { "<leader>ap", "<cmd>AgentPanel toggle<cr>", desc = "Toggle Agent Panel" },
    { "<leader>aR", "<cmd>Lazy reload nvim-agent-panel<cr>", desc = "Reload Agent Panel" },
  },
}
```

## Usage

### Commands

| Command | Description |
|---------|-------------|
| `:AgentPanel` | Toggle panel |
| `:AgentPanel open` | Open the panel |
| `:AgentPanel close` | Close the panel |
| `:AgentPanel toggle` | Toggle the panel |
| `:AgentPanel focus sidebar` | Focus sidebar pane |
| `:AgentPanel focus main` | Focus main pane |
| `:AgentPanel focus input` | Focus input pane |

### Keymaps

#### Global (all panes)

| Key | Action |
|-----|--------|
| `q` / `Esc` | Close panel |
| `?` | Show help popup |
| `Ctrl+h` | Focus pane to the left |
| `Ctrl+l` | Focus pane to the right |
| `Ctrl+j` / `Ctrl+k` | Same as l/h (alternative) |

#### Sidebar

| Key | Action |
|-----|--------|
| `j` / `k` | Navigate items (skips headers/separators) |
| `Enter` | Select item |
| `dd` | Delete item |
| `a` | Add new item |

#### Main pane

| Key | Action |
|-----|--------|
| `j` / `k` | Scroll one line |
| `G` / `gg` | Go to bottom / top |
| `Ctrl+d` / `Ctrl+u` | Half-page scroll |

#### Input pane

| Key | Action |
|-----|--------|
| `Enter` | Send message to agent |
| `Shift+Enter` | Newline (don't send) |
| `Ctrl+c` | Clear input |
| `Esc` | Exit insert mode |

## Configuration

```lua
require("agent-panel").setup({
  width = 0.8,
  height = 0.8,
  border = "rounded",
  sidebar_width = 0.25,
  input_height = 3,
})
```

## Architecture

```
lua/agent-panel/
├── init.lua       -- Public API (setup, open, close, toggle, focus)
├── config.lua     -- Config with defaults
├── layout.lua     -- 3-pane layout engine, keymaps, UI logic
├── pane.lua       -- Single pane abstraction (buf + win + keymaps)
├── pi.lua         -- Pi RPC client (spawn, prompt, streaming)
└── util.lua       -- Notifications
```

## Development

```bash
make test                          # Run all tests
make test-one MODULE=layout        # Run single test file
make lint                          # Check formatting
make format                        # Auto-format
make dev                           # Open Neovim with repro config
```

Tests use [mini.test](https://github.com/echasnovski/mini.test) + [luassert](https://github.com/lunarmodules/luassert). Dependencies auto-install on first run.
