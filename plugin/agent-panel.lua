-- User commands for agent-panel.nvim
-- The require() is inside the callback — lazy-loading

vim.api.nvim_create_user_command("AgentPanel", function(opts)
  local args = opts.fargs
  local sub = args[1] or "toggle"

  if sub == "open" then
    require("agent-panel").open()
  elseif sub == "close" then
    require("agent-panel").close()
  elseif sub == "toggle" then
    require("agent-panel").toggle()
  else
    vim.notify("AgentPanel: unknown subcommand '" .. sub .. "'", vim.log.levels.ERROR, { title = "agent-panel.nvim" })
  end
end, {
  nargs = "?",
  desc = "Agent Panel",
  complete = function(arg_lead, cmdline, _)
    local subcmds = { "open", "close", "toggle" }
    if cmdline:match("^['<,'>]*AgentPanel[!]*%s+%w*$") then
      return vim.iter(subcmds)
        :filter(function(cmd)
          return cmd:find(arg_lead) ~= nil
        end)
        :totable()
    end
    return {}
  end,
})
