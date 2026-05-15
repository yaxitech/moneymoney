-- SPDX-License-Identifier: MIT
-- Author: Vincent Haupert <vincent.haupert@yaxi.tech>

local log = (require("routex-client.logging") --[[@as lualogging]]).defaultLogger()

local manifest = require("yaxi.manifest")

local base64 = require("routex-client.util.base64")

local Connection = require("yaxi.connections")
local Session = require("yaxi.session")
local accountMapping = require("yaxi.mapping.account")
local enum = require("yaxi.enum")
local util = require("yaxi.util")

local Phase = enum.Phase
local StorageKey = enum.StorageKey
local VopMode = enum.VopMode
---Maximum number of days that `RefreshAccount` may look back beyond the last
---successful refresh. If `since` is older than `lastRefresh - LAST_REFRESH_MAX_AGE_DAYS`,
---it is clamped to `today - LAST_REFRESH_MAX_AGE_DAYS`.
local LAST_REFRESH_MAX_AGE_DAYS = 89

---Warning shown before submitting a transfer to a bank without native Verification of Payee support.
local VOP_WARNING = "This bank does not support Verification of Payee (VoP). "
  .. "Please verify the recipient's name and IBAN yourself before authorizing the transfer.\n\n"
  .. "This warning can be disabled via the suppressVopWarning configuration option."
local demoConnection = require("yaxi.connections.demo")
local errors = require("yaxi.errors")
local interrupt = require("yaxi.interrupt")
local result = require("yaxi.result")
local service = require("yaxi.service")
local ticketMod = require("yaxi.ticket")

--region State

---@class YAXI.MoneyMoney.Extension : MM.WebBankingExtension
local YAXI = {}

---@type string
local YAXI_API_KEY_ID
---@type string
local YAXI_API_KEY_SECRET

---@type boolean
local YAXI_SUPPRESS_VOP_WARNING = false

---@type YAXI.MoneyMoney.Session?
local session = nil

--endregion State

--region Setup

---Check whether the YAXI API key is configured.
---@return boolean
local function hasApiKey()
  return YAXI_API_KEY_ID ~= nil and YAXI_API_KEY_ID ~= "" and YAXI_API_KEY_SECRET ~= nil and YAXI_API_KEY_SECRET ~= ""
end

---Check whether the configured API key is an integration/test key.
---@return boolean
local function isIntegrationKey()
  if not YAXI_API_KEY_ID then
    return false
  end
  return YAXI_API_KEY_ID:match("^api%-key%-integration") ~= nil or YAXI_API_KEY_ID:match("^test") ~= nil
end

