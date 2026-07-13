---@class AgentPanel.Plugin
local M = {}

M.did_setup = false

---Setup the agent panel plugin
---@param opts? AgentPanel.UserOptions plugin options
function M.setup(opts)
  if M.did_setup then
    local Util = require("agent-panel.util")
    return Util.warn("agent-panel.nvim is already setup")
  end
  M.did_setup = true
  require("agent-panel.config").setup(opts)
end

---Open the agent panel floating window
---@return integer buf, integer win
function M.open()
  local Window = require("agent-panel.window")
  return Window.open()
end

---Close the agent panel
function M.close()
  local Window = require("agent-panel.window")
  Window.close()
end

---Toggle the agent panel
function M.toggle()
  local Window = require("agent-panel.window")
  Window.toggle()
end

return M
