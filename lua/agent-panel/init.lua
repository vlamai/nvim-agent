---@class AgentPanel.Plugin
local M = {}

M.did_setup = false

---@param opts? AgentPanel.UserOptions
function M.setup(opts)
  if M.did_setup then
    local Util = require("agent-panel.util")
    return Util.warn("agent-panel.nvim is already setup")
  end
  M.did_setup = true
  require("agent-panel.config").setup(opts)
end

function M.open()
  require("agent-panel.layout").open()
end

function M.close()
  require("agent-panel.layout").close()
end

function M.toggle()
  require("agent-panel.layout").toggle()
end

---@return boolean
function M.is_open()
  return require("agent-panel.layout").is_open()
end

---@param name "sidebar"|"main"|"input"
function M.focus(name)
  local layout = require("agent-panel.layout")
  if layout.panes and layout.panes[name] then
    layout.panes[name]:focus()
  end
end

return M
