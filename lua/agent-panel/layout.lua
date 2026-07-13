---@class AgentPanel.Layout
---@field panes table<string, AgentPanel.Pane>|nil
---@field augroup integer|nil
---@field active_pane string|nil
local M = {}

local pane_order = { "sidebar", "main", "input" }

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

---Apply border highlights to all panes based on active pane
function M._apply_highlights()
  if not M.panes then
    return
  end
  for name, pane in pairs(M.panes) do
    if pane:is_valid() then
      if name == M.active_pane then
        vim.wo[pane.win].winhl = "FloatBorder:AgentPanelBorderActive"
      else
        vim.wo[pane.win].winhl = "FloatBorder:AgentPanelBorderInactive"
      end
    end
  end
end

---Update scroll percentage indicator on main pane
---@param pane AgentPanel.Pane
function M.update_scroll_pct(pane)
  if not pane or not pane:is_valid() then
    return
  end
  local Config = require("agent-panel.config")
  local line_count = vim.api.nvim_buf_line_count(pane.buf)
  if line_count <= 1 then
    return
  end
  local cursor_line = vim.api.nvim_win_get_cursor(pane.win)[1]
  local pct = math.floor((cursor_line / line_count) * 100)
  local text = string.format("── %d%% ──", pct)
  -- Clear previous extmark
  local marks = vim.api.nvim_buf_get_extmarks(pane.buf, Config.ns, 0, -1)
  for _, mark in ipairs(marks) do
    vim.api.nvim_buf_del_extmark(pane.buf, Config.ns, mark[1])
  end
  -- Set new extmark at last line
  vim.api.nvim_buf_set_extmark(pane.buf, Config.ns, line_count - 1, 0, {
    virt_text = { { text, "Comment" } },
    virt_text_pos = "overlay",
  })
end

---Scroll pane to bottom
---@param pane AgentPanel.Pane
function M._scroll_to_bottom(pane)
  if pane:is_valid() then
    local line_count = vim.api.nvim_buf_line_count(pane.buf)
    pcall(vim.api.nvim_win_set_cursor, pane.win, { line_count, 0 })
  end
end

