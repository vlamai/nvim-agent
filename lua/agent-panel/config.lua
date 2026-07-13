---@class AgentPanel.Config
---@field width number|nil Window width (nil = auto)
---@field height number|nil Window height (nil = auto)
---@field title string Window title
---@field border string Border style ("none", "single", "double", "rounded", "solid", "shadow")
local M = {}

---@class AgentPanel.DefaultOptions
local defaults = {
  width = nil,  -- auto: 80% of editor width
  height = nil, -- auto: 80% of editor height
  title = " Agent Panel ",
  border = "rounded",
}

local config = vim.deepcopy(defaults)

-- Access config values directly: Config.width, Config.height
setmetatable(M, {
  __index = function(_, key)
    return config[key]
  end,
})

-- Created at module load — always available
M.augroup = vim.api.nvim_create_augroup("agent-panel", { clear = true })
M.ns = vim.api.nvim_create_namespace("agent-panel")

---Extend the defaults options table with the user options
---@param opts? AgentPanel.UserOptions plugin options
function M.setup(opts)
  config = vim.tbl_deep_extend("force", {}, vim.deepcopy(defaults), opts or {})

  -- Validate config
  if config.width ~= nil and type(config.width) ~= "number" then
    local Util = require("agent-panel.util")
    Util.error(("Invalid 'width' option: expected number, got %s"):format(type(config.width)))
    config.width = defaults.width
  end
  if config.height ~= nil and type(config.height) ~= "number" then
    local Util = require("agent-panel.util")
    Util.error(("Invalid 'height' option: expected number, got %s"):format(type(config.height)))
    config.height = defaults.height
  end
end

return M
