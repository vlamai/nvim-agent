---@class AgentPanel.PiClient
---@field _handle uv_process_t|nil
---@field _stdin uv_pipe_t|nil
---@field _stdout uv_pipe_t|nil
---@field _buffer string  incomplete line buffer
---@field _state "idle"|"streaming"|"disposed"
---@field _prompt_cb { on_delta?: fun(text: string), on_settled?: fun(), on_error?: fun(err: string) }
---@field _pending table<string, fun(response: table)>  command id → callback
---@field _on_exit fun(code: number)|nil
local Client = {}
Client.__index = Client

---@class AgentPanel.Pi
local M = {}

---Spawn a new pi RPC process and return a client handle.
---@param opts? { on_exit?: fun(code: number) }
---@return AgentPanel.PiClient
function M.new(opts)
  local self = setmetatable({}, Client)
  self._handle = nil
  self._stdin = nil
  self._stdout = nil
  self._buffer = ""
  self._state = "idle"
  self._prompt_cb = {}
  self._pending = {}
  self._on_exit = opts and opts.on_exit or nil
  self:_spawn()
  return self
end

---Spawn the pi process with stdin/stdout pipes.
function Client:_spawn()
  local uv = vim.uv or vim.loop

  self._stdin = uv.new_pipe(false)
  self._stdout = uv.new_pipe(false)

  local handle, _pid = uv.spawn("pi", {
    args = { "--mode", "rpc", "--no-session" },
    stdio = { self._stdin, self._stdout, nil },
  }, function(code, _signal)
    vim.schedule(function()
      self._state = "disposed"
      self:_cleanup()
      if self._on_exit then
        self._on_exit(code)
      end
    end)
  end)

  if not handle then
    error("failed to spawn pi process")
  end

  self._handle = handle

  -- Read stdout as raw bytes, split on \n only
  self._stdout:read_start(function(err, data)
    if err or data == nil then
      return
    end
    self._buffer = self._buffer .. data
    -- Split on \n only (RPC protocol requires strict LF splitting)
    while true do
      local nl = self._buffer:find("\n", 1, true)
      if not nl then break end
      local line = self._buffer:sub(1, nl - 1)
      self._buffer = self._buffer:sub(nl + 1)
      -- Strip optional trailing \r
      if line:sub(-1) == "\r" then
        line = line:sub(1, -2)
      end
      if #line > 0 then
        vim.schedule(function()
          self:_on_line(line)
        end)
      end
    end
  end)


end

---Handle a single JSON line from stdout.
---@param line string
function Client:_on_line(line)
  local ok, event = pcall(vim.json.decode, line)
  if not ok then return end
  local etype = event.type

  if etype == "response" then
    self:_on_response(event)
  elseif etype == "message_update" then
    self:_on_message_update(event)
  elseif etype == "agent_settled" then
    self:_on_agent_settled()
  elseif etype == "agent_end" then
    -- Fallback: if agent_end fires without agent_settled, treat as done
    if self._prompt_cb.on_settled and self._state == "streaming" then
      self._prompt_cb.on_settled()
      self._prompt_cb = {}
      self._state = "idle"
    end
  end
end

---Route command responses.
---@param event table
function Client:_on_response(event)
  -- Check if there's a pending callback for this command
  local cb = self._pending[event.command]
  if cb then
    self._pending[event.command] = nil
    cb(event)
    return
  end

  -- Prompt response: success/failure before streaming starts
  if event.command == "prompt" then
    if not event.success and self._prompt_cb.on_error then
      self._prompt_cb.on_error(event.error or "prompt rejected")
      self._prompt_cb = {}
      self._state = "idle"
    end
  end
end

---Handle streaming text deltas.
---@param event table
function Client:_on_message_update(event)
  local assistant_event = event.assistantMessageEvent
  if assistant_event and assistant_event.type == "text_delta" then
    if self._prompt_cb.on_delta then
      self._prompt_cb.on_delta(assistant_event.delta)
    end
  end
end