---Navigate to the next pane to the right (wraps): sidebar→main→input→sidebar
function M.nav_right()
  if not M.active_pane then
    return
  end
  local idx = 1
  for i, name in ipairs(pane_order) do
    if M.active_pane == name then
      idx = i
      break
    end
  end
  local next_idx = (idx % #pane_order) + 1
  M.focus(pane_order[next_idx])
end

---Navigate to the next pane to the left (wraps): input→main→sidebar→input
function M.nav_left()
  if not M.active_pane then
    return
  end
  local idx = 1
  for i, name in ipairs(pane_order) do
    if M.active_pane == name then
      idx = i
      break
    end
  end
  local prev_idx = ((idx - 2) % #pane_order) + 1
  M.focus(pane_order[prev_idx])
end

---@param name "sidebar"|"main"|"input"
function M.focus(name)
  if not M.panes or not M.panes[name] then
    return
  end

  -- Handle leaving current pane
  if M.active_pane and M.panes[M.active_pane] then
    local old = M.panes[M.active_pane]
    if old:is_valid() then
      -- Stop insert when leaving input pane
      if M.active_pane == "input" then
        pcall(vim.cmd, "stopinsert")
      end
      -- Disable cursorline on sidebar when leaving
      if M.active_pane == "sidebar" then
        vim.wo[old.win].cursorline = false
      end
    end
  end

  M.active_pane = name
  M.panes[name]:focus()

  -- Apply border highlights to all panes
  M._apply_highlights()

  -- Enable cursorline on sidebar when focused
  if name == "sidebar" and M.panes.sidebar:is_valid() then
    vim.wo[M.panes.sidebar.win].cursorline = true
  end

  -- Enter insert mode when focusing input pane
  if name == "input" and M.panes.input:is_valid() then
    vim.schedule(function()
      if M.panes and M.panes.input and M.panes.input:is_valid() then
        vim.cmd("startinsert")
      end
    end)
  end
end

local function create(layout)
  local Pane = require("agent-panel.pane")
  local Config = require("agent-panel.config")

  layout.panes = {}

  -- Sidebar
  layout.panes.sidebar = Pane.new("sidebar", {
    ft = "agent-panel-sidebar",
    wo = { cursorline = false, wrap = false, number = false, relativenumber = false, signcolumn = "no" },
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
      -- Pane navigation
      ["<C-h>"] = function()
        M.nav_left()
      end,
      ["<C-l>"] = function()
        M.nav_right()
      end,
      ["<C-j>"] = function()
        M.nav_right()
      end,
      ["<C-k>"] = function()
        M.nav_left()
      end,
    },
    on_open = function(pane)
      pane:set_lines(dummy_sidebar)
    end,
  })

  -- Main
  layout.panes.main = Pane.new("main", {
    ft = "agent-panel-main",
    wo = { wrap = true, number = false, relativenumber = false, signcolumn = "no", cursorline = false, scrolloff = 2 },
    bo = { modifiable = false },
    keymaps = {
      ["q"] = function()
        M.close()
      end,
      ["<Esc>"] = function()
        M.close()
      end,
      -- Line scroll
      ["j"] = function(pane)
        local cur = vim.api.nvim_win_get_cursor(pane.win)[1]
        local line_count = vim.api.nvim_buf_line_count(pane.buf)
        if cur < line_count then
          vim.api.nvim_win_set_cursor(pane.win, { cur + 1, 0 })
        end
        M.update_scroll_pct(pane)
      end,
      ["k"] = function(pane)
        local cur = vim.api.nvim_win_get_cursor(pane.win)[1]
        if cur > 1 then
          vim.api.nvim_win_set_cursor(pane.win, { cur - 1, 0 })
        end
        M.update_scroll_pct(pane)
      end,
      -- Half-page scroll
      ["<C-d>"] = function(pane)
        local cur = vim.api.nvim_win_get_cursor(pane.win)[1]
        local line_count = vim.api.nvim_buf_line_count(pane.buf)
        local height = vim.api.nvim_win_get_height(pane.win)
        local half = math.floor(height / 2)
        local target = math.min(cur + half, line_count)
        vim.api.nvim_win_set_cursor(pane.win, { target, 0 })
        M.update_scroll_pct(pane)
      end,
      ["<C-u>"] = function(pane)
        local cur = vim.api.nvim_win_get_cursor(pane.win)[1]
        local height = vim.api.nvim_win_get_height(pane.win)
        local half = math.floor(height / 2)
        local target = math.max(cur - half, 1)
        vim.api.nvim_win_set_cursor(pane.win, { target, 0 })
        M.update_scroll_pct(pane)
      end,
      -- Go to top/bottom
      ["G"] = function(pane)
        local line_count = vim.api.nvim_buf_line_count(pane.buf)
        vim.api.nvim_win_set_cursor(pane.win, { line_count, 0 })
        M.update_scroll_pct(pane)
      end,
      ["gg"] = function(pane)
        vim.api.nvim_win_set_cursor(pane.win, { 1, 0 })
        M.update_scroll_pct(pane)
      end,
      -- Pane navigation
      ["<C-h>"] = function()
        M.nav_left()
      end,
      ["<C-l>"] = function()
        M.nav_right()
      end,
      ["<C-j>"] = function()
        M.nav_right()
      end,
      ["<C-k>"] = function()
        M.nav_left()
      end,
    },
    on_open = function(pane)
      pane:set_lines(dummy_main, true)
      -- Set up CursorMoved autocmd for scroll indicator
      vim.api.nvim_create_autocmd("CursorMoved", {
        callback = function()
          if M.panes and M.panes.main and M.panes.main:is_valid() then
            M.update_scroll_pct(M.panes.main)
          end
        end,
        buffer = pane.buf,
        group = layout.augroup,
      })
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
      -- Pane navigation (stop insert before navigating)
      ["<C-h>"] = function()
        vim.cmd("stopinsert")
        M.nav_left()
      end,
      ["<C-l>"] = function()
        vim.cmd("stopinsert")
        M.nav_right()
      end,
      ["<C-j>"] = function()
        vim.cmd("stopinsert")
        M.nav_right()
      end,
      ["<C-k>"] = function()
        vim.cmd("stopinsert")
        M.nav_left()
      end,
    },
    on_open = function(pane)
      pane:set_lines({ "  Ask me anything..." })
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
  M.focus("sidebar")
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
  -- Re-apply highlights after updating window positions
  M._apply_highlights()
end

function M.close()
  if M.panes then
    for _, pane in pairs(M.panes) do
      pane:destroy()
    end
    M.panes = nil
  end
  M.active_pane = nil
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

return M
