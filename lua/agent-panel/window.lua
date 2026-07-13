---@class AgentPanel.Window
local M = {}

-- State tracking
M.buf = nil ---@type integer|nil
M.win = nil ---@type integer|nil

---Calculate window dimensions and position
---@return {width: integer, height: integer, row: integer, col: integer}
local function calc_win_config()
  local Config = require("agent-panel.config")

  local editor_width = vim.o.columns
  local editor_height = vim.o.lines

  -- Default: 80% of editor size
  local width = Config.width or math.floor(editor_width * 0.8)
  local height = Config.height or math.floor(editor_height * 0.8)

  -- Clamp to editor size
  width = math.min(width, editor_width - 4)
  height = math.min(height, editor_height - 4)

  -- Center the window
  local row = math.floor((editor_height - height) / 2)
  local col = math.floor((editor_width - width) / 2)

  return { width = width, height = height, row = row, col = col }
end

---Create a scratch buffer for the panel
---@return integer buf
local function create_buf()
  local buf = vim.api.nvim_create_buf(false, true) -- unlisted, scratch
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "hide"
  vim.bo[buf].swapfile = false

  -- Set initial content
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
    "",
    "  Agent Panel",
    "  ────────────────────────────────",
    "",
    "  This is a floating window panel.",
    "",
    "  Press 'q' to close.",
    "",
  })

  return buf
end

---Set buffer-local keymaps for the panel
---@param buf integer
local function set_keymaps(buf)
  local opts = { buffer = buf, nowait = true, silent = true }

  vim.keymap.set("n", "q", function()
    M.close()
  end, vim.tbl_extend("force", opts, { desc = "Close agent panel" }))

  vim.keymap.set("n", "<Esc>", function()
    M.close()
  end, vim.tbl_extend("force", opts, { desc = "Close agent panel" }))
end

---Open the floating window
---@return integer buf, integer win
function M.open()
  -- If already open, just focus it
  if M.win and vim.api.nvim_win_is_valid(M.win) then
    vim.api.nvim_set_current_win(M.win)
    return M.buf, M.win
  end

  local Config = require("agent-panel.config")

  -- Create buffer
  M.buf = create_buf()

  -- Calculate window config
  local win_config = calc_win_config()

  -- Open floating window
  M.win = vim.api.nvim_open_win(M.buf, true, {
    relative = "editor",
    width = win_config.width,
    height = win_config.height,
    row = win_config.row,
    col = win_config.col,
    style = "minimal",
    border = Config.border,
    title = Config.title,
    title_pos = "center",
  })

  -- Set window options
  vim.wo[M.win].wrap = true
  vim.wo[M.win].cursorline = true

  -- Set keymaps
  set_keymaps(M.buf)

  -- Auto-close on BufLeave
  vim.api.nvim_create_autocmd("BufLeave", {
    buffer = M.buf,
    once = true,
    callback = function()
      -- Defer to allow window switching
      vim.schedule(function()
        M.close()
      end)
    end,
  })

  return M.buf, M.win
end

---Close the floating window
function M.close()
  if M.win and vim.api.nvim_win_is_valid(M.win) then
    pcall(vim.api.nvim_win_close, M.win, true)
    M.win = nil
  end
  if M.buf and vim.api.nvim_buf_is_valid(M.buf) then
    pcall(vim.api.nvim_buf_delete, M.buf, { force = true })
    M.buf = nil
  end
end

---Toggle the floating window
function M.toggle()
  if M.win and vim.api.nvim_win_is_valid(M.win) then
    M.close()
  else
    M.open()
  end
end

---Check if the window is currently open
---@return boolean
function M.is_open()
  return M.win ~= nil and vim.api.nvim_win_is_valid(M.win)
end

return M
