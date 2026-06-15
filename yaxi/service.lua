-- SPDX-License-Identifier: MIT
-- Author: Vincent Haupert <vincent.haupert@yaxi.tech>

-- YAXI Service Orchestrator — Issues tickets and calls `RoutexClient`

local log = (require("routex-client.logging") --[[@as lualogging]]).defaultLogger()

local rc = require("routex-client")
local AccountField = rc.AccountField
local Confirmation = rc.Confirmation
local Selection = rc.Selection
local Field = rc.Field

local enum = require("yaxi.enum")
local http = require("routex-client.http")
local ticketMod = require("yaxi.ticket")
local transactionMapping = require("yaxi.mapping.transaction")
local util = require("yaxi.util")

local Service = enum.Service
local StorageKey = enum.StorageKey

local M = {}

---Get the current month key (e.g. `"2026-03"`).
---@return string
local function monthKey()
  return os.date("!%Y-%m") --[[@as string]]
end

---Record a service call in `LocalStorage`.
---@param serviceName YAXI.RoutexClient.Service
local function recordCall(serviceName)
  ---@type table<string, table<string, integer>>
  local usage = LocalStorage[StorageKey.Usage] --[[@as table?]] or {}
  local month = monthKey()
  if not usage[month] then
    usage[month] = {}
  end
  usage[month][serviceName] = (usage[month][serviceName] or 0) + 1
  LocalStorage[StorageKey.Usage] = usage --[[@as any]]
end

---Get usage stats for the current month from `LocalStorage`.
---@return { accounts: integer, balances: integer, transactions: integer, transfer: integer, total: integer }
function M.getUsageStats()
  ---@type table<string, table<string, integer>>
  local usage = LocalStorage[StorageKey.Usage] --[[@as table?]] or {}
  local counts = usage[monthKey()] or {}
  local services = {
    Service.Accounts,
    Service.Balances,
    Service.Transactions,
    Service.Transfer,
  }

  local stats = {
    accounts = 0,
    balances = 0,
    transactions = 0,
    transfer = 0,
    total = 0,
  }
  for _, svc in ipairs(services) do
    local n = counts[svc] or 0
    stats[svc] = n
    stats.total = stats.total + n
  end

  return stats
end

---@class YAXI.MoneyMoney.ServiceMethods
---@field respond function
---@field confirm function

---`RoutexClient` service method lookup table for `respond`/`confirm` dispatch.
---@param client YAXI.RoutexClient.RoutexClient
---@return table<YAXI.RoutexClient.Service, YAXI.MoneyMoney.ServiceMethods>
local function getMethods(client)
  return {
    [Service.Accounts] = {
      respond = client.respondAccounts,
      confirm = client.confirmAccounts,
    },
    [Service.Balances] = {
      respond = client.respondBalances,
      confirm = client.confirmBalances,
    },
    [Service.Transactions] = {
      respond = client.respondTransactions,
      confirm = client.confirmTransactions,
    },
    [Service.Transfer] = {
      respond = client.respondTransfer,
      confirm = client.confirmTransfer,
    },
  }
end

---Set up session state for a new service call: generate ticket, update active fields, record usage.
---@param session YAXI.MoneyMoney.Session
---@param serviceName YAXI.RoutexClient.Service
---@param ticket string Signed YAXI ticket JWT
---@param client YAXI.RoutexClient.Core Client issuing the call (so its trace is fetched on error)
local function prepareCall(session, serviceName, ticket, client)
  session.activeTicket = ticket
  session.activeService = serviceName
  session.activeClient = client
  recordCall(serviceName)
end

---Resolve the `respond`/`confirm` method pair for the current active service.
---@param session YAXI.MoneyMoney.Session
---@return YAXI.MoneyMoney.ServiceMethods
---@return YAXI.RoutexClient.RoutexClient
local function resolveService(session)
  local client = session.client
  local activeSvc = assert(session.activeService, "No active service")
  local methods = getMethods(client)
  local svc = methods[activeSvc]
  if not svc then
    error(string.format("No service methods for: %s", activeSvc))
  end
  return svc, client
end

