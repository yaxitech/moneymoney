-- SPDX-License-Identifier: MIT
-- Author: Vincent Haupert <vincent.haupert@yaxi.tech>

dofile("tests/mm_env.lua")

local assert = require("luassert")

local Session = require("yaxi.session")
local enum = require("yaxi.enum")
local interrupt = require("yaxi.interrupt")
local resultMod = require("yaxi.result")
local service = require("yaxi.service")
local StorageKey = enum.StorageKey

local TEST_IBAN = "DE02120300000000202051"
local CONNECTION_PAYMENT_TYPES = { PaymentTypeTransfer, PaymentTypeInstantTransfer }

local extension = require("yaxi.extension")
extension.setup({ apiKeyId = "test", apiKeySecret = "dGVzdA==" })

local function resetState()
  EndSession()
  for k in pairs(LocalStorage) do
    LocalStorage[k] = nil
  end
end

---Inject a mock session whose connection exposes `CONNECTION_PAYMENT_TYPES`.
local function initWithMockSession()
  local origNew = Session.new
  ---@diagnostic disable-next-line: duplicate-set-field
  Session.new = function(_cls, conn)
    local sess = setmetatable({}, Session)
    sess.sessionType = "refresh"
    sess.connection = conn
    sess.connection.paymentTypes = CONNECTION_PAYMENT_TYPES
    sess.credentials = { connectionId = "mock" } --[[@as YAXI.RoutexClient.Credentials]]
    sess.balancesCache = { [TEST_IBAN] = { balance = 0 } }
    return sess
  end
  InitializeSession2(ProtocolWebBanking, "YAXI Demo", 1, { "", "" } --[[@as MM.Credentials]], true, {}, "refresh")
  ---@diagnostic disable-next-line: duplicate-set-field
  Session.new = origNew
end

---Stub out service and result modules so `RefreshAccount` runs without HTTP.
---Records the `paymentTypes` argument passed to `buildRefreshResponse`.
---@return fun(): any captured `paymentTypes` value seen by `buildRefreshResponse`
local function stubAndCapture()
  local origCallTransactions = service.callTransactions
  local origMapToChallenge = interrupt.mapToChallenge
  local origCacheTransactions = resultMod.cacheTransactions
  local origBuildRefresh = resultMod.buildRefreshResponse

  local captured
  service.callTransactions = function(_sess, _iban, _currency, _since)
    ---@diagnostic disable-next-line: missing-fields
    local mockResult = { jwt = "mock" } --[[@as YAXI.RoutexClient.Result]]
    _sess.result = mockResult
    ---@diagnostic disable-next-line: access-invisible
    _sess._resultData = {}
    return mockResult
  end
  interrupt.mapToChallenge = function()
    return nil
  end
  resultMod.cacheTransactions = function() end
  resultMod.buildRefreshResponse = function(_sess, _iban, paymentTypes)
    captured = paymentTypes
    return { balance = 0, transactions = {}, paymentTypes = paymentTypes }
  end

  return function()
    service.callTransactions = origCallTransactions
    interrupt.mapToChallenge = origMapToChallenge
    resultMod.cacheTransactions = origCacheTransactions
    resultMod.buildRefreshResponse = origBuildRefresh
    return captured
  end
end

---`MM.Account` as MoneyMoney would pass it. Deliberately omits any
---`paymentTypes` field to prove derivation does not depend on it.
local REFRESH_ACCOUNT_PARAM = {
  iban = TEST_IBAN,
  currency = "EUR",
  name = "Test Account",
  bic = "YAXIDEM0",
  bankCode = "YAXI Demo",
}

context("RefreshAccount paymentTypes derivation", function()
  teardown(resetState)

  test("derives paymentTypes from stored YAXI account, not from MM.Account", function()
    resetState()
    initWithMockSession()
    LocalStorage[StorageKey.AccountsData] = {
      [TEST_IBAN] = { capabilities = { "SinglePayment", "Balances" } },
    } --[[@as any]]
    local finish = stubAndCapture()

    RefreshAccount(REFRESH_ACCOUNT_PARAM, 0, function()
      return false
    end, 1, {})

    local paymentTypes = finish()
    assert.are_same(CONNECTION_PAYMENT_TYPES, paymentTypes)
  end)

  test("omits paymentTypes when stored YAXI account lacks SinglePayment", function()
    resetState()
    initWithMockSession()
    LocalStorage[StorageKey.AccountsData] = {
      [TEST_IBAN] = { capabilities = { "Balances", "Transactions" } },
    } --[[@as any]]
    local finish = stubAndCapture()

    RefreshAccount(REFRESH_ACCOUNT_PARAM, 0, function()
      return false
    end, 1, {})

    assert.is_nil(finish())
  end)

  test("omits paymentTypes when no YAXI account data is stored", function()
    resetState()
    initWithMockSession()
    local finish = stubAndCapture()

    RefreshAccount(REFRESH_ACCOUNT_PARAM, 0, function()
      return false
    end, 1, {})

    assert.is_nil(finish())
  end)
end)
