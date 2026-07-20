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

local LAST_REFRESH_MAX_AGE_DAYS = 89
local TEST_IBAN = "DE02120300000000202051"

local extension = require("yaxi.extension")
extension.setup({ apiKeyId = "test", apiKeySecret = "dGVzdA==" })

---Create a mock session without hitting the network.
---@param sessionType MM.SessionType
---@return any
local function mockSession(sessionType)
  local sess = setmetatable({}, Session)
  sess.sessionType = sessionType
  ---@diagnostic disable-next-line: missing-fields
  sess.connection = {
    paymentTypes = { PaymentTypeTransfer },
  } --[[@as YAXI.MoneyMoney.Connection]]
  sess.credentials = { connectionId = "mock" } --[[@as YAXI.RoutexClient.Credentials]]
  sess.balancesCache = { [TEST_IBAN] = { balance = 42 } }
  sess.transactionsCache = nil
  sess.result = nil
  return sess
end

--- Reset extension and LocalStorage state.
local function resetState()
  EndSession()
  for k in pairs(LocalStorage) do
    LocalStorage[k] = nil
  end
end

--- Patch `Session.new` to inject a mock session, call `InitializeSession2`,
--- then restore the original. Returns the injected session.
---@param sessionType MM.SessionType
---@return any session
local function initWithMockSession(sessionType)
  local origNew = Session.new
  local injected
  ---@diagnostic disable-next-line: duplicate-set-field, redundant-parameter
  Session.new = function(_cls, conn, _apiKeyId, _apiKeySecret, _version)
    injected = mockSession(sessionType)
    injected.connection = conn
    injected.connection.paymentTypes = injected.connection.paymentTypes or {}
    injected.balancesCache = { [TEST_IBAN] = { balance = 42 } }
    return injected
  end
  InitializeSession2(ProtocolWebBanking, "YAXI Demo", 1, { "", "" } --[[@as MM.Credentials]], true, {}, sessionType)
  ---@diagnostic disable-next-line: duplicate-set-field
  Session.new = origNew
  return injected
end

--- Wrap service and result modules so `RefreshAccount` can complete without HTTP.
--- Returns a teardown function that restores originals and the captured `since` values.
---@return fun(): integer[] finish
local function stubServiceCalls()
  local origCallTransactions = service.callTransactions
  local origMapToChallenge = interrupt.mapToChallenge
  local origCacheTransactions = resultMod.cacheTransactions
  local origBuildRefresh = resultMod.buildRefreshResponse

  local captured = {} ---@type integer[]

  service.callTransactions = function(_sess, _iban, _currency, since)
    table.insert(captured, since)
    -- Simulate a completed Result so the caching path runs
    ---@diagnostic disable-next-line: missing-fields
    local mockResult = { jwt = "mock" } --[[@as YAXI.RoutexClient.Result]]
    _sess.result = mockResult
    ---@diagnostic disable-next-line: access-invisible
    _sess._resultData = {}
    return mockResult
  end
  interrupt.mapToChallenge = function(_sess, _obResponse)
    return nil
  end
  resultMod.cacheTransactions = function(_sess, _iban, _transactions) end
  resultMod.buildRefreshResponse = function(_sess, _iban)
    return { balance = 42, transactions = {} }
  end

  return function()
    service.callTransactions = origCallTransactions
    interrupt.mapToChallenge = origMapToChallenge
    resultMod.cacheTransactions = origCacheTransactions
    resultMod.buildRefreshResponse = origBuildRefresh
    return captured
  end
end

local REFRESH_ACCOUNT_PARAM = {
  portfolio = false,
  owner = "Test",
  attributes = {},
  bic = "YAXIDEM0",
  type = "Unknown",
  comment = "",
  balanceDate = os.time(),
  subAccount = "",
  name = "Test Account",
  iban = TEST_IBAN,
  balance = 0,
  bankCode = "YAXI Demo",
  accountNumber = "",
  currency = "EUR",
}

context("last-refresh max-age clamping", function()
  teardown(resetState)

  test("persists last refresh timestamp on success", function()
    resetState()
    initWithMockSession("refresh")
    local finish = stubServiceCalls()

    local before = os.time()
    RefreshAccount(REFRESH_ACCOUNT_PARAM, 0, function()
      return false
    end, 1, {})
    local after = os.time()
    finish()

    ---@type table<string, integer>?
    local lastRefreshByIban = LocalStorage[StorageKey.LastRefresh]
    assert.is_table(lastRefreshByIban)
    ---@cast lastRefreshByIban table<string, integer>
    local ts = lastRefreshByIban[TEST_IBAN]
    assert.is_number(ts)
    assert.is_true(ts >= before and ts <= after)
  end)

  test("clamps since when older than lastRefresh - maxAge", function()
    resetState()
    LocalStorage[StorageKey.LastRefresh] = { [TEST_IBAN] = os.time() } --[[@as any]]

    initWithMockSession("refresh")
    local finish = stubServiceCalls()

    RefreshAccount(REFRESH_ACCOUNT_PARAM, 0, function()
      return false
    end, 1, {})

    local captured = finish()
    assert.is_true(#captured > 0)
    local expectedMin = os.time() - LAST_REFRESH_MAX_AGE_DAYS * 86400 - 5
    local expectedMax = os.time() - LAST_REFRESH_MAX_AGE_DAYS * 86400 + 5
    assert.is_true(captured[1] >= expectedMin and captured[1] <= expectedMax)
  end)

  test("does not clamp on first-ever refresh (no stored timestamp)", function()
    resetState()
    initWithMockSession("refresh")
    local finish = stubServiceCalls()

    RefreshAccount(REFRESH_ACCOUNT_PARAM, 0, function()
      return false
    end, 1, {})

    local captured = finish()
    assert.is_true(#captured > 0)
    assert.are_equal(0, captured[1])
  end)

  test("does not clamp for new-account sessions", function()
    resetState()
    LocalStorage[StorageKey.LastRefresh] = { [TEST_IBAN] = os.time() } --[[@as any]]

    initWithMockSession("new account")
    local finish = stubServiceCalls()

    RefreshAccount(REFRESH_ACCOUNT_PARAM, 0, function()
      return false
    end, 1, {})

    local captured = finish()
    assert.is_true(#captured > 0)
    assert.are_equal(0, captured[1])
  end)

  test("does not clamp when since is within maxAge of lastRefresh", function()
    resetState()
    LocalStorage[StorageKey.LastRefresh] = { [TEST_IBAN] = os.time() } --[[@as any]]

    initWithMockSession("refresh")
    local finish = stubServiceCalls()

    local recentSince = os.time() - 86400
    RefreshAccount(REFRESH_ACCOUNT_PARAM, recentSince, function()
      return false
    end, 1, {})

    local captured = finish()
    assert.is_true(#captured > 0)
    assert.are_equal(recentSince, captured[1])
  end)
end)