---Register the extension with MoneyMoney.
---Services are filtered based on the configured API key:
---no key → no services; integration/test key → includes demo; production key → excludes demo.
local function register()
  local serviceNames = {}
  ---@type table<MM.PaymentTypeConst, true>
  local paymentTypeSet = {}
  if not hasApiKey() then
    error("No YAXI API key configured. No bank services will be available.")
  else
    local isDemoKey = isIntegrationKey()
    for name, conn in pairs(Connection.registry) do
      if name ~= demoConnection.service or isDemoKey then
        serviceNames[#serviceNames + 1] = name
        for _, pt in ipairs(conn.paymentTypes) do
          paymentTypeSet[pt] = true
        end
      end
    end
  end

  local paymentTypes = {}
  for pt in pairs(paymentTypeSet) do
    paymentTypes[#paymentTypes + 1] = pt
  end

  WebBanking({
    version = manifest.version,
    description = manifest.description,
    services = serviceNames,
    url = manifest.url,
    paymentTypes = paymentTypes,
  })
end

---Initialize the extension with API key credentials and register with MoneyMoney.
---@param config { apiKeyId: string, apiKeySecret: string, suppressVopWarning: boolean? }
function YAXI.setup(config)
  local id = config.apiKeyId
  local secret = config.apiKeySecret
  if id and id ~= "" and not id:match("^api%-key%-") then
    log:warn("API key ID has unexpected format: %s", id)
  end
  if secret and secret ~= "" then
    local decoded = base64.decode(secret)
    if not decoded or #decoded == 0 then
      log:warn("API key secret does not appear to be valid Base64")
    end
  end
  YAXI_API_KEY_ID = id
  YAXI_API_KEY_SECRET = secret
  YAXI_SUPPRESS_VOP_WARNING = config.suppressVopWarning or false

  register()
end

--endregion Setup

--region Helpers

local REDACTED_KEYS = {
  credentials = true,
  tan = true,
}

---Build a debug log line like `"FnName(a=1, b={...})"` from named arguments.
---@param name string
---@param ... any Alternating key, value pairs
local function logCall(name, ...)
  if log.level ~= "DEBUG" then
    return
  end
  local args = { ... }
  local parts = {}
  for i = 1, #args, 2 do
    local key = args[i]
    local value = REDACTED_KEYS[key] and "***" or util.fmt(args[i + 1])
    parts[#parts + 1] = string.format("%s=%s", key, value)
  end
  log:debug("%s(%s)", name, table.concat(parts, ", "))
end

---Shorthand for `errors.protected` bound to the module-level `session`.
---@param fn function
---@param ... any
---@return any
local function protected(fn, ...)
  return errors.protected(session, fn, ...)
end

---Persist the current time as last-refresh timestamp for the given IBAN.
---@param iban string
local function recordLastRefresh(iban)
  ---@type table<string, integer>
  local byIban = LocalStorage[StorageKey.LastRefresh] --[[@as table<string, integer>?]] or {}
  byIban[iban] = os.time()
  LocalStorage[StorageKey.LastRefresh] = byIban --[[@as any]]
end

---Clamp `since` to prevent overly broad date ranges on recurring refreshes.
---@param sess YAXI.MoneyMoney.Session
---@param iban string
---@param since MM.Timestamp?
---@return MM.Timestamp?
local function clampSince(sess, iban, since)
  if sess.sessionType ~= "refresh" or not since then
    return since
  end
  local lastRefreshByIban = LocalStorage[StorageKey.LastRefresh] --[[@as table<string, integer>?]] or {}
  local lastRefresh = lastRefreshByIban[iban] ---@type integer?
  if not lastRefresh then
    return since
  end
  local maxAgeSince = lastRefresh - LAST_REFRESH_MAX_AGE_DAYS * 86400
  if since >= maxAgeSince then
    return since
  end
  local clamped = os.time() - LAST_REFRESH_MAX_AGE_DAYS * 86400
  log:info(
    "Account %s: clamping since from %s to %s (last refresh %s, max age %d days)",
    iban,
    os.date("%Y-%m-%d", since),
    os.date("%Y-%m-%d", clamped),
    os.date("%Y-%m-%d", lastRefresh),
    LAST_REFRESH_MAX_AGE_DAYS
  )
  MM.printStatus(string.format("Limiting transaction history to %d days.", LAST_REFRESH_MAX_AGE_DAYS))
  return clamped --[[@as MM.Timestamp]]
end

---Fetch balances for all accounts if not already cached. Returns a challenge on interrupt.
---@param sess YAXI.MoneyMoney.Session
---@param iban string
---@param currency string?
---@param accountName string?
---@return MM.SessionChallenge?
local function fetchBalances(sess, iban, currency, accountName)
  if sess.balancesCache and sess.balancesCache[iban] then
    return nil
  end
  MM.printStatus(string.format("Fetching balances for %s…", accountName or iban))
  local accountRefs = LocalStorage[StorageKey.Accounts]
    or {
      {
        iban = iban,
        currency = currency,
      },
    }
  local obResponse = service.callBalances(sess, accountRefs)
  local challenge = interrupt.mapToChallenge(sess, obResponse)
  if challenge then
    sess.phase = Phase.Balances
    return challenge
  end
  sess.balancesResult = sess.result
  result.cacheBalancesResult(sess)
  return nil
end

---Fetch transactions for a single account if not already cached. Returns a challenge on interrupt.
---@param sess YAXI.MoneyMoney.Session
---@param iban string
---@param currency string?
---@param since integer
---@param accountName string?
---@return MM.SessionChallenge?
local function fetchTransactions(sess, iban, currency, since, accountName)
  if sess.transactionsCache and sess.transactionsCache[iban] then
    return nil
  end
  MM.printStatus(string.format("Fetching transactions for %s…", accountName or iban))
  local obResponse = service.callTransactions(sess, iban, currency, since)
  local challenge = interrupt.mapToChallenge(sess, obResponse)
  if challenge then
    sess.phase = Phase.Transactions
    return challenge
  end
  result.cacheTransactionsResult(sess, iban)
  return nil
end

---Build the final refresh response and record the last-refresh timestamp.
---@param sess YAXI.MoneyMoney.Session
---@param iban string
---@param paymentTypes MM.PaymentTypeConst[]? Per-account payment types reported in the response
---@return MM.RefreshAccountResponse
local function finishRefresh(sess, iban, paymentTypes)
  local response = result.buildRefreshResponse(sess, iban, paymentTypes)
  recordLastRefresh(iban)
  return response
end

--endregion Helpers

--region Callbacks

function YAXI.SupportsBank(protocol, bankCode, _fetchStatements, _fetchScheduledPayments, isPaymentSession)
  logCall("SupportsBank", "protocol", protocol, "bankCode", bankCode, "isPaymentSession", isPaymentSession)

  if protocol ~= ProtocolWebBanking then
    return false
  end
  local conn = Connection.registry[bankCode]
  if not conn then
    return false
  end
  ---@type MM.SupportsBankResponse
  return {
    url = conn.url,
    since = conn.since,
  }
end

function YAXI.InitializeSession2(protocol, bankCode, step, credentials, interactive, tanMethods, sessionType)
  logCall(
    "InitializeSession2",
    "protocol",
    protocol,
    "bankCode",
    bankCode,
    "step",
    step,
    "credentials",
    credentials,
    "interactive",
    interactive,
    "tanMethods",
    tanMethods,
    "sessionType",
    sessionType
  )
  if step == 1 and not hasApiKey() then
    return "YAXI API key not configured. Get your free key at https://hub.yaxi.tech"
  end

  return protected(function()
    if sessionType == "new account" and step == 1 then
      local conn = Connection.registry[bankCode] or error("Unsupported bank: " .. bankCode)
      local sess = Session:new(conn, YAXI_API_KEY_ID, YAXI_API_KEY_SECRET, manifest.version)
      session = sess
      sess.sessionType = sessionType
      sess:setCredentials(credentials --[[@as string[] ]])
      MM.printStatus("Fetching accounts…")
      local obResponse = service.callAccounts(sess)
      return interrupt.mapToChallenge(sess, obResponse)
    elseif sessionType == "new account" then
      assert(session, "No active session")
      local obResponse = service.respondToInterrupt(session, credentials --[[@as string[]|MM.TanMethod[] ]])
      return interrupt.mapToChallenge(session, obResponse)
    elseif step == 1 then
      -- `"refresh"` or `"payment"`: create session, defer service calls
      local conn = Connection.registry[bankCode] or error("Unsupported bank: " .. bankCode)
      local sess = Session:new(conn, YAXI_API_KEY_ID, YAXI_API_KEY_SECRET, manifest.version)
      session = sess
      sess.sessionType = sessionType
      sess:setCredentials(credentials --[[@as string[] ]])
      return nil
    end
    -- step 2+ shouldn't happen for refresh/payment init
    return nil
  end)
end

function YAXI.ListAccounts(knownAccounts)
  logCall("ListAccounts", "knownAccounts", knownAccounts)
  return protected(function()
    if not session or not session.result then
      return "The session initialization did not produce a valid list of accounts"
    end

    local yaxiAccounts = result.decodeResultData(session.result.jwt, session.apiKeySecret)
    ---@type MM.Account[]
    local accounts = {}
    ---@type YAXI.RoutexClient.AccountReference[]
    local accountRefs = {}
    ---@type table<string, any>
    local yaxiAccountsByIban = {}

    for _, yaxiAccount in ipairs(yaxiAccounts or {}) do
      local ok, mapped = pcall(session.connection.mapAccount, session.connection, yaxiAccount)
      if ok and mapped then
        ---@cast mapped MM.Account
        table.insert(accounts, mapped)
        if mapped.iban then
          table.insert(accountRefs, {
            iban = mapped.iban,
            currency = mapped.currency,
          })
          yaxiAccountsByIban[mapped.iban] = yaxiAccount
        end
      else
        log:warn("Failed to map account: %s", tostring(mapped))
      end
    end
    log:debug("Mapped %d accounts", #accounts)

    -- Persist YAXI account data for MapAccount and bulk balance fetching
    LocalStorage[StorageKey.Accounts] = accountRefs --[[@as any]]
    LocalStorage[StorageKey.AccountsData] = yaxiAccountsByIban --[[@as any]]

    return accounts
  end)
end

---@return MM.RefreshAccountResponse|MM.SessionChallenge|MM.ErrorMessage
function YAXI.RefreshAccount(account, since, isKnownTransactionId, step, credentials)
  logCall(
    "RefreshAccount",
    "account",
    account,
    "since",
    since,
    "isKnownTransactionId",
    isKnownTransactionId,
    "step",
    step,
    "credentials",
    credentials
  )
  return protected(function()
    assert(session, "No active session")
    local iban = assert(account.iban, "Account has no IBAN")
    since = clampSince(session, iban, since)

    local yaxiAccountsByIban = LocalStorage[StorageKey.AccountsData] --[[@as table<string, YAXI.RoutexClient.Result.Account>?]]
      or {}
    local paymentTypes = accountMapping.derivePaymentTypes(yaxiAccountsByIban[iban], session.connection)

    if step == 1 or not step then
      local challenge = fetchBalances(session, iban, account.currency, account.name)
        or fetchTransactions(session, iban, account.currency, since or 0, account.name)
      return challenge or finishRefresh(session, iban, paymentTypes)
    end

    -- step > 1: respond to interrupt
    local obResponse = service.respondToInterrupt(session, credentials --[[@as string[]|MM.TanMethod[] ]])
    local challenge = interrupt.mapToChallenge(session, obResponse)
    if challenge then
      return challenge
    end

    -- Cache the completed phase's result
    if session.phase == Phase.Balances then
      session.balancesResult = session.result
      result.cacheBalancesResult(session)
    elseif session.phase == Phase.Transactions then
      result.cacheTransactionsResult(session, iban)
    end

    -- Continue with remaining phases
    challenge = fetchBalances(session, iban, account.currency, account.name)
      or fetchTransactions(session, iban, account.currency, since or 0, account.name)
    return challenge or finishRefresh(session, iban, paymentTypes)
  end)
end

function YAXI.GetTanMethods(account)
  logCall("GetTanMethods", "account", account)
  return protected(function()
    for _, conn in pairs(Connection.registry) do
      local bankInfo = BankInfo(account.bankCode or "")
      if bankInfo and bankInfo.bic == conn.bic or conn.bic == account.bic then
        return conn:getEffectiveTanMethods()
      end
    end

    error(string.format("No connection found for BIC %s", account.bic))
  end)
end

function YAXI.SubmitPayment(step, account, payment, tanMethod, credentials)
  logCall(
    "SubmitPayment",
    "step",
    step,
    "account",
    account,
    "payment",
    payment,
    "tanMethod",
    tanMethod,
    "credentials",
    credentials
  )
  return protected(function()
    assert(session, "No active session")

    if step == 1 then
      session:resetInterruptState()

      -- Banks without native VoP get a synthetic confirmation BEFORE `callTransfer`,
      -- so the user can still verify (and abort) while no transfer is in flight.
      if session.connection.vop == VopMode.None and not YAXI_SUPPRESS_VOP_WARNING then
        session.pendingVopWarning = true
        return {
          status = "pending",
          challenge = VOP_WARNING,
          poll = true,
          vop = VOP_WARNING,
        }
      end
    end

    if session.pendingVopWarning then
      session.pendingVopWarning = nil
      MM.printStatus("Submitting transfer…")
      local obResponse = service.callTransfer(session, account, payment, payment.type or PaymentTypeTransfer)
      return interrupt.mapToPaymentResponse(session, obResponse, tanMethod)
    end

    if step == 1 then
      MM.printStatus("Submitting transfer…")
      local obResponse = service.callTransfer(session, account, payment, payment.type or PaymentTypeTransfer)
      return interrupt.mapToPaymentResponse(session, obResponse, tanMethod)
    end

    if session.result then
      local ticketId = session.activeTicket and ticketMod.getId(session.activeTicket) or nil
      return { status = "accepted", orderId = ticketId }
    end
    local obResponse = service.respondToInterrupt(session, credentials --[[@as string[]|MM.TanMethod[] ]])
    return interrupt.mapToPaymentResponse(session, obResponse, tanMethod)
  end)
end

function YAXI.MapAccount(account)
  logCall("MapAccount", "account", account)
  return protected(function()
    if not session then
      return nil
    end

    -- Re-map from stored YAXI account data if available
    local yaxiAccountsByIban = LocalStorage[StorageKey.AccountsData] --[[@as table<string, any>?]]
    local iban = account.iban
    local yaxiAccount = iban and yaxiAccountsByIban and yaxiAccountsByIban[iban]
    if yaxiAccount then
      return session.connection:mapAccount(yaxiAccount)
    end

    return nil
  end)
end

function YAXI.EndSession()
  logCall("EndSession")
  if session then
    session:persist()
  end

  local name = session and session.connection.service or "unknown"
  local stats = service.getUsageStats()
  log:info(
    "%s usage this month so far: %d total (accounts=%d, balances=%d, transactions=%d, transfer=%d)",
    name,
    stats.total,
    stats.accounts,
    stats.balances,
    stats.transactions,
    stats.transfer
  )
end

--endregion Callbacks

--region Exports

SupportsBank = YAXI.SupportsBank
InitializeSession2 = YAXI.InitializeSession2
ListAccounts = YAXI.ListAccounts
RefreshAccount = YAXI.RefreshAccount
GetTanMethods = YAXI.GetTanMethods
MapAccount = YAXI.MapAccount
SubmitPayment = YAXI.SubmitPayment
EndSession = YAXI.EndSession

return YAXI

--endregion Exports
