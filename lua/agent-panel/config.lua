---@class AgentPanel.Config
---@field width number|nil Window width (nil = 0.8)
---@field height number|nil Window height (nil = 0.8)
---@field border string Border style
---@field sidebar_width number Sidebar width (ratio or absolute)
---@field input_height number Input pane height in rows
local M = {}

---@class AgentPanel.DefaultOptions
local defaults = {
  width = 0.8,           -- 80% of editor width
  height = 0.8,          -- 80% of editor height
  border = "rounded",
  sidebar_width = 0.25,  -- 25% of panel width
  input_height = 3,      -- rows
}

local config = vim.deepcopy(defaults)

setmetatable(M, {
  __index = function(_, key)
    return config[key]
  end,
})

M.augroup = vim.api.nvim_create_augroup("agent-panel", { clear = true })
M.ns = vim.api.nvim_create_namespace("agent-panel")

---@param opts? AgentPanel.UserOptions
function M.setup(opts)
  config = vim.tbl_deep_extend("force", {}, vim.deepcopy(defaults), opts or {})
end

return M