---Handle an OAuth redirect completion: POST code+state to YAXI, then confirm.
---@param session YAXI.MoneyMoney.Session
---@param svc YAXI.MoneyMoney.ServiceMethods
---@param client YAXI.RoutexClient.RoutexClient
---@param oauthCode string
---@return YAXI.RoutexClient.OBResponse
local function handleRedirect(session, svc, client, oauthCode)
  local redirect = assert(session.redirect, "No redirect to handle")
  log:debug("Responding to redirect for %s", session.activeService)

  local oauthState = util.extractOAuthState(redirect.url)
  if not oauthState then
    error("Failed to find state parameter in redirect URL")
  end

  -- POST redirect `code` + `state` to YAXI (form-urlencoded per server expectation).
  -- `oauthState` is already URL-encoded (extracted from the redirect URL); don't re-encode.
  local ticketId = ticketMod.getId(assert(session.activeTicket, "No active ticket"))
  local encodedCode = MM.urlencode(oauthCode, "UTF-8")
  local request = http.Request
    :builder((client --[[@as table]])._url .. "/redirect")
    :method("POST")
    :header("accept", client.MEDIA_TYPE)
    :header("content-type", "application/x-www-form-urlencoded")
    :header("yaxi-ticket-id", ticketId)
    :data(("code=%s&state=%s"):format(encodedCode, oauthState))
    :build()
  local response = client:sealedRequest(request)
  if response.body ~= nil and #response.body ~= 0 then
    log:debug("Redirect endpoint returned body: %s", response.body)
  end

  return svc.confirm(client, {
    ticket = session.activeTicket,
    context = redirect.context,
  })
end

---Run a read service call through the non-interactive `RoutexRefreshClient` when
---possible (see `Session:canRefresh`), otherwise through the interactive
---`RoutexClient`. Refresh-client errors propagate: a background refresh that needs an
---interactive step (SCA) or hits the refresh limit surfaces as a manual-refresh
---message rather than an automatic interactive call, which in a background session
---would trigger a surprise SCA (e.g., a push notification from the banking app).
---@param session YAXI.MoneyMoney.Session
---@param refreshFn fun(): YAXI.RoutexRefreshClient.Response
---@param interactiveFn fun(): YAXI.RoutexClient.OBResponse
---@return YAXI.RoutexClient.OBResponse? obResponse `nil` if the refresh client completed the call (see `Session:resultData`)
local function tryRefresh(session, refreshFn, interactiveFn)
  if not session:canRefresh() then
    return interactiveFn()
  end
  session:storeRefreshResponse(refreshFn())
  return nil
end

---Call the `Accounts` service.
---@param session YAXI.MoneyMoney.Session
---@return YAXI.RoutexClient.OBResponse
function M.callAccounts(session)
  local ticket = session.ticketGenerator:accounts(MM.uuid())
  prepareCall(session, Service.Accounts, ticket, session.client)
  log:debug("Calling accounts service")

  return session.client:accounts({
    credentials = session.credentials,
    ticket = ticket,
    fields = util.values(AccountField),
    filter = {
      notEq = {
        AccountField.Iban,
        nil,
      },
    },
    recurringConsents = true,
    session = session:routexSession(),
  })
end

