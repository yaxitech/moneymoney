-- SPDX-License-Identifier: MIT
-- Author: Vincent Haupert <vincent.haupert@yaxi.tech>

-- Error handling for the YAXI MoneyMoney extension.

local log = (require("routex-client.logging") --[[@as lualogging]]).defaultLogger()

local rc = require("routex-client")
local InvalidCredentialsError = rc.InvalidCredentialsError
local CanceledError = rc.CanceledError
local UnauthorizedError = rc.UnauthorizedError
local ConsentExpiredError = rc.ConsentExpiredError

local traces = require("yaxi.traces")

local M = {}

---Handle YAXI errors before returning them to MoneyMoney.
---Maps `RoutexClient.Error` subclasses to appropriate MoneyMoney responses.
---@param session YAXI.MoneyMoney.Session? Current session (may be nil)
---@param err any
---@return string
function M.errorHandler(session, err)
  if type(err) == "string" then
    return err
  end

  if type(err) ~= "table" or not err.isInstanceOf then
    local msg = type(err) == "table" and JSON():set(err):json() or tostring(err)
    log:error("Untyped error: %s", msg)
    return string.format("Err: %s", msg)
  end

  ---@type YAXI.RoutexClient.Error
  local yaxiErr = err
  ---@type string?
  local userMessage = (yaxiErr --[[@as table]])["userMessage"]

  -- Save trace for debugging (before early returns so trace is always captured)
  local tracePath = nil
  if session and session.activeService and session.activeTicket then
    tracePath = traces.write(session)
  end

  ---Append trace file path to a message, if available.
  ---@param msg string
  ---@return string
  local function withTrace(msg)
    if not tracePath then
      return msg
    end
    return string.format("%s\n\nEncrypted YAXI trace file:\n%s", msg, tracePath)
  end

  if yaxiErr:isInstanceOf(InvalidCredentialsError) then
    return LoginFailed
  end

  if yaxiErr:isInstanceOf(UnauthorizedError) or yaxiErr:isInstanceOf(ConsentExpiredError) then
    -- Clear stale connection data
    if session then
      log:debug("Clearing connectionData for %s due to %s", session.connection.service, yaxiErr.name)
      LocalStorage[session.connection.id] = nil
    end
    return withTrace(userMessage or yaxiErr.message or "Authorization expired. Please try again.")
  end

  if yaxiErr:isInstanceOf(CanceledError) then
    return withTrace(userMessage or yaxiErr.message)
  end

  -- All other errors with userMessage: prefer it
  if userMessage then
    return withTrace(userMessage)
  end

  return withTrace(string.format("%s: %s", yaxiErr.name, yaxiErr.message))
end

---Wrap a function in `xpcall` with the shared `errorHandler`.
---@param session YAXI.MoneyMoney.Session? Current session (may be nil during setup)
---@param fn function
---@param ... any
---@return any
function M.protected(session, fn, ...)
  local args = { ... }
  local _ok, result = xpcall(function()
    return fn(table.unpack(args))
  end, function(err)
    return M.errorHandler(session, err)
  end)
  return result
end

return M