---Handle agent settled.
function Client:_on_agent_settled()
  if self._prompt_cb.on_settled then
    self._prompt_cb.on_settled()
  end
  self._prompt_cb = {}
  self._state = "idle"
end

---Send a raw command object to stdin.
---@param cmd table
function Client:_send(cmd)
  if self._state == "disposed" then
    error("client is disposed")
  end
  local json = vim.json.encode(cmd) .. "\n"
  self._stdin:write(json)
end

---Send a command and register a one-shot response callback.
---@param cmd table
---@param callback fun(response: table)
function Client:_send_with_response(cmd, callback)
  local key = cmd.type
  -- Use id field if present for correlation
  if cmd.id then
    key = cmd.id
  end
  self._pending[key] = callback
  self:_send(cmd)
end

---Send a prompt, returns immediately, streams via callbacks.
---@param message string
---@param callbacks? { on_delta?: fun(text: string), on_settled?: fun(), on_error?: fun(err: string) }
function Client:prompt(message, callbacks)
  if self._state == "streaming" then
    error("agent is busy, wait for current prompt to finish")
  end
  self._prompt_cb = callbacks or {}
  self._state = "streaming"
  self:_send({ type = "prompt", message = message })
end

---Abort the current generation.
function Client:abort()
  if self._state ~= "streaming" then return end
  self:_send({ type = "abort" })
end

---Get conversation history.
---@param callback fun(messages: table[])
function Client:get_messages(callback)
  self:_send_with_response({ type = "get_messages" }, function(resp)
    if resp.success and resp.data then
      callback(resp.data.messages or {})
    else
      callback({})
    end
  end)
end

---Get session state.
---@param callback fun(state: table)
function Client:get_state(callback)
  self:_send_with_response({ type = "get_state" }, function(resp)
    if resp.success and resp.data then
      callback(resp.data)
    else
      callback({})
    end
  end)
end

---Get list of all sessions.
---@param callback fun(entries: table[])  list of { path, title, ... }
function Client:get_entries(callback)
  self:_send_with_response({ type = "get_entries" }, function(resp)
    if resp.success and resp.data then
      callback(resp.data.entries or resp.data or {})
    else
      callback({})
    end
  end)
end

---Create a new session.
---@param callback fun(session: table|nil)  new session info or nil on error
function Client:new_session(callback)
  self:_send_with_response({ type = "new_session" }, function(resp)
    if resp.success and resp.data then
      callback(resp.data)
    else
      callback(nil)
    end
  end)
end

---Switch to a different session.
---@param sessionPath string  path to the session file
---@param callback fun(success: boolean, err?: string)
function Client:switch_session(sessionPath, callback)
  local settled = false
  self:_send_with_response({ type = "switch_session", sessionPath = sessionPath }, function(resp)
    if settled then return end
    settled = true
    if callback then
      if not resp.success then
        local err_msg = resp.error or "switch failed"
        vim.notify("  ⚠ switch_session error: " .. err_msg, vim.log.levels.WARN)
        callback(false, err_msg)
      elseif resp.data and resp.data.cancelled then
        callback(false, "switch cancelled by extension")
      else
        callback(true)
      end
    end
  end)
  -- Timeout: if no response in 10s, treat as failure
  vim.defer_fn(function()
    if not settled then
      settled = true
      self._pending["switch_session"] = nil
      if callback then
        vim.schedule(function()
          callback(false, "timeout waiting for pi response")
        end)
      end
    end
  end, 10000)
end

---Kill the process and clean up.
function Client:dispose()
  if self._state == "disposed" then return end
  self._state = "disposed"
  self:_cleanup()
  if self._handle and not self._handle:is_closing() then
    self._handle:close()
  end
end

---Clean up pipes.
function Client:_cleanup()
  if self._stdin and not self._stdin:is_closing() then
    self._stdin:close()
  end
  if self._stdout and not self._stdout:is_closing() then
    self._stdout:close()
  end
  self._stdin = nil
  self._stdout = nil
end

---Check if process is alive.
---@return boolean
function Client:is_running()
  return self._handle ~= nil and self._state ~= "disposed"
end

return M
