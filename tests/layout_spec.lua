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

    it("sets active_pane", function()
      Layout.open()
      Layout.focus("main")
      assert.are.equal("main", Layout.active_pane)
    end)

    it("focuses the target pane window", function()
      Layout.open()
      Layout.focus("input")
      assert.are.equal(Layout.panes.input.win, vim.api.nvim_get_current_win())
    end)

    it("tracks pane transitions", function()
      Layout.open()
      Layout.focus("sidebar")
      assert.are.equal("sidebar", Layout.active_pane)
      Layout.focus("main")
      assert.are.equal("main", Layout.active_pane)
      Layout.focus("input")
      assert.are.equal("input", Layout.active_pane)
    end)
  end)

  describe("nav_right()", function()
    it("does not error when closed", function()
      assert.has_no.errors(function()
        Layout.nav_right()
      end)
    end)

    it("sidebar -> main", function()
      Layout.open()
      Layout.focus("sidebar")
      Layout.nav_right()
      assert.are.equal("main", Layout.active_pane)
    end)

    it("main -> input", function()
      Layout.open()
      Layout.focus("main")
      Layout.nav_right()
      assert.are.equal("input", Layout.active_pane)
    end)

    it("input -> sidebar (wraps)", function()
      Layout.open()
      Layout.focus("input")
      Layout.nav_right()
      assert.are.equal("sidebar", Layout.active_pane)
    end)
  end)

  describe("nav_left()", function()
    it("does not error when closed", function()
      assert.has_no.errors(function()
        Layout.nav_left()
      end)
    end)

    it("input -> main", function()
      Layout.open()
      Layout.focus("input")
      Layout.nav_left()
      assert.are.equal("main", Layout.active_pane)
    end)

    it("main -> sidebar", function()
      Layout.open()
      Layout.focus("main")
      Layout.nav_left()
      assert.are.equal("sidebar", Layout.active_pane)
    end)

    it("sidebar -> input (wraps)", function()
      Layout.open()
      Layout.focus("sidebar")
      Layout.nav_left()
      assert.are.equal("input", Layout.active_pane)
    end)
  end)

  describe("scroll", function()
    it("main pane has scrolloff set", function()
      Layout.open()
      assert.are.equal(2, vim.wo[Layout.panes.main.win].scrolloff)
    end)

    it("update_scroll_pct does not error", function()
      Layout.open()
      Layout.focus("main")
      assert.has_no.errors(function()
        Layout.update_scroll_pct(Layout.panes.main)
      end)
    end)

    it("update_scroll_pct sets extmark", function()
      Layout.open()
      Layout.focus("main")
      Layout.update_scroll_pct(Layout.panes.main)
      local Config = require("agent-panel.config")
      local marks = vim.api.nvim_buf_get_extmarks(Layout.panes.main.buf, Config.ns, 0, -1)
      assert.is_true(#marks > 0)
    end)

    it("set_lines with scroll_bottom scrolls to bottom", function()
      Layout.open()
      Layout.focus("main")
      local pane = Layout.panes.main
      pane:set_lines({ "line1", "line2", "line3", "line4", "line5" }, true)
      vim.schedule(function()
        local cursor = vim.api.nvim_win_get_cursor(pane.win)
        assert.are.equal(5, cursor[1])
      end)
    end)
  end)
end)
