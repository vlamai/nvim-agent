---@module 'luassert'
local pi = require("agent-panel.pi")

describe("pi client", function()
  it("spawns and responds to prompt", function()
    local client = pi.new({})
    assert.is_not_nil(client)

    local result = {}
    client:prompt("Reply with just the word 'test'", {
      on_delta = function(text)
        table.insert(result, text)
      end,
      on_settled = function()
        result.done = true
      end,
      on_error = function(err)
        result.error = err
      end,
    })

    -- Wait up to 30s for response
    vim.wait(30000, function()
      return result.done or result.error
    end, 100)

    client:dispose()
    assert.is_true(result.done)
    assert.is_nil(result.error)
    assert.is_true(#result > 0)
  end)

  it("can abort mid-stream", function()
    local client = pi.new({})
    local settled = false

    -- Send a long-running prompt
    client:prompt("Count from 1 to 100, one number per line, slowly", {
      on_settled = function()
        settled = true
      end,
    })

    -- Give it a moment to start streaming, then abort
    vim.wait(2000, function() return false end)
    client:abort()

    -- Wait for settled
    vim.wait(10000, function() return settled end, 100)

    client:dispose()
    -- Should settle without error (abort is graceful)
    assert.is_true(settled)
  end)

  it("get_entries returns session list", function()
    local client = pi.new({})
    assert.is_not_nil(client)

    local entries = nil
    client:get_entries(function(e)
      entries = e
    end)

    -- Wait up to 10s for response
    vim.wait(10000, function() return entries ~= nil end, 100)

    client:dispose()
    assert.is_not_nil(entries)
    assert.is_table(entries)
  end)

  it("new_session creates a session", function()
    local client = pi.new({})
    assert.is_not_nil(client)

    local session = nil
    client:new_session(function(s)
      session = s
    end)

    -- Wait up to 10s for response
    vim.wait(10000, function() return session ~= nil end, 100)

    client:dispose()
    assert.is_not_nil(session)
  end)
end)
