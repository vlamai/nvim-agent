# nvim-agent-panel

A floating panel for Neovim, designed for agent/AI interactions.

## Installation

### lazy.nvim

```lua
{
  "your-username/nvim-agent-panel",
  opts = {
    -- width = 80,        -- fixed width (default: 80% of editor)
    -- height = 20,       -- fixed height (default: 80% of editor)
    -- title = " Agent Panel ",
    -- border = "rounded",
  },
  keys = {
    { "<leader>ap", "<cmd>AgentPanel toggle<cr>", desc = "Toggle Agent Panel" },
  },
}
```

For development (local clone):

```lua
{
  dir = "/path/to/nvim-agent-panel",
  opts = {},
  keys = {
    { "<leader>ap", "<cmd>AgentPanel toggle<cr>", desc = "Toggle Agent Panel" },
  },
}
```

## Usage

### Commands

| Command | Description |
|---------|-------------|
| `:AgentPanel open` | Open the panel |
| `:AgentPanel close` | Close the panel |
| `:AgentPanel toggle` | Toggle the panel |

### Keymaps (inside panel)

| Key | Action |
|-----|--------|
| `q` | Close panel |
| `<Esc>` | Close panel |

## Configuration

```lua
require("agent-panel").setup({
  width = 80,           -- nil = 80% of editor width
  height = 20,          -- nil = 80% of editor height
  title = " Agent Panel ",
  border = "rounded",   -- "none", "single", "double", "rounded", "solid", "shadow"
})
```

## Development

```bash
make test          # Run all tests
make test-one MODULE=window  # Run single test file
make dev           # Open Neovim with repro config
```
