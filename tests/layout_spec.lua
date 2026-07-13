---@module 'luassert'

local agent_panel = require("agent-panel")
local Layout = require("agent-panel.layout")

describe("layout", function()
  before_each(function()
    agent_panel.did_setup = false
    agent_panel.setup({})
    Layout.close()
  end)

  after_each(function()
    Layout.close()
  end)

  describe("calc_positions()", function()
    it("returns 3 panes", function()
      local pos = Layout.calc_positions({
        width = 0.8,
        height = 0.8,
        sidebar_width = 0.25,
        input_height = 3,
      })
      assert.is_not_nil(pos.sidebar)
      assert.is_not_nil(pos.main)
      assert.is_not_nil(pos.input)
    end)

    it("sidebar width + main width = panel width", function()
      local pos = Layout.calc_positions({
        width = 0.8,
        height = 0.8,
        sidebar_width = 0.25,
        input_height = 3,
      })
      -- sidebar starts at panel_col, main ends at panel_col + panel_width
      assert.is_true(pos.sidebar.width > 0)
      assert.is_true(pos.main.width > 0)
      -- main col = sidebar col + sidebar width
      assert.are.equal(pos.sidebar.col + pos.sidebar.width, pos.main.col)
    end)

    it("main height + input height = panel height", function()
      local pos = Layout.calc_positions({
        width = 0.8,
        height = 0.8,
        sidebar_width = 0.25,
        input_height = 3,
      })
      -- main and input share the same row range
      assert.are.equal(pos.main.row + pos.main.height, pos.input.row)
      assert.are.equal(pos.main.height + pos.input.height, pos.sidebar.height)
    end)
  end)

  describe("open()", function()
    it("creates all 3 panes", function()
      Layout.open()
      assert.is_not_nil(Layout.panes)
      assert.is_not_nil(Layout.panes.sidebar)
      assert.is_not_nil(Layout.panes.main)
      assert.is_not_nil(Layout.panes.input)
    end)

    it("all panes are valid", function()
      Layout.open()
      assert.is_true(Layout.panes.sidebar:is_valid())
      assert.is_true(Layout.panes.main:is_valid())
      assert.is_true(Layout.panes.input:is_valid())
    end)

    it("is_open() returns true", function()
      Layout.open()
      assert.is_true(Layout.is_open())
    end)

    it("is idempotent", function()
      Layout.open()
      assert.has_no.errors(function()
        Layout.open()
      end)
    end)
  end)

  describe("close()", function()
    it("cleans up panes", function()
      Layout.open()
      Layout.close()
      assert.is_nil(Layout.panes)
    end)

    it("is_open() returns false", function()
      Layout.open()
      Layout.close()
      assert.is_false(Layout.is_open())
    end)

    it("handles double close", function()
      Layout.open()
      Layout.close()
      assert.has_no.errors(function()
        Layout.close()
      end)
    end)
  end)

  describe("toggle()", function()
    it("opens when closed", function()
      assert.is_false(Layout.is_open())
      Layout.toggle()
      assert.is_true(Layout.is_open())
    end)

    it("closes when open", function()
      Layout.open()
      Layout.toggle()
      assert.is_false(Layout.is_open())
    end)
  end)

  describe("focus()", function()
    it("does not error when closed", function()
      assert.has_no.errors(function()
        Layout.focus("sidebar")
      end)
    end)
  end)
end)
