---@class AgentPanel.Layout
---@field panes table<string, AgentPanel.Pane>|nil
---@field augroup integer|nil
---@field active_pane string|nil
---@field sidebar_items string[] list of selectable sidebar items
local M = {}

local pane_order = { "sidebar", "main", "input" }

---@type AgentPanel.PiClient|nil
M.client = nil

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

  -- Hints bar is 1 row above the panel
  local hints_height = 1
  return {
    hints = { relative = "editor", row = pr - hints_height, col = pc, width = pw, height = hints_height },
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
  -- Header lines (starts with clipboard or gear emoji)  -- Use plain string matching to avoid multi-byte character issues
  local trimmed = line:match("^%s*(.*)") or line
  if trimmed:sub(1, #"📋") == "📋" or trimmed:sub(1, #"⚙") == "⚙" then
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
  "## Agent",
  "",
  "Hello! I'm your AI assistant.",
  "How can I help you today?",
  "",
  "---",
  "",
  "## You",
  "",
  "Show me how to create a",
  "floating window in Neovim.",
  "",
  "---",
  "",
  "## Agent",
  "",
  "Here's a basic example using",
  "nvim_open_win():",
  "",
  "```lua",
  "local buf = vim.api.nvim_create_buf(false, true)",
  "local win = vim.api.nvim_open_win(buf, true, {",
  "  relative = 'editor',",
  "  width = 40,",
  "  height = 10,",
  "  row = 5,",
  "  col = 10,",
  "  style = 'minimal',",
  "  border = 'rounded',",
  "})",
  "```",
  "",
  "This creates a centered floating",
  "window with rounded borders.",
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

---Hints content for each pane
local hints_text = {
  sidebar = "  j/k: navigate  \195\137: select  dd: delete  a: add  ?: help  q: quit",
  main = "  j/k: scroll  G/gg: top/bottom  Ctrl+d/u: half-page  Ctrl+c: abort  ?: help  q: quit",
  input = "  \195\137: send  Ctrl+c: clear  Ctrl+h/l: switch pane  Esc: normal mode",
}

---Update hints bar content based on active pane
function M._update_hints()
  if not M.panes or not M.panes.hints or not M.panes.hints:is_valid() then
    return
  end
  local text = hints_text[M.active_pane] or ""
  M.panes.hints:set_lines({ text })
end

---Help popup content
local help_lines = {
  "",
  "  \226\148\128 Agent Panel Help \226\148\128",
  "",
  "  Global",
  "    q / Esc       Close panel",
  "    ?             This help",
  "",
  "  Sidebar",
  "    j / k         Navigate items",
  "    Enter          Select item",
  "    dd            Delete item",
  "    a             Add item",
  "    Ctrl+l        Focus main pane",
  "",
  "  Main",
  "    j / k         Scroll",
  "    G / gg        Bottom / Top",
  "    Ctrl+d/u      Half page",
  "    Ctrl+c        Abort generation",
  "    Ctrl+h        Focus sidebar",
  "",
  "  Input",
  "    Enter          Send message",
  "    Ctrl+c        Clear input",
  "    Ctrl+h/l      Switch pane",
  "",
}

---Show help popup
function M._show_help()
  if M._help_win and vim.api.nvim_win_is_valid(M._help_win) then
    return
  end
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "hide"
  vim.bo[buf].swapfile = false
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, help_lines)
  vim.bo[buf].modifiable = false
  -- Calculate dimensions
  local max_width = 0
  for _, line in ipairs(help_lines) do
    max_width = math.max(max_width, vim.fn.strdisplaywidth(line))
  end
  local width = max_width + 4
  local height = #help_lines + 2
  -- Center on screen
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)
  M._help_win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    zindex = 100,
  })
  -- Close keymaps
  local close = function()
    if M._help_win and vim.api.nvim_win_is_valid(M._help_win) then
      vim.api.nvim_win_close(M._help_win, true)
      M._help_win = nil
    end
  end
  vim.keymap.set("n", "q", close, { buffer = buf, silent = true })
  vim.keymap.set("n", "<Esc>", close, { buffer = buf, silent = true })
  vim.keymap.set("n", "?", close, { buffer = buf, silent = true })
end

---Input pane placeholder management
local Placeholder = {}
local PLACEHOLDER_TEXT = "Ask me anything..."

