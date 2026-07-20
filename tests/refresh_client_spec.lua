-- SPDX-License-Identifier: MIT
-- Author: Vincent Haupert <vincent.haupert@yaxi.tech>

-- Tests for the non-interactive `RoutexRefreshClient` integration:
-- client selection (interactive vs refresh) and error propagation.

dofile("tests/mm_env.lua")

local assert = require("luassert")

local Session = require("yaxi.session")
local enum = require("yaxi.enum")
local errors = require("yaxi.errors")
local interrupt = require("yaxi.interrupt")
local service = require("yaxi.service")

local rcErrors = require("routex-client.errors")
local InterruptError = rcErrors.InterruptError
local UnauthorizedError = rcErrors.UnauthorizedError
local AccessExceededError = rcErrors.AccessExceededError

local TEST_IBAN = "DE02120300000000202051"
local ACCOUNT_REFS = { { iban = TEST_IBAN, currency = "EUR" } }

local extension = require("yaxi.extension")
extension.setup({ apiKeyId = "test", apiKeySecret = "dGVzdA==" })

---Create a mock session with stubbed clients and ticket generator.
---@param opts { interactive: boolean?, connectionData: string?, client: table?, refreshClient: table? }
---@return any session, fun(): integer ticketCount
local function mockSession(opts)
  local tickets = 0
  local sess = setmetatable({}, Session)
  sess.sessionType = "refresh"
  sess.interactive = opts.interactive
  ---@diagnostic disable-next-line: missing-fields
  sess.connection = { id = "mock-conn", service = "MockBank", paymentTypes = {} } --[[@as YAXI.MoneyMoney.Connection]]
  sess.credentials = {
    connectionId = "mock-conn",
    connectionData = opts.connectionData --[[@as binary]],
  }
  ---@diagnostic disable-next-line: missing-fields
  sess.ticketGenerator = {
    balances = function()
      tickets = tickets + 1
      return "ticket-balances-" .. tickets
    end,
    transactions = function()
      tickets = tickets + 1
      return "ticket-transactions-" .. tickets
    end,
  } --[[@as YAXI.MoneyMoney.Ticket.Generator]]
  sess.client = (opts.client or {}) --[[@as YAXI.RoutexClient.RoutexClient]]
  sess.refreshClient = (opts.refreshClient or {}) --[[@as YAXI.RoutexRefreshClient]]
  return sess, function()
    return tickets
  end
end

local function resetState()
  EndSession()
  for k in pairs(LocalStorage) do
    LocalStorage[k] = nil
  end
end

---Name of a typed error value raised via `error()`.
---@param err any
---@return string?
local function errName(err)
  return type(err) == "table" and err.name or nil
end

