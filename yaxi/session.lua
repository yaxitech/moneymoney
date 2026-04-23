-- SPDX-License-Identifier: MIT
-- Author: Vincent Haupert <vincent.haupert@yaxi.tech>

-- YAXI Session — State container for a single MoneyMoney session

---The `binary` alias is defined in `routex-client/result-types.lua`.

local log = require("routex-client.logging").defaultLogger()

local rc = require("routex-client")
local RoutexClient = rc.RoutexClient
local Result = rc.Result
local Dialog = rc.Dialog
local Redirect = rc.Redirect
local RedirectHandle = rc.RedirectHandle

local TicketGenerator = require("yaxi.ticket").Generator
local MMHttpClient = require("yaxi.mm.http").MMHttpClient

---@class YAXI.MoneyMoney.Session.BalanceEntry
---@field balance number Primary balance amount
---@field pendingBalance number? Pending balance amount

---@alias YAXI.MoneyMoney.Session.BalancesCache table<string, YAXI.MoneyMoney.Session.BalanceEntry>
---@alias YAXI.MoneyMoney.Session.TransactionsCache table<string, MM.Transaction[]>

---@class YAXI.MoneyMoney.Session
---@field apiKeySecret string Base64-encoded API key secret for JWT verification
---@field connection YAXI.MoneyMoney.Connection The bank connection this session operates on
---@field client YAXI.RoutexClient.RoutexClient `RoutexClient` instance for API calls
---@field ticketGenerator YAXI.MoneyMoney.Ticket.Generator Generates signed YAXI service tickets
---@field credentials YAXI.RoutexClient.Credentials Credentials passed to each service call
---@field connectionInfo YAXI.RoutexClient.ConnectionInfo Metadata from `RoutexClient:info()` (credentials model, labels)
---@field dialog YAXI.RoutexClient.Dialog? Current `Dialog` interrupt (if any)
---@field redirect YAXI.RoutexClient.Redirect? Current `Redirect` interrupt (if any)
---@field result YAXI.RoutexClient.Result? Current `Result` (if service completed)
---@field savedSession binary? Latest routex session token seen during this MoneyMoney session (for reuse across service calls)
---@field activeTicket string? YAXI ticket JWT for the current service call
---@field activeService YAXI.RoutexClient.Service? Current service name
---@field phase YAXI.MoneyMoney.Session.Phase? Multi-phase tracking for `RefreshAccount`
---@field balancesResult YAXI.RoutexClient.Result? Stashed balances `Result` during `RefreshAccount`
---@field balancesCache YAXI.MoneyMoney.Session.BalancesCache? Decoded balances keyed by IBAN
---@field transactionsCache YAXI.MoneyMoney.Session.TransactionsCache? Decoded transactions keyed by IBAN
---@field sessionType MM.SessionType? MoneyMoney session type (e.g. `"refresh"`, `"new account"`)
local Session = {}
Session.__index = Session

---Create a new `Session` for the given `Connection`.
---Initializes `RoutexClient`, `TicketGenerator`, loads `connectionData` from
---`LocalStorage`, and fetches `ConnectionInfo` via `RoutexClient:info()` (free call).
---@param connection YAXI.MoneyMoney.Connection
---@param apiKeyId string
---@param apiKeySecret string
---@param version number
---@return YAXI.MoneyMoney.Session
function Session:new(connection, apiKeyId, apiKeySecret, version)
  ---@type YAXI.MoneyMoney.Session
  local obj = setmetatable({}, self)

  obj.apiKeySecret = apiKeySecret
  obj.connection = connection
  obj.client = RoutexClient:new("https://api.yaxi.tech", MMHttpClient:new(version))
  obj.client:setRedirectUri("https://service.moneymoney-app.com/1/redirect")
  obj.ticketGenerator = TicketGenerator:new(apiKeyId, apiKeySecret)

  local connectionData = LocalStorage[connection.id] --[[@as string?]]
  log:debug("Session for %s (connectionData=%s)", connection.service, connectionData and "present" or "absent")

  -- Fetch `ConnectionInfo` (free call)
  local infoTicket = obj.ticketGenerator:accounts(MM.uuid())
  obj.connectionInfo = obj.client:info({
    ticket = infoTicket,
    connectionId = connection.id,
  })

  local model = obj.connectionInfo.credentials
  local credentialModel = model.full and "full" or model.userId and "userId" or "none"
  log:debug("Credentials model: %s", credentialModel)

  obj.credentials = {
    connectionId = obj.connectionInfo.id,
    connectionData = connectionData --[[@as binary]],
  }
  return obj
end

---Set credentials from the MoneyMoney credentials array based on
---the `ConnectionInfo.credentials` model (`full`, `userId`, or `none`).
---@param mmCredentials string[]
function Session:setCredentials(mmCredentials)
  local model = self.connectionInfo.credentials
  if model.full then
    self.credentials.userId = mmCredentials[1]
    self.credentials.password = mmCredentials[2]
  elseif model.userId then
    self.credentials.userId = mmCredentials[1]
  end
  -- `none`: no credentials needed
end

---Return the best available routex session token.
---Prefers the current result's session, falls back to the last seen session
---from a prior service call within this MoneyMoney session.
---@return binary?
function Session:routexSession()
  return (self.result and self.result.session) or self.savedSession
end

---Reset interrupt state (`dialog`, `redirect`, `result`).
function Session:resetInterruptState()
  self.dialog = nil
  self.redirect = nil
  self.result = nil
end

---Classify and store an `OBResponse` into the appropriate state field
---(`result`, `dialog`, or `redirect`). Updates `connectionData` when a `Result` arrives.
---@param obResponse YAXI.RoutexClient.OBResponse
function Session:storeResponse(obResponse)
  self:resetInterruptState()

  if obResponse:isInstanceOf(Result) then
    self.result = obResponse --[[@as YAXI.RoutexClient.Result]]
    log:debug("Received Result for %s", self.activeService or "unknown")
    if self.result.connectionData then
      self.credentials.connectionData = self.result.connectionData
    end
    self.savedSession = self.result.session
  elseif obResponse:isInstanceOf(Dialog) then
    self.dialog = obResponse --[[@as YAXI.RoutexClient.Dialog]]
    log:debug("Received Dialog for %s", self.activeService or "unknown")
  elseif obResponse:isInstanceOf(Redirect) then
    self.redirect = obResponse --[[@as YAXI.RoutexClient.Redirect]]
    log:debug("Received Redirect for %s", self.activeService or "unknown")
  elseif obResponse:isInstanceOf(RedirectHandle) then
    error("Received RedirectHandle but expected Redirect. Ensure a redirect URI is configured.")
  else
    error(string.format("Unexpected OBResponse type: %s", type(obResponse)))
  end
end

---Persist `connectionData` to `LocalStorage` and clean up any stale session data.
function Session:persist()
  if self.credentials.connectionData then
    LocalStorage[self.connection.id] = self.credentials.connectionData --[[@as any]]
    log:debug("Persisted connectionData for %s", self.connection.service)
  end

  -- Routex sessions are short-lived and must not be persisted across MoneyMoney
  -- sessions. Clear any stale session data that may have been saved by older versions.
  LocalStorage[self.connection.id .. ":session"] = nil
end

return Session