---Call the `Balances` service for one or more accounts.
---@param session YAXI.MoneyMoney.Session
---@param accounts YAXI.RoutexClient.AccountReference[]
---@return YAXI.RoutexClient.OBResponse? obResponse `nil` if the refresh client completed the call (see `Session:resultData`)
function M.callBalances(session, accounts)
  return tryRefresh(session, function()
    local ticket = session.ticketGenerator:balances(MM.uuid())
    prepareCall(session, Service.Balances, ticket, session.refreshClient)
    log:debug("Refreshing balances for %d account(s)", #accounts)

    return session.refreshClient:balances({
      accounts = accounts,
      connectionData = assert(session.credentials.connectionData),
      ticket = ticket,
      session = session:routexSession(),
    })
  end, function()
    local ticket = session.ticketGenerator:balances(MM.uuid())
    prepareCall(session, Service.Balances, ticket, session.client)
    log:debug("Calling balances service for %d account(s)", #accounts)

    return session.client:balances({
      accounts = accounts,
      credentials = session.credentials,
      ticket = ticket,
      recurringConsents = true,
      session = session:routexSession(),
    })
  end)
end

---Call the `Transactions` service.
---@param session YAXI.MoneyMoney.Session
---@param iban string
---@param currency string?
---@param since integer POSIX timestamp
---@return YAXI.RoutexClient.OBResponse? obResponse `nil` if the refresh client completed the call (see `Session:resultData`)
function M.callTransactions(session, iban, currency, since)
  ---Account and date range live in the ticket.
  ---@return string ticket
  local function transactionsTicket()
    return session.ticketGenerator:transactions(MM.uuid(), {
      account = {
        iban = iban,
        currency = currency,
      },
      range = {
        from = transactionMapping.timestampToDate(since),
      },
    })
  end

  return tryRefresh(session, function()
    log:debug("Refreshing transactions for %s (since=%s)", iban, transactionMapping.timestampToDate(since))
    local ticket = transactionsTicket()
    prepareCall(session, Service.Transactions, ticket, session.refreshClient)

    return session.refreshClient:transactions({
      connectionData = assert(session.credentials.connectionData),
      ticket = ticket,
      session = session:routexSession(),
    })
  end, function()
    log:debug("Calling transactions service for %s (since=%s)", iban, transactionMapping.timestampToDate(since))
    local ticket = transactionsTicket()
    prepareCall(session, Service.Transactions, ticket, session.client)

    return session.client:transactions({
      credentials = session.credentials,
      ticket = ticket,
      recurringConsents = true,
      session = session:routexSession(),
    })
  end)
end

---Call the `Transfer` service.
---@param session YAXI.MoneyMoney.Session
---@param account MM.Account Debtor account
---@param payment MM.Payment
---@param mmPaymentType MM.PaymentTypeConst
---@return YAXI.RoutexClient.OBResponse
function M.callTransfer(session, account, payment, mmPaymentType)
  local ticket = session.ticketGenerator:transfer(MM.uuid())
  prepareCall(session, Service.Transfer, ticket, session.client)

  local product = session.connection:paymentProduct(mmPaymentType)
  log:debug("Calling transfer service (product=%s, amount=%s %s)", product, payment.amount, payment.currency or "EUR")

  ---@type YAXI.RoutexClient.TransferOptions.Details
  local details = {
    amount = {
      amount = payment.amount or error("Payment missing amount"),
      currency = payment.currency or "EUR",
    },
    creditorAccount = {
      iban = payment.accountNumber or error("Payment missing creditor IBAN"),
    },
    creditorName = payment.name or error("Payment missing creditor name"),
    remittance = payment.purpose,
    endToEndIdentification = payment.endToEndReference,
  }

  ---@type osdate?
  local requestedExecutionDate = nil
  if mmPaymentType == PaymentTypeScheduledTransfer and payment.scheduledDate then
    local d = os.date("!*t", payment.scheduledDate) --[[@as osdate]]
    -- Strip time fields so `formatDate` produces `YYYY-MM-DD` (not RFC3339)
    d.hour = nil
    d.min = nil
    d.sec = nil
    requestedExecutionDate = d
  end

  return session.client:transfer({
    credentials = session.credentials,
    ticket = ticket,
    product = product,
    debtorAccount = {
      iban = account.iban or account.accountNumber or error("Debtor account missing IBAN"),
      currency = account.currency,
    },
    details = { details },
    requestedExecutionDate = requestedExecutionDate,
    recurringConsents = true,
    session = session:routexSession(),
  })
end

---Respond to an interrupt based on session state (`dialog` or `redirect`).
---Dispatches to the correct `RoutexClient` `respond` or `confirm` method.
---@param session YAXI.MoneyMoney.Session
---@param userInput string[]|MM.TanMethod[] Credentials/TAN from MoneyMoney
---@return YAXI.RoutexClient.OBResponse
function M.respondToInterrupt(session, userInput)
  local svc, client = resolveService(session)

  if session.redirect then
    return handleRedirect(session, svc, client, userInput[1] --[[@as string]])
  elseif session.dialog then
    local dialog = session.dialog
    local input = dialog.input
    if not input then
      error("Dialog has no input")
    end

    if input:isInstanceOf(Confirmation) then
      log:debug("Confirming dialog for %s", session.activeService)
      return svc.confirm(client, {
        ticket = session.activeTicket,
        context = input.context,
      })
    elseif input:isInstanceOf(Selection) then
      local tanMethod = userInput[1] --[[@as MM.TanMethod]]
      log:debug("Responding to selection for %s (webMethod=%s)", session.activeService, tanMethod.webMethod)
      return svc.respond(client, {
        ticket = session.activeTicket,
        context = input.context,
        response = tanMethod.webMethod,
      })
    elseif input:isInstanceOf(Field) then
      log:debug("Responding to field input for %s", session.activeService)
      return svc.respond(client, {
        ticket = session.activeTicket,
        context = input.context,
        response = userInput[1] --[[@as string]],
      })
    else
      error("Unhandled dialog type in respondToInterrupt")
    end
  else
    error("No interrupt to respond to (no dialog or redirect)")
  end
end

---Confirm a `Confirmation` dialog without user input.
---Used internally for auto-confirming VopCheck dialogs.
---@param session YAXI.MoneyMoney.Session
---@return YAXI.RoutexClient.OBResponse
function M.confirmDialog(session)
  local svc, client = resolveService(session)

  local dialog = session.dialog
  if not dialog or not dialog.input then
    error("No dialog to confirm")
  end

  return svc.confirm(client, {
    ticket = session.activeTicket,
    context = dialog.input.context,
  })
end

---Respond to a `Selection` dialog with a specific key.
---Used internally by `interrupt.mapToPaymentResponse` for TAN method auto-selection.
---@param session YAXI.MoneyMoney.Session
---@param selectionKey string
---@return YAXI.RoutexClient.OBResponse
function M.respondToSelection(session, selectionKey)
  local svc, client = resolveService(session)

  local dialog = session.dialog
  if not dialog or not dialog.input then
    error("No dialog to respond to")
  end

  return svc.respond(client, {
    ticket = session.activeTicket,
    context = dialog.input.context,
    response = selectionKey,
  })
end

return M