context("RoutexRefreshClient integration", function()
  teardown(resetState)

  context("service calls", function()
    test("uses the interactive client when connectionData is absent", function()
      local refreshCalls = 0
      local sentinel = { kind = "obResponse" }
      local sess = mockSession({
        interactive = true,
        connectionData = nil,
        refreshClient = {
          balances = function()
            refreshCalls = refreshCalls + 1
          end,
        },
        client = {
          balances = function()
            return sentinel
          end,
        },
      })

      local obResponse = service.callBalances(sess, ACCOUNT_REFS)

      assert.are_equal(sentinel, obResponse)
      assert.are_equal(0, refreshCalls)
    end)

    test("uses the interactive client for an interactive session even with connectionData", function()
      local refreshCalls = 0
      local sentinel = { kind = "obResponse" }
      local sess = mockSession({
        interactive = true,
        connectionData = "blob",
        refreshClient = {
          balances = function()
            refreshCalls = refreshCalls + 1
          end,
        },
        client = {
          balances = function()
            return sentinel
          end,
        },
      })

      local obResponse = service.callBalances(sess, ACCOUNT_REFS)

      assert.are_equal(sentinel, obResponse)
      assert.are_equal(0, refreshCalls)
    end)

    test("uses the refresh client for a non-interactive session", function()
      local interactiveCalls = 0
      local sess = mockSession({
        interactive = false,
        connectionData = "blob",
        refreshClient = {
          balances = function()
            return { result = { balances = {} } }
          end,
        },
        client = {
          balances = function()
            interactiveCalls = interactiveCalls + 1
          end,
        },
      })

      local obResponse = service.callBalances(sess, ACCOUNT_REFS)

      assert.is_nil(obResponse)
      assert.are_equal(0, interactiveCalls)
    end)

    test("propagates InterruptError from the refresh client", function()
      local interactiveCalls = 0
      local sess = mockSession({
        interactive = false,
        connectionData = "blob",
        refreshClient = {
          balances = function()
            error(InterruptError:new())
          end,
        },
        client = {
          balances = function()
            interactiveCalls = interactiveCalls + 1
          end,
        },
      })

      local ok, err = pcall(service.callBalances, sess, ACCOUNT_REFS)

      assert.is_false(ok)
      assert.are_equal("InterruptError", errName(err))
      assert.are_equal(0, interactiveCalls)
    end)

    test("propagates AccessExceededError from the refresh client", function()
      local interactiveCalls = 0
      local sess = mockSession({
        interactive = false,
        connectionData = "blob",
        refreshClient = {
          balances = function()
            error(AccessExceededError:new())
          end,
        },
        client = {
          balances = function()
            interactiveCalls = interactiveCalls + 1
          end,
        },
      })

      local ok, err = pcall(service.callBalances, sess, ACCOUNT_REFS)

      assert.is_false(ok)
      assert.are_equal("AccessExceededError", errName(err))
      assert.are_equal(0, interactiveCalls)
    end)

    test("propagates other refresh client errors unchanged", function()
      local interactiveCalls = 0
      local sess = mockSession({
        interactive = false,
        connectionData = "blob",
        refreshClient = {
          balances = function()
            error(UnauthorizedError:new("Consent expired"))
          end,
        },
        client = {
          balances = function()
            interactiveCalls = interactiveCalls + 1
          end,
        },
      })

      local ok, err = pcall(service.callBalances, sess, ACCOUNT_REFS)

      assert.is_false(ok)
      assert.are_equal("UnauthorizedError", errName(err))
      assert.are_equal(0, interactiveCalls)
    end)
  end)

  context("_readResponse status-code compat", function()
    -- MoneyMoney cannot surface HTTP status codes; `yaxi.mm.http` patches
    -- `RoutexRefreshClient._readResponse` to map error bodies despite status 200.
    local RoutexRefreshClient = require("routex-client.refresh").RoutexRefreshClient --[[@as table]]

    local function readResponse(body)
      return RoutexRefreshClient._readResponse({ status = 200, headers = {}, body = body })
    end

    test("raises InterruptError for an error body with status 200", function()
      local ok, err = pcall(readResponse, '{"InterruptError":{}}')
      assert.is_false(ok)
      assert.are_equal("InterruptError", errName(err))
    end)

    test("raises a typed error for other error bodies", function()
      local ok, err = pcall(readResponse, '{"Unauthorized":{"userMessage":"Consent expired"}}')
      assert.is_false(ok)
      assert.are_equal("UnauthorizedError", errName(err))
    end)

    test("returns the decoded payload for success bodies", function()
      local response = readResponse('{"result":[{"iban":"' .. TEST_IBAN .. '"}]}')
      assert.are_equal(TEST_IBAN, response.result[1].iban)
    end)

    test("treats an empty body as an empty response", function()
      local response = readResponse("{}")
      assert.is_nil(response.result)
    end)
  end)

  context("errorHandler", function()
    test("maps InterruptError to a manual-refresh message without side effects", function()
      local traces = require("yaxi.traces")
      local origWrite = traces.write
      local traceWritten = false
      traces.write = function()
        traceWritten = true
        return "trace-path"
      end

      LocalStorage["mock-conn"] = "blob" --[[@as any]]
      local sess = mockSession({ interactive = false, connectionData = "blob" })
      sess.activeService = enum.Service.Balances
      sess.activeTicket = "ticket"

      local message = errors.errorHandler(sess, InterruptError:new())

      traces.write = origWrite
      assert.is_truthy(message:find("authorization %(SCA%)"))
      assert.are_equal("blob", LocalStorage["mock-conn"])
      assert.is_false(traceWritten)
    end)

    test("maps AccessExceededError to a manual-refresh message without side effects", function()
      local traces = require("yaxi.traces")
      local origWrite = traces.write
      local traceWritten = false
      traces.write = function()
        traceWritten = true
        return "trace-path"
      end

      LocalStorage["mock-conn"] = "blob" --[[@as any]]
      local sess = mockSession({ interactive = false, connectionData = "blob" })
      sess.activeService = enum.Service.Balances
      sess.activeTicket = "ticket"

      local message = errors.errorHandler(sess, AccessExceededError:new("server limit message"))

      traces.write = origWrite
      assert.is_truthy(message:find("automatic refresh limit"))
      assert.is_falsy(message:find("server limit message", 1, true))
      assert.are_equal("blob", LocalStorage["mock-conn"])
      assert.is_false(traceWritten)
    end)
  end)

  context("InitializeSession2", function()
    ---Patch `Session.new` to inject a mock session, run `InitializeSession2`
    ---with the given flag, then restore. Returns the injected session.
    ---@param sessionType MM.SessionType
    ---@param interactive boolean
    ---@return any session
    local function initWithMockSession(sessionType, interactive)
      local origNew = Session.new
      local injected
      ---@diagnostic disable-next-line: duplicate-set-field
      Session.new = function(_cls, conn)
        injected = mockSession({ interactive = nil, connectionData = nil })
        injected.sessionType = nil
        injected.connection = conn
        injected.connectionInfo = { id = "mock-conn", credentials = {} }
        return injected
      end
      local origCallAccounts = service.callAccounts
      local origMapToChallenge = interrupt.mapToChallenge
      service.callAccounts = function()
        return { kind = "obResponse" }
      end
      interrupt.mapToChallenge = function()
        return nil
      end

      InitializeSession2(
        ProtocolWebBanking,
        "YAXI Demo",
        1,
        { "", "" } --[[@as MM.Credentials]],
        interactive,
        {},
        sessionType
      )

      ---@diagnostic disable-next-line: duplicate-set-field
      Session.new = origNew
      service.callAccounts = origCallAccounts
      interrupt.mapToChallenge = origMapToChallenge
      return injected
    end

    test("stores the interactive flag for refresh sessions", function()
      resetState()
      local sess = initWithMockSession("refresh", false)
      assert.is_false(sess.interactive)
    end)

    test("stores the interactive flag for new-account sessions", function()
      resetState()
      local sess = initWithMockSession("new account", true)
      assert.is_true(sess.interactive)
    end)
  end)
end)
