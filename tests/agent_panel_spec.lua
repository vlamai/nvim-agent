---@module 'luassert'

local agent_panel = require("agent-panel")

describe("agent-panel", function()
  before_each(function()
    agent_panel.did_setup = false
    agent_panel.setup({})
  end)

  after_each(function()
    agent_panel.close()
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

  describe("open()", function()
    it("returns buffer and window handles", function()
      local buf, win = agent_panel.open()
      assert.is_not_nil(buf)
      assert.is_not_nil(win)
    end)
  end)

  describe("close()", function()
    it("handles close when not open", function()
      assert.has_no.errors(function()
        agent_panel.close()
      end)
    end)
  end)

  describe("toggle()", function()
    it("toggles the panel", function()
      agent_panel.toggle()
      local Window = require("agent-panel.window")
      assert.is_true(Window.is_open())
      agent_panel.toggle()
      assert.is_false(Window.is_open())
    end)
  end)
end)
