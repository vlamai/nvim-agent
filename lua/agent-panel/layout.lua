---@class AgentPanel.Layout
---@field panes table<string, AgentPanel.Pane>|nil
---@field augroup integer|nil
local M = {}

-- Position calculation
---@param cfg table
---@return table<string, {relative: string, row: integer, col: integer, width: integer, height: integer}>
function M.calc_positions(cfg)
  local ew, eh = vim.o.columns, vim.o.lines

  -- Panel dimensions (relative < 1 = ratio, >= 1 = absolute)
  local pw = cfg.width < 1 and math.floor(ew * cfg.width) or cfg.width
  local ph = cfg.height < 1 and math.floor(eh * cfg.height) or cfg.height
  pw = math.min(pw, ew - 4)
  ph = math.min(ph, eh - 4)

  -- Center the panel
  local pr = math.floor((eh - ph) / 2)
  local pc = math.floor((ew - pw) / 2)

  -- Sidebar width
  local sw = cfg.sidebar_width < 1 and math.floor(pw * cfg.sidebar_width) or cfg.sidebar_width
  local mw = pw - sw
  local mh = ph - cfg.input_height
  local ih = cfg.input_height

  return {
    sidebar = { relative = "editor", row = pr, col = pc, width = sw, height = ph },
    main = { relative = "editor", row = pr, col = pc + sw, width = mw, height = mh },
    input = { relative = "editor", row = pr + mh, col = pc + sw, width = mw, height = ih },
  }
end

-- Dummy data for sidebar
local dummy_sidebar = {
  "  📋 Conversations",
  "  ─────────────",
  "  ▸ Current Chat",
  "    Earlier Today",
  "    Yesterday",
  "    Project Setup",
  "    Code Review",
  "",
  "  ⚙ Settings",
  "  ─────────────",
  "    Model: gpt-4",
  "    Temp: 0.7",
}

-- Dummy data for main
local dummy_main = {
  "",
  "  ┌─ Agent ─────────────────────",
  "  │",
  "  │  Hello! I'm your AI assistant.",
  "  │  How can I help you today?",
  "  │",
  "  └──────────────────────────────",
  "",
  "  ┌─ You ────────────────────────",
  "  │",
  "  │  Show me how to create a",
  "  │  floating window in Neovim.",
  "  │",
  "  └──────────────────────────────",
  "",
  "  ┌─ Agent ─────────────────────",
  "  │",
  "  │  Here's a basic example using",
  "  │  nvim_open_win():",
  "  │",
  "  │    local buf = vim.api.nvim_create_buf(false, true)",
  "  │    local win = vim.api.nvim_open_win(buf, true, {",
  "  │      relative = 'editor',",
  "  │      width = 40,",
  "  │      height = 10,",
  "  │      row = 5,",
  "  │      col = 10,",
  "  │      style = 'minimal',",
  "  │      border = 'rounded',",
  "  │    })",
  "  │",
  "  │  This creates a centered floating",
  "  │  window with rounded borders.",
  "  │",
  "  └──────────────────────────────",
}

