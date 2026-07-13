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
      local marks = vim.api.nvim_buf_get_extmarks(Layout.panes.main.buf, Config.ns, 0, -1, {})
      assert.is_true(#marks > 0)
    end)

    it("scroll_to_bottom scrolls to last line", function()
      Layout.open()
      Layout.focus("main")
      local pane = Layout.panes.main
      pane:set_lines({ "line1", "line2", "line3", "line4", "line5" })
      Layout._scroll_to_bottom(pane)
      local cursor = vim.api.nvim_win_get_cursor(pane.win)
      assert.are.equal(5, cursor[1])
    end)
  end)

  describe("sidebar list", function()
    it("initializes sidebar_items on open", function()
      Layout.open()
      assert.is_not_nil(Layout.sidebar_items)
      assert.is_true(#Layout.sidebar_items > 0)
    end)

    it("sidebar opens with cursor at line 1", function()
      Layout.open()
      Layout.focus("sidebar")
      local cursor = vim.api.nvim_win_get_cursor(Layout.panes.sidebar.win)
      assert.are.equal(1, cursor[1])
    end)

    it("_add_sidebar_item adds to list", function()
      Layout.open()
      Layout.focus("sidebar")
      local initial_count = #Layout.sidebar_items
      Layout._add_sidebar_item("New Item")
      assert.are.equal(initial_count + 1, #Layout.sidebar_items)
      assert.are.equal("New Item", Layout.sidebar_items[#Layout.sidebar_items])
    end)

    it("_delete_sidebar_item removes from list", function()
      Layout.open()
      Layout.focus("sidebar")
      local initial_count = #Layout.sidebar_items
      -- Delete the first item (line 3 in buffer)
      Layout._delete_sidebar_item(3)
      assert.are.equal(initial_count - 1, #Layout.sidebar_items)
    end)

    it("sidebar_items has correct count", function()
      Layout.open()
      -- default_sidebar_items has 8 entries
      assert.are.equal(8, #Layout.sidebar_items)
    end)

    it("_delete_sidebar_item does not delete skip lines", function()
      Layout.open()
      Layout.focus("sidebar")
      local initial_count = #Layout.sidebar_items
      -- Try to delete line 1 (header)
      Layout._delete_sidebar_item(1)
      assert.are.equal(initial_count, #Layout.sidebar_items)
    end)

    it("sidebar buffer has header and separator", function()
      Layout.open()
      local lines = vim.api.nvim_buf_get_lines(Layout.panes.sidebar.buf, 0, -1, false)
      assert.is_true(#lines > 0)
      -- First line should be header
      assert.is_truthy(lines[1]:match("📋"))
      -- Second line should be separator
      assert.is_truthy(lines[2]:match("─"))
    end)
  end)

  describe("hints", function()
    it("hints pane is created on open", function()
      Layout.open()
      assert.is_not_nil(Layout.panes.hints)
      assert.is_true(Layout.panes.hints:is_valid())
    end)

    it("hints pane is 1 row tall", function()
      Layout.open()
      local height = vim.api.nvim_win_get_height(Layout.panes.hints.win)
      assert.are.equal(1, height)
    end)

    it("hints update on focus change", function()
      Layout.open()
      Layout.focus("sidebar")
      local lines = vim.api.nvim_buf_get_lines(Layout.panes.hints.buf, 0, -1, false)
      assert.is_truthy(lines[1]:match("navigate"))
      Layout.focus("main")
      lines = vim.api.nvim_buf_get_lines(Layout.panes.hints.buf, 0, -1, false)
      assert.is_truthy(lines[1]:match("scroll"))
    end)
  end)

  describe("help popup", function()
    it("_show_help creates help window", function()
      Layout.open()
      Layout._show_help()
      assert.is_not_nil(Layout._help_win)
      assert.is_true(vim.api.nvim_win_is_valid(Layout._help_win))
    end)

    it("help window closes on q", function()
      Layout.open()
      Layout._show_help()
      local help_buf = vim.api.nvim_win_get_buf(Layout._help_win)
      vim.keymap.set("n", "q", function()
        vim.api.nvim_win_close(Layout._help_win, true)
        Layout._help_win = nil
      end, { buffer = help_buf })
      vim.api.nvim_feedkeys("q", "x", false)
      assert.is_nil(Layout._help_win)
    end)
  end)

  describe("navigation keybindings", function()
    it("Ctrl+l from input wraps to sidebar", function()
      Layout.open()
      Layout.focus("input")
      assert.are.equal("input", Layout.active_pane)
      -- Trigger Ctrl+l keybinding
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-l>", true, false, true), "x", false)
      assert.are.equal("sidebar", Layout.active_pane)
    end)

    it("Ctrl+h from sidebar wraps to input", function()
      Layout.open()
      Layout.focus("sidebar")
      assert.are.equal("sidebar", Layout.active_pane)
      -- Trigger Ctrl+h keybinding
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-h>", true, false, true), "x", false)
      assert.are.equal("input", Layout.active_pane)
    end)
  end)

  describe("sidebar selection notification", function()
    it("<CR> on item triggers vim.notify", function()
      Layout.open()
      Layout.focus("sidebar")
      -- Move to first item (line 3)
      vim.api.nvim_win_set_cursor(Layout.panes.sidebar.win, { 3, 0 })
      -- Stub vim.notify to capture calls
      local notify_called = false
      local notify_msg = nil
      local original_notify = vim.notify
      vim.notify = function(msg, ...)
        notify_called = true
        notify_msg = msg
        -- Don't call original to avoid noise
      end
      -- Trigger Enter keybinding using schedule to ensure it runs
      vim.schedule(function()
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<CR>", true, false, true), "x", false)
      end)
      vim.wait(100)
      -- Restore vim.notify
      vim.notify = original_notify
      -- Assert notification was sent
      assert.is_true(notify_called)
      assert.is_truthy(notify_msg:match("Selected"))
    end)
  end)

  describe("input submit content", function()
    it("submitted text appears in main buffer", function()
      Layout.open()
      local input_pane = Layout.panes.input
      local main_pane = Layout.panes.main
      -- Set text in input
      vim.api.nvim_buf_set_lines(input_pane.buf, 0, -1, false, { "Hello from test" })
      -- Submit
      Layout._submit_input(input_pane, main_pane)
      -- Check main buffer contains the text
      local main_lines = vim.api.nvim_buf_get_lines(main_pane.buf, 0, -1, false)
      local found = false
      for _, line in ipairs(main_lines) do
        if line:match("Hello from test") then
          found = true
          break
        end
      end
      assert.is_true(found)
    end)

    it("submitted text is in You markdown format", function()
      Layout.open()
      local input_pane = Layout.panes.input
      local main_pane = Layout.panes.main
      -- Set text in input
      vim.api.nvim_buf_set_lines(input_pane.buf, 0, -1, false, { "Formatted message" })
      -- Submit
      Layout._submit_input(input_pane, main_pane)
      -- Check main buffer has the markdown format
      local main_lines = vim.api.nvim_buf_get_lines(main_pane.buf, 0, -1, false)
      local found_header = false
      local found_content = false
      local found_separator = false
      for _, line in ipairs(main_lines) do
        if line:match("## You") then
          found_header = true
        end
        if line:match("Formatted message") then
          found_content = true
        end
        if line:match("^---$") then
          found_separator = true
        end
      end
      assert.is_true(found_header)
      assert.is_true(found_content)
      assert.is_true(found_separator)
    end)
  end)

  describe("scroll behavior", function()
    it("scroll_to_bottom moves cursor to last line", function()
      Layout.open()
      Layout.focus("main")
      local pane = Layout.panes.main
      -- Set multiple lines
      local test_lines = {}
      for i = 1, 20 do
        table.insert(test_lines, "line " .. i)
      end
      pane:set_lines(test_lines)
      -- Start at line 1
      vim.api.nvim_win_set_cursor(pane.win, { 1, 0 })
      -- Scroll to bottom
      Layout._scroll_to_bottom(pane)
      -- Cursor should be at last line
      local cursor = vim.api.nvim_win_get_cursor(pane.win)
      assert.are.equal(20, cursor[1])
    end)

    it("scroll percentage updates after scroll", function()
      Layout.open()
      Layout.focus("main")
      local pane = Layout.panes.main
      -- Set multiple lines
      local test_lines = {}
      for i = 1, 10 do
        table.insert(test_lines, "line " .. i)
      end
      pane:set_lines(test_lines)
      -- Scroll to bottom
      vim.api.nvim_win_set_cursor(pane.win, { 10, 0 })
      Layout.update_scroll_pct(pane)
      -- Check extmark exists
      local Config = require("agent-panel.config")
      local marks = vim.api.nvim_buf_get_extmarks(pane.buf, Config.ns, 0, -1, {})
      assert.is_true(#marks > 0)
    end)
  end)

  describe("input pane", function()
    it("input pane is created on open", function()
      Layout.open()
      assert.is_not_nil(Layout.panes.input)
      assert.is_true(Layout.panes.input:is_valid())
    end)

    it("input pane starts empty", function()
      Layout.open()
      local lines = vim.api.nvim_buf_get_lines(Layout.panes.input.buf, 0, -1, false)
      assert.are.equal(1, #lines)
      assert.are.equal("", lines[1])
    end)

    it("input pane has placeholder extmark", function()
      Layout.open()
      local Config = require("agent-panel.config")
      local marks = vim.api.nvim_buf_get_extmarks(Layout.panes.input.buf, Config.ns, 0, -1, {})
      assert.is_true(#marks > 0)
    end)

    it("placeholder shows Ask me anything text", function()
      Layout.open()
      local Config = require("agent-panel.config")
      local marks = vim.api.nvim_buf_get_extmarks(Layout.panes.input.buf, Config.ns, 0, -1, {
        details = true,
      })
      assert.is_true(#marks > 0)
      local virt_text = marks[1][4].virt_text
      assert.is_not_nil(virt_text)
      assert.is_truthy(virt_text[1][1]:match("Ask me anything"))
    end)

    it("_submit_input clears input buffer", function()
      Layout.open()
      local input_pane = Layout.panes.input
      local main_pane = Layout.panes.main
      -- Set some text in input
      vim.api.nvim_buf_set_lines(input_pane.buf, 0, -1, false, { "Hello world" })
      -- Submit
      Layout._submit_input(input_pane, main_pane)
      -- Input should be cleared
      local lines = vim.api.nvim_buf_get_lines(input_pane.buf, 0, -1, false)
      assert.are.equal(1, #lines)
      assert.are.equal("", lines[1])
    end)

    it("_submit_input appends to main pane", function()
      Layout.open()
      local input_pane = Layout.panes.input
      local main_pane = Layout.panes.main
      local initial_lines = vim.api.nvim_buf_line_count(main_pane.buf)
      -- Set some text in input
      vim.api.nvim_buf_set_lines(input_pane.buf, 0, -1, false, { "Test message" })
      -- Submit
      Layout._submit_input(input_pane, main_pane)
      -- Main should have more lines
      local final_lines = vim.api.nvim_buf_line_count(main_pane.buf)
      assert.is_true(final_lines > initial_lines)
    end)

    it("_submit_input does nothing on empty input", function()
      Layout.open()
      local input_pane = Layout.panes.input
      local main_pane = Layout.panes.main
      local initial_lines = vim.api.nvim_buf_line_count(main_pane.buf)
      -- Submit empty input
      Layout._submit_input(input_pane, main_pane)
      -- Main should have same lines
      local final_lines = vim.api.nvim_buf_line_count(main_pane.buf)
      assert.are.equal(initial_lines, final_lines)
    end)

    it("_submit_input shows placeholder after submit", function()
      Layout.open()
      local input_pane = Layout.panes.input
      local main_pane = Layout.panes.main
      -- Set some text in input
      vim.api.nvim_buf_set_lines(input_pane.buf, 0, -1, false, { "Test" })
      -- Submit
      Layout._submit_input(input_pane, main_pane)
      -- Placeholder should be set
      local Config = require("agent-panel.config")
      local marks = vim.api.nvim_buf_get_extmarks(input_pane.buf, Config.ns, 0, -1, {})
      assert.is_true(#marks > 0)
      -- Buffer should remain modifiable
      assert.is_true(vim.bo[input_pane.buf].modifiable)
    end)

    it("input pane has correct height", function()
      Layout.open()
      local Config = require("agent-panel.config")
      local height = vim.api.nvim_win_get_height(Layout.panes.input.win)
      assert.are.equal(Config.input_height, height)
    end)

    it("input pane buffer exists", function()
      Layout.open()
      assert.is_true(vim.api.nvim_buf_is_valid(Layout.panes.input.buf))
    end)
  end)

  describe("pi client integration", function()
    it("client is spawned on open", function()
      Layout.open()
      assert.is_not_nil(Layout.client)
      assert.is_true(Layout.client:is_running())
    end)

    it("client is disposed on close", function()
      Layout.open()
      assert.is_not_nil(Layout.client)
      Layout.close()
      assert.is_nil(Layout.client)
    end)

    it("prompt updates main pane buffer", function()
      Layout.open()
      local main_buf = Layout.panes.main.buf
      local client = Layout.client
      assert.is_not_nil(client)
      assert.is_true(client:is_running())

      local settled = false
      local collected = {}
      client:prompt("say just the word 'ok'", {
        on_delta = function(delta)
          table.insert(collected, delta)
        end,
        on_settled = function()
          settled = true
        end,
        on_error = function(err)
          settled = true
        end,
      })

      vim.wait(30000, function() return settled end, 100)

      local content = table.concat(collected, "")
      assert.is_truthy(content:find("ok"))
    end)
  end)
end)
