---@class AgentPanel.Pane
---@field name string
---@field buf integer
---@field win integer|nil
---@field opts AgentPanel.PaneOpts
local Pane = {}
Pane.__index = Pane

---@class AgentPanel.PaneOpts
---@field ft string|nil
---@field wo table<string, any>
---@field bo table<string, any>
---@field keymaps table<string, fun(pane: AgentPanel.Pane)>
---@field on_open fun(pane: AgentPanel.Pane)|nil

---@param name string
---@param opts AgentPanel.PaneOpts
function Pane.new(name, opts)
  local self = setmetatable({}, Pane)
  self.name = name
  self.opts = opts
  self.buf = self:_create_buf()
  self.win = nil
  return self
end

---@return integer
function Pane:_create_buf()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "hide"
  vim.bo[buf].swapfile = false
  if self.opts.ft then
    vim.bo[buf].filetype = self.opts.ft
  end
  for k, v in pairs(self.opts.bo or {}) do
    vim.bo[buf][k] = v
  end
  return buf
end

---@param win_config table
function Pane:open(win_config)
  if self.win and vim.api.nvim_win_is_valid(self.win) then
    vim.api.nvim_win_set_config(self.win, win_config)
    return
  end
  win_config.style = "minimal"
  self.win = vim.api.nvim_open_win(self.buf, false, win_config)
  for k, v in pairs(self.opts.wo or {}) do
    vim.wo[self.win][k] = v
  end
  self:_set_keymaps()
  if self.opts.on_open then
    self.opts.on_open(self)
  end
end

function Pane:_set_keymaps()
  local base = { buffer = self.buf, nowait = true, silent = true }
  for lhs, rhs in pairs(self.opts.keymaps or {}) do
    vim.keymap.set("n", lhs, function()
      rhs(self)
    end, vim.tbl_extend("force", base, { desc = "agent-panel:" .. self.name }))
  end
end

function Pane:close()
  if self.win and vim.api.nvim_win_is_valid(self.win) then
    pcall(vim.api.nvim_win_close, self.win, true)
    self.win = nil
  end
end

function Pane:destroy()
  self:close()
  if self.buf and vim.api.nvim_buf_is_valid(self.buf) then
    pcall(vim.api.nvim_buf_delete, self.buf, { force = true })
  end
end

---@return boolean
function Pane:is_valid()
  return self.win ~= nil
    and vim.api.nvim_win_is_valid(self.win)
    and self.buf ~= nil
    and vim.api.nvim_buf_is_valid(self.buf)
end

function Pane:focus()
  if self:is_valid() then
    vim.api.nvim_set_current_win(self.win)
  end
end

---@param lines string[]
---@param scroll_bottom boolean|nil scroll to bottom after setting lines
function Pane:set_lines(lines, scroll_bottom)
  if vim.api.nvim_buf_is_valid(self.buf) then
    vim.bo[self.buf].modifiable = true
    vim.api.nvim_buf_set_lines(self.buf, 0, -1, false, lines)
    vim.bo[self.buf].modifiable = false
    if scroll_bottom and self:is_valid() then
      vim.schedule(function()
        if self:is_valid() then
          local line_count = vim.api.nvim_buf_line_count(self.buf)
          pcall(vim.api.nvim_win_set_cursor, self.win, { line_count, 0 })
        end
      end)
    end
  end
end

return Pane
