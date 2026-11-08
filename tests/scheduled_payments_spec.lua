-- SPDX-License-Identifier: MIT
-- Author: Vincent Haupert <vincent.haupert@yaxi.tech>

-- Tests for `FetchScheduledPayments`: which connections fetch standing orders,
-- and that MoneyMoney keeps its known ones when the bank requires the user.

dofile("tests/mm_env.lua")

local assert = require("luassert")
local fixtures = require("tests.fixtures")

local Session = require("yaxi.session")
local base64 = require("routex-client.util.base64")
local jwt = require("routex-client.jwt")
local rc = require("routex-client")

local API_KEY_SECRET = "YAXI"
local ACCOUNT = { iban = fixtures.DEMO_IBAN, currency = "EUR" }

local extension = require("yaxi.extension")
extension.setup({ apiKeyId = "test", apiKeySecret = "dGVzdA==" })

local function resetState()
  EndSession()
  for k in pairs(LocalStorage) do
    LocalStorage[k] = nil
  end
end

---@param standingOrders table[]
---@return YAXI.RoutexClient.Result
local function standingOrdersResult(standingOrders)
  local token = jwt.encode({
    exp = os.time() + 600,
    data = { id = MM.uuid(), service = "StandingOrders", data = standingOrders },
  }, base64.decode(API_KEY_SECRET) --[[@as binary]], "HS256")
  return rc.Result:fromJSON({ Result = { token } })
end

---Inject a refresh session whose client answers standing orders requests with `respond`.
---@param standingOrders boolean Connection's standing orders flag
---@param respond fun(): YAXI.RoutexClient.OBResponse
---@return table[] requests Options of each standing orders request
local function initSession(standingOrders, respond)
  local requests = {}
  local origNew = Session.new
  ---@diagnostic disable-next-line: duplicate-set-field
  Session.new = function(_cls, conn)
    local sess = setmetatable({}, Session) --[[@as any]]
    sess.apiKeySecret = API_KEY_SECRET
    sess.connection = { id = conn.id, service = conn.service, standingOrders = standingOrders }
    sess.connectionInfo = { credentials = {} }
    sess.credentials = { connectionId = conn.id, connectionData = "blob" }
    sess.ticketGenerator = {
      standingOrders = function()
        return "ticket"
      end,
    }
    sess.client = {
      standingOrders = function(_client, options)
        table.insert(requests, options)
        return respond()
      end,
    }
    return sess
  end
  InitializeSession2(ProtocolWebBanking, "YAXI Demo", 1, { "", "" } --[[@as MM.Credentials]], false, {}, "refresh")
  ---@diagnostic disable-next-line: duplicate-set-field
  Session.new = origNew
  return requests
end

context("FetchScheduledPayments", function()
  before_each(resetState)
  teardown(resetState)

  test("fetches standing orders with the session's credentials", function()
    local requests = initSession(true, function()
      return standingOrdersResult({ fixtures.SO_RENT, fixtures.SO_BROADCASTING })
    end)

    local response = FetchScheduledPayments(ACCOUNT) --[[@as MM.FetchScheduledPaymentsResponse]]

    assert.are_equal(1, #requests)
    local request = requests[1] --[[@as table]]
    assert.are_equal("blob", request.credentials.connectionData)
    assert.is_nil(request.connectionData)
    assert.are_equal(2, #response.payments)
    assert.are_equal("Stefanie Müller-Schmitt", (response.payments[1] --[[@as MM.ScheduledPayment]]).name)
  end)

  test("skips connections that opt out of standing orders", function()
    local requests = initSession(false, function()
      return standingOrdersResult({})
    end)

    assert.is_nil(FetchScheduledPayments(ACCOUNT))
    assert.are_equal(0, #requests)
  end)

  test("keeps the known standing orders when the bank requires an interactive step", function()
    initSession(true, function()
      error(rc.InterruptError:new())
    end)

    -- `nil` instead of an error message: MoneyMoney keeps its stored standing orders
    assert.is_nil(FetchScheduledPayments(ACCOUNT))
  end)
end)