---Set placeholder extmark on input buffer
---@param buf integer
function Placeholder.set(buf)
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  local Config = require("agent-panel.config")
  -- Clear existing placeholder
  Placeholder.clear(buf)
  -- Only set if buffer is empty
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local content = table.concat(lines, "")
  if content == "" or ( #lines == 1 and lines[1] == "" ) then
    vim.api.nvim_buf_set_extmark(buf, Config.ns, 0, 0, {
      virt_text = { { "  " .. PLACEHOLDER_TEXT, "Comment" } },
      virt_text_pos = "overlay",
      right_gravity = true,
    })
  end
end

---Clear placeholder extmark from input buffer
---@param buf integer
function Placeholder.clear(buf)
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  local Config = require("agent-panel.config")
  local marks = vim.api.nvim_buf_get_extmarks(buf, Config.ns, 0, -1, {})
  for _, mark in ipairs(marks) do
    vim.api.nvim_buf_del_extmark(buf, Config.ns, mark[1])
  end
end

---Check if buffer has content (non-empty)
---@param buf integer
---@return boolean
function Placeholder.has_content(buf)
  if not vim.api.nvim_buf_is_valid(buf) then
    return false
  end
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  if #lines == 0 then
    return false
  end
  if #lines == 1 and lines[1] == "" then
    return false
  end
  return true
end

---Append lines to main pane buffer
---@param main_pane AgentPanel.Pane
---@param new_lines string[]
local function append_to_main(main_pane, new_lines)
  vim.bo[main_pane.buf].modifiable = true
  local main_lines = vim.api.nvim_buf_get_lines(main_pane.buf, 0, -1, false)
  -- Find the last non-empty line
  local insert_at = #main_lines
  while insert_at > 1 and vim.trim(main_lines[insert_at]) == "" do
    insert_at = insert_at - 1
  end
  insert_at = insert_at + 1
  -- Insert the new content
  for i, line in ipairs(new_lines) do
    table.insert(main_lines, insert_at + i - 1, line)
  end
  vim.api.nvim_buf_set_lines(main_pane.buf, 0, -1, false, main_lines)
  vim.bo[main_pane.buf].modifiable = false
end

---Show thinking indicator in main pane
---@param main_pane AgentPanel.Pane
function M._show_thinking(main_pane)
  if not main_pane:is_valid() then return end
  vim.bo[main_pane.buf].modifiable = true
  local main_lines = vim.api.nvim_buf_get_lines(main_pane.buf, 0, -1, false)
  local insert_at = #main_lines
  while insert_at > 1 and vim.trim(main_lines[insert_at]) == "" do
    insert_at = insert_at - 1
  end
  insert_at = insert_at + 1
  table.insert(main_lines, insert_at, "## Agent")
  table.insert(main_lines, insert_at + 1, "")
  table.insert(main_lines, insert_at + 2, "  ⏳ Agent is thinking...")
  table.insert(main_lines, insert_at + 3, "")
  vim.api.nvim_buf_set_lines(main_pane.buf, 0, -1, false, main_lines)
  vim.bo[main_pane.buf].modifiable = false
  M._scroll_to_bottom(main_pane)
end

---Remove thinking indicator lines from main pane
---@param main_pane AgentPanel.Pane
function M._remove_thinking(main_pane)
  if not main_pane:is_valid() then return end
  vim.bo[main_pane.buf].modifiable = true
  local main_lines = vim.api.nvim_buf_get_lines(main_pane.buf, 0, -1, false)
  -- Remove lines containing the thinking indicator
  local new_lines = {}
  local skip_next = false
  for i, line in ipairs(main_lines) do
    if line:find("Agent is thinking") then
      -- Skip this line and the blank lines around it
      skip_next = true
    elseif skip_next and line == "" then
      skip_next = false
    elseif not skip_next then
      table.insert(new_lines, line)
    end
  end
  vim.api.nvim_buf_set_lines(main_pane.buf, 0, -1, false, new_lines)
  vim.bo[main_pane.buf].modifiable = false
end

---Append streaming delta to main pane (replaces thinking indicator on first delta)
---@param main_pane AgentPanel.Pane
---@param delta string
---@param is_first boolean
function M._append_delta(main_pane, delta, is_first)
  if not main_pane:is_valid() then return end
  vim.bo[main_pane.buf].modifiable = true
  local main_lines = vim.api.nvim_buf_get_lines(main_pane.buf, 0, -1, false)
  if is_first then
    -- Remove thinking indicator, then append response content
    local cleaned = {}
    local skip_thinking = false
    for _, line in ipairs(main_lines) do
      if line:find("Agent is thinking") then
        skip_thinking = true
      elseif skip_thinking and line == "" then
        skip_thinking = false
      elseif not skip_thinking then
        table.insert(cleaned, line)
      end
    end
    main_lines = cleaned
  end
  -- Get last line and append delta
  if #main_lines > 0 then
    main_lines[#main_lines] = main_lines[#main_lines] .. delta
  else
    table.insert(main_lines, delta)
  end
  vim.api.nvim_buf_set_lines(main_pane.buf, 0, -1, false, main_lines)
  vim.bo[main_pane.buf].modifiable = false
  M._scroll_to_bottom(main_pane)
end

---Finalize response with blank line and separator
---@param main_pane AgentPanel.Pane
function M._finalize_response(main_pane)
  if not main_pane:is_valid() then return end
  vim.bo[main_pane.buf].modifiable = true
  local main_lines = vim.api.nvim_buf_get_lines(main_pane.buf, 0, -1, false)
  table.insert(main_lines, "")
  table.insert(main_lines, "---")
  vim.api.nvim_buf_set_lines(main_pane.buf, 0, -1, false, main_lines)
  vim.bo[main_pane.buf].modifiable = false
  M._scroll_to_bottom(main_pane)
end

---Submit input text to main pane
---@param input_pane AgentPanel.Pane
---@param main_pane AgentPanel.Pane
function M._submit_input(input_pane, main_pane)
  if not input_pane:is_valid() or not main_pane:is_valid() then
    return
  end
  -- Get input text
  local lines = vim.api.nvim_buf_get_lines(input_pane.buf, 0, -1, false)
  local text = table.concat(lines, "\n")
  text = vim.trim(text)
  if text == "" then
    return
  end
  -- Check if client is available
  if not M.client or not M.client:is_running() then
    vim.notify("  ❌ Pi client not connected", vim.log.levels.ERROR)
    return
  end
  -- Format user message as markdown
  local input_lines = vim.split(text, "\n", { plain = true })
  local box_lines = { "## You", "" }
  for _, line in ipairs(input_lines) do
    table.insert(box_lines, line)
  end
  table.insert(box_lines, "")
  table.insert(box_lines, "---")
  table.insert(box_lines, "")
  -- Append user message to main pane
  append_to_main(main_pane, box_lines)
  -- Clear input
  vim.api.nvim_buf_set_lines(input_pane.buf, 0, -1, false, { "" })
  Placeholder.set(input_pane.buf)
  -- Show thinking indicator
  M._show_thinking(main_pane)
  -- Send to pi client
  local is_first = true
  M.client:prompt(text, {
    on_delta = function(delta)
      vim.schedule(function()
        M._append_delta(main_pane, delta, is_first)
        is_first = false
      end)
    end,
    on_settled = function()
      vim.schedule(function()
        M._finalize_response(main_pane)
      end)
    end,
    on_error = function(err)
      vim.schedule(function()
        M._remove_thinking(main_pane)
        vim.bo[main_pane.buf].modifiable = true
        local main_lines = vim.api.nvim_buf_get_lines(main_pane.buf, 0, -1, false)
        local insert_at = #main_lines
        while insert_at > 1 and vim.trim(main_lines[insert_at]) == "" do
          insert_at = insert_at - 1
        end
        insert_at = insert_at + 1
        table.insert(main_lines, insert_at, "## Agent")
        table.insert(main_lines, insert_at + 1, "")
        table.insert(main_lines, insert_at + 2, "  ❌ Error: " .. (err or "unknown error"))
        table.insert(main_lines, insert_at + 3, "")
        table.insert(main_lines, insert_at + 4, "---")
        vim.api.nvim_buf_set_lines(main_pane.buf, 0, -1, false, main_lines)
        vim.bo[main_pane.buf].modifiable = false
        M._scroll_to_bottom(main_pane)
      end)
    end,
  })
end

---Auto-grow input pane based on content
---@param pane AgentPanel.Pane
function M._autoGrow_input(pane)
  if not pane:is_valid() then
    return
  end
  local Config = require("agent-panel.config")
  local min_height = Config.input_height or 3
  local max_height = 5
  local lines = vim.api.nvim_buf_get_lines(pane.buf, 0, -1, false)
  local line_count = #lines
  -- Account for wrapped lines
  local total_height = 0
  for _, line in ipairs(lines) do
    local display_width = vim.fn.strdisplaywidth(line)
    local win_width = vim.api.nvim_win_get_width(pane.win) - 4 -- account for border/padding
    local wrapped = math.max(1, math.ceil(display_width / win_width))
    total_height = total_height + wrapped
  end
  total_height = math.max(total_height, 1)
  local new_height = math.max(min_height, math.min(max_height, total_height))
  local cur_height = vim.api.nvim_win_get_height(pane.win)
  if new_height ~= cur_height then
    vim.api.nvim_win_set_config(pane.win, { height = new_height })
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

  -- Update hints bar
  M._update_hints()

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

  -- Hints bar
  layout.panes.hints = Pane.new("hints", {
    ft = "agent-panel-hints",
    wo = { wrap = false, number = false, relativenumber = false, signcolumn = "no", cursorline = false },
    bo = { modifiable = false },
    on_open = function(pane)
      pane:set_lines({ "" })
      vim.wo[pane.win].winhl = "NormalFloat:Comment"
    end,
  })

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
      ["?"] = function()
        M._show_help()
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
      ["?"] = function()
        M._show_help()
      end,
      -- Abort generation
      ["<C-c>"] = function()
        if M.client and M.client._state == "streaming" then
          M.client:abort()
          vim.bo[pane.buf].modifiable = true
          local main_lines = vim.api.nvim_buf_get_lines(pane.buf, 0, -1, false)
          local insert_at = #main_lines
          while insert_at > 1 and vim.trim(main_lines[insert_at]) == "" do
            insert_at = insert_at - 1
          end
          insert_at = insert_at + 1
          table.insert(main_lines, insert_at, "")
          table.insert(main_lines, insert_at + 1, "  ⚠ Aborted")
          vim.api.nvim_buf_set_lines(pane.buf, 0, -1, false, main_lines)
          vim.bo[pane.buf].modifiable = false
          M._scroll_to_bottom(pane)
        end
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
      ["?"] = function()
        vim.cmd("stopinsert")
        M._show_help()
      end,
    },
    insert_keymaps = {
      -- Submit on Enter
      ["<CR>"] = function(pane)
        if M.panes and M.panes.main then
          M._submit_input(pane, M.panes.main)
        end
      end,
      -- Newline on Shift-Enter
      ["<S-CR>"] = function(pane)
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<CR>", true, false, true), "n", false)
      end,
      -- Clear and exit insert on Ctrl-C
      ["<C-c>"] = function(pane)
        vim.api.nvim_buf_set_lines(pane.buf, 0, -1, false, { "" })
        Placeholder.set(pane.buf)
        vim.cmd("stopinsert")
      end,
    },
    on_open = function(pane)
      -- Initialize empty buffer with placeholder
      vim.api.nvim_buf_set_lines(pane.buf, 0, -1, false, { "" })
      Placeholder.set(pane.buf)
      -- Set up autocmds for placeholder and auto-grow
      vim.api.nvim_create_autocmd({ "InsertEnter", "InsertLeave", "TextChanged" }, {
        buffer = pane.buf,
        group = layout.augroup,
        callback = function(ev)
          if not pane:is_valid() then
            return
          end
          local event = ev.event
          if event == "InsertEnter" then
            -- Clear placeholder on entering insert mode
            Placeholder.clear(pane.buf)
          elseif event == "InsertLeave" then
            -- Re-show placeholder if buffer is empty
            if not Placeholder.has_content(pane.buf) then
              Placeholder.set(pane.buf)
            end
          elseif event == "TextChanged" then
            -- Update placeholder based on content
            if not Placeholder.has_content(pane.buf) then
              Placeholder.set(pane.buf)
            else
              Placeholder.clear(pane.buf)
            end
          end
        end,
      })
      -- Auto-grow on TextChangedI
      vim.api.nvim_create_autocmd("TextChangedI", {
        buffer = pane.buf,
        group = layout.augroup,
        callback = function()
          M._autoGrow_input(pane)
        end,
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
  M.focus("sidebar")
  -- Spawn pi client
  local PiClient = require("agent-panel.pi")
  M.client = PiClient.new({})
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
  -- Close help popup if open
  if M._help_win and vim.api.nvim_win_is_valid(M._help_win) then
    pcall(vim.api.nvim_win_close, M._help_win, true)
    M._help_win = nil
  end
  -- Dispose pi client
  if M.client then
    pcall(function() M.client:dispose() end)
    M.client = nil
  end
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
