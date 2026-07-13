---@module 'luassert'

local agent_panel = require("agent-panel")
local Window = require("agent-panel.window")

describe("window", function()
  before_each(function()
    -- Reset state
    agent_panel.did_setup = false
    agent_panel.setup({})
    Window.close()
  end)

  after_each(function()
    Window.close()
  end)

  describe("open()", function()
    it("creates a buffer and window", function()
      local buf, win = Window.open()
      assert.is_not_nil(buf)
      assert.is_not_nil(win)
      assert.is_true(vim.api.nvim_buf_is_valid(buf))
      assert.is_true(vim.api.nvim_win_is_valid(win))
    end)

    it("returns the same window if already open", function()
      local buf1, win1 = Window.open()
      local buf2, win2 = Window.open()
      assert.are.equal(buf1, buf2)
      assert.are.equal(win1, win2)
    end)

    it("creates a scratch buffer", function()
      local buf = Window.open()
      assert.are.equal("nofile", vim.bo[buf].buftype)
      assert.is_true(vim.bo[buf].swapfile == false)
    end)

    it("has correct initial content", function()
      local buf = Window.open()
      local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      assert.is_true(#lines > 0)
      -- Check that title is present
      local found_title = false
      for _, line in ipairs(lines) do
        if line:find("Agent Panel") then
          found_title = true
          break
        end
      end
      assert.is_true(found_title)
    end)

    it("opens with border", function()
      local _, win = Window.open()
      local config = vim.api.nvim_win_get_config(win)
      assert.is_not_nil(config.border)
    end)
  end)

  describe("close()", function()
    it("closes the window", function()
      Window.open()
      assert.is_true(Window.is_open())
      Window.close()
      assert.is_false(Window.is_open())
    end)

    it("handles double close gracefully", function()
      Window.open()
      Window.close()
      assert.has_no.errors(function()
        Window.close()
      end)
    end)
  end)

  describe("toggle()", function()
    it("opens when closed", function()
      assert.is_false(Window.is_open())
      Window.toggle()
      assert.is_true(Window.is_open())
    end)

    it("closes when open", function()
      Window.open()
      assert.is_true(Window.is_open())
      Window.toggle()
      assert.is_false(Window.is_open())
    end)
  end)

  describe("is_open()", function()
    it("returns false when no window exists", function()
      assert.is_false(Window.is_open())
    end)

    it("returns true when window is open", function()
      Window.open()
      assert.is_true(Window.is_open())
    end)

    it("returns false after close", function()
      Window.open()
      Window.close()
      assert.is_false(Window.is_open())
    end)
  end)

  describe("keymaps", function()
    it("sets 'q' to close the window", function()
      local buf = Window.open()
      local maps = vim.api.nvim_buf_get_keymap(buf, "n")
      local found_q = false
      for _, m in ipairs(maps) do
        if m.lhs == "q" then
          found_q = true
          assert.are.equal("Close agent panel", m.desc)
          break
        end
      end
      assert.is_true(found_q)
    end)

    it("sets '<Esc>' to close the window", function()
      local buf = Window.open()
      local maps = vim.api.nvim_buf_get_keymap(buf, "n")
      local found_esc = false
      for _, m in ipairs(maps) do
        if m.lhs == "<Esc>" then
          found_esc = true
          assert.are.equal("Close agent panel", m.desc)
          break
        end
      end
      assert.is_true(found_esc)
    end)
  end)
end)
