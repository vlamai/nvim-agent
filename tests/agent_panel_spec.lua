---@module 'luassert'

local agent_panel = require("agent-panel")
local Layout = require("agent-panel.layout")

describe("agent-panel", function()
  before_each(function()
    agent_panel.did_setup = false
    agent_panel.setup({})
    Layout.close()
  end)

  after_each(function()
    Layout.close()
  end)

  describe("setup()", function()
    it("sets did_setup to true", function()
      assert.is_true(agent_panel.did_setup)
    end)

    it("warns on double setup", function()
      assert.has_no.errors(function()
        agent_panel.setup({})
      end)
    end)
  end)

  describe("toggle()", function()
    it("toggles the panel", function()
      agent_panel.toggle()
      assert.is_true(Layout.is_open())
      agent_panel.toggle()
      assert.is_false(Layout.is_open())
    end)
  end)
end)