local function create(layout)
  local Pane = require("agent-panel.pane")
  local Config = require("agent-panel.config")

  layout.panes = {}

  -- Sidebar
  layout.panes.sidebar = Pane.new("sidebar", {
    ft = "agent-panel-sidebar",
    wo = { cursorline = true, wrap = false, number = false, relativenumber = false, signcolumn = "no" },
    bo = { modifiable = false },
    keymaps = {
      ["q"] = function()
        M.close()
      end,
      ["<Esc>"] = function()
        M.close()
      end,
      ["j"] = function(pane)
        local cur = vim.api.nvim_win_get_cursor(pane.win)[1]
        local line_count = vim.api.nvim_buf_line_count(pane.buf)
        if cur < line_count then
          vim.api.nvim_win_set_cursor(pane.win, { cur + 1, 0 })
        end
      end,
      ["k"] = function(pane)
        local cur = vim.api.nvim_win_get_cursor(pane.win)[1]
        if cur > 1 then
          vim.api.nvim_win_set_cursor(pane.win, { cur - 1, 0 })
        end
      end,
      ["<CR>"] = function()
        -- placeholder: select sidebar item
      end,
      ["<C-l>"] = function()
        M.focus("main")
      end,
    },
    on_open = function(pane)
      pane:set_lines(dummy_sidebar)
    end,
  })

  -- Main
  layout.panes.main = Pane.new("main", {
    ft = "agent-panel-main",
    wo = { wrap = true, number = false, relativenumber = false, signcolumn = "no", cursorline = false },
    bo = { modifiable = false },
    keymaps = {
      ["q"] = function()
        M.close()
      end,
      ["<Esc>"] = function()
        M.close()
      end,
      ["G"] = function(pane)
        local line_count = vim.api.nvim_buf_line_count(pane.buf)
        vim.api.nvim_win_set_cursor(pane.win, { line_count, 0 })
      end,
      ["gg"] = function(pane)
        vim.api.nvim_win_set_cursor(pane.win, { 1, 0 })
      end,
      ["<C-h>"] = function()
        M.focus("sidebar")
      end,
    },
    on_open = function(pane)
      pane:set_lines(dummy_main)
      -- Scroll to bottom
      vim.schedule(function()
        if pane:is_valid() then
          local line_count = vim.api.nvim_buf_line_count(pane.buf)
          pcall(vim.api.nvim_win_set_cursor, pane.win, { line_count, 0 })
        end
      end)
    end,
  })

  -- Input
  layout.panes.input = Pane.new("input", {
    ft = "agent-panel-input",
    wo = { wrap = true, number = false, relativenumber = false, signcolumn = "no", cursorline = false },
    bo = { modifiable = true },
    keymaps = {
      ["<Esc>"] = function()
        vim.cmd("stopinsert")
      end,
      ["<C-c>"] = function(pane)
        vim.cmd("stopinsert")
        pane:set_lines({ "" })
      end,
      ["<C-h>"] = function()
        vim.cmd("stopinsert")
        M.focus("sidebar")
      end,
      ["<C-l>"] = function()
        vim.cmd("stopinsert")
        M.focus("main")
      end,
    },
    on_open = function(pane)
      pane:set_lines({ "  Ask me anything..." })
      -- Enter insert mode on focus
      vim.api.nvim_create_autocmd("WinEnter", {
        callback = function()
          if pane:is_valid() and vim.api.nvim_get_current_win() == pane.win then
            vim.schedule(function()
              if pane:is_valid() then
                vim.api.nvim_win_set_cursor(pane.win, { 1, 0 })
                vim.cmd("startinsert")
              end
            end)
          end
        end,
        group = layout.augroup,
      })
    end,
  })
end

function M.open()
  if M.is_open() then
    return
  end
  if not M.augroup then
    M.augroup = vim.api.nvim_create_augroup("agent-panel-layout", { clear = true })
  end
  create(M)
  M.update()
  M.panes.sidebar:focus()
end

function M.update()
  if not M.panes then
    return
  end
  local Config = require("agent-panel.config")
  local cfg = {
    width = Config.width or 0.8,
    height = Config.height or 0.8,
    sidebar_width = Config.sidebar_width or 0.25,
    input_height = Config.input_height or 3,
    border = Config.border or "rounded",
  }
  local positions = M.calc_positions(cfg)
  for name, pane in pairs(M.panes) do
    local pos = positions[name]
    pane:open(vim.tbl_extend("force", pos, {
      border = cfg.border,
      zindex = 50,
    }))
  end
end

function M.close()
  if M.panes then
    for _, pane in pairs(M.panes) do
      pane:destroy()
    end
    M.panes = nil
  end
  if M.augroup then
    pcall(vim.api.nvim_del_augroup_by_id, M.augroup)
    M.augroup = nil
  end
end

function M.toggle()
  if M.is_open() then
    M.close()
  else
    M.open()
  end
end

---@return boolean
function M.is_open()
  return M.panes ~= nil and M.panes.main ~= nil and M.panes.main:is_valid()
end

---@param name "sidebar"|"main"|"input"
function M.focus(name)
  if M.panes and M.panes[name] then
    M.panes[name]:focus()
  end
end

return M
