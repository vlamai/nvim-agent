---@class AgentPanel.Layout
---@field panes table<string, AgentPanel.Pane>|nil
---@field augroup integer|nil
---@field active_pane string|nil
---@field sidebar_items string[] list of selectable sidebar items
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

-- Check if a line is a non-item line (header, separator, or empty)
---@param line string
---@return boolean
local function is_skip_line(line)
  -- Empty or whitespace-only
  if line:match("^%s*$") then
    return true
  end
  -- Separator lines (only horizontal rules)
  if line:match("^%s*[─]+$") then
    return true
  end
  -- Header lines (starts with emoji)
  if line:match("^%s*[📋⚙]") then
    return true
  end
  return false
end

-- Find the next non-skip line from a given position
---@param lines string[]
---@param start integer 1-indexed start position
---@param direction integer 1 for down, -1 for up
---@return integer|nil
local function find_next_item(lines, start, direction)
  local i = start
  while i >= 1 and i <= #lines do
    if not is_skip_line(lines[i]) then
      return i
    end
    i = i + direction
  end
  return nil
end

-- Build sidebar display lines from items
---@return string[]
local function build_sidebar_lines()
  if not M.sidebar_items then
    return {}
  end
  local lines = {}
  -- Add header
  table.insert(lines, "  📋 Conversations")
  table.insert(lines, "  ─────────────")
  -- Add items
  for _, item in ipairs(M.sidebar_items) do
    table.insert(lines, "  " .. item)
  end
  return lines
end

-- Initial sidebar items
local default_sidebar_items = {
  "▸ Current Chat",
  "  Earlier Today",
  "  Yesterday",
  "  Project Setup",
  "  Code Review",
  "",
  "  Model: gpt-4",
  "  Temp: 0.7",
}

-- Dummy data for sidebar (built from items)
local function get_dummy_sidebar()
  M.sidebar_items = vim.deepcopy(default_sidebar_items)
  return build_sidebar_lines()
end

---Delete a sidebar item by its display line number
---@param display_line integer 1-indexed line in the buffer
function M._delete_sidebar_item(display_line)
  if not M.panes or not M.panes.sidebar or not M.panes.sidebar:is_valid() then
    return
  end
  local lines = vim.api.nvim_buf_get_lines(M.panes.sidebar.buf, 0, -1, false)
  local line = lines[display_line]
  if not line or is_skip_line(line) then
    return
  end
  -- Find the item index in sidebar_items by counting non-skip lines before this one
  local item_idx = 0
  for i = 1, display_line do
    if not is_skip_line(lines[i]) then
      item_idx = item_idx + 1
    end
  end
  -- Remove from items list
  if M.sidebar_items and item_idx > 0 and item_idx <= #M.sidebar_items then
    table.remove(M.sidebar_items, item_idx)
    -- Re-render the sidebar
    local new_lines = build_sidebar_lines()
    M.panes.sidebar:set_lines(new_lines)
    -- Move cursor to a valid item if needed
    local next = find_next_item(new_lines, display_line, 1)
    if not next then
      next = find_next_item(new_lines, display_line, -1)
    end
    if next and M.panes.sidebar:is_valid() then
      vim.api.nvim_win_set_cursor(M.panes.sidebar.win, { next, 0 })
    end
  end
end

---Add a new sidebar item at the end
---@param text string
function M._add_sidebar_item(text)
  if not M.sidebar_items then
    M.sidebar_items = {}
  end
  table.insert(M.sidebar_items, text)
  -- Re-render the sidebar
  if M.panes and M.panes.sidebar and M.panes.sidebar:is_valid() then
    local new_lines = build_sidebar_lines()
    M.panes.sidebar:set_lines(new_lines)
    -- Move cursor to the new item
    local new_line = #new_lines
    if new_line > 0 then
      vim.api.nvim_win_set_cursor(M.panes.sidebar.win, { new_line, 0 })
    end
  end
end

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
  local marks = vim.api.nvim_buf_get_extmarks(pane.buf, Config.ns, 0, -1, {})
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
      -- Navigate down, skipping non-item lines
      ["j"] = function(pane)
        local lines = vim.api.nvim_buf_get_lines(pane.buf, 0, -1, false)
        local cur = vim.api.nvim_win_get_cursor(pane.win)[1]
        local next = find_next_item(lines, cur + 1, 1)
        if next then
          vim.api.nvim_win_set_cursor(pane.win, { next, 0 })
        end
      end,
      -- Navigate up, skipping non-item lines
      ["k"] = function(pane)
        local lines = vim.api.nvim_buf_get_lines(pane.buf, 0, -1, false)
        local cur = vim.api.nvim_win_get_cursor(pane.win)[1]
        local prev = find_next_item(lines, cur - 1, -1)
        if prev then
          vim.api.nvim_win_set_cursor(pane.win, { prev, 0 })
        end
      end,
      -- Select item with Enter
      ["<CR>"] = function(pane)
        local cur = vim.api.nvim_win_get_cursor(pane.win)[1]
        local lines = vim.api.nvim_buf_get_lines(pane.buf, 0, -1, false)
        local line = lines[cur]
        if line and not is_skip_line(line) then
          vim.notify("Selected: " .. vim.trim(line))
        end
      end,
      -- Delete item with confirmation
      ["dd"] = function(pane)
        local cur = vim.api.nvim_win_get_cursor(pane.win)[1]
        local lines = vim.api.nvim_buf_get_lines(pane.buf, 0, -1, false)
        local line = lines[cur]
        if not line or is_skip_line(line) then
          return
        end
        local item_text = vim.trim(line)
        vim.ui.select({ "yes", "no" }, {
          prompt = "Delete '" .. item_text .. "'?",
        }, function(choice)
          if choice == "yes" then
            M._delete_sidebar_item(cur)
          end
        end)
      end,
      -- Add new item
      ["a"] = function(pane)
        vim.ui.input({ prompt = "New item: " }, function(input)
          if input and input ~= "" then
            M._add_sidebar_item(input)
          end
        end)
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
      pane:set_lines(get_dummy_sidebar())
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
