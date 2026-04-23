-- SPDX-License-Identifier: MIT

-- Unit tests for yaxi.result module.

dofile("tests/mm_env.lua")

local assert = require("luassert")
local fixtures = require("tests.fixtures")
local result = require("yaxi.result")

local Session = require("yaxi.session")
local base64 = require("routex-client.util.base64")
local jwt = require("routex-client.jwt")

local FAKE_TEST_KEY_SECRET = "YAXI"
local TEST_KEY_BINARY = base64.decode(FAKE_TEST_KEY_SECRET) or error("Failed to decode key")

local DEMO_IBAN = fixtures.DEMO_IBAN

---Encode a YAXI-style result JWT with the given data payload.
---@param data any
---@return string
local function encodeResultJWT(data)
  local payload = {
    exp = os.time() + 600,
    data = {
      id = MM.uuid(),
      service = "Test",
      data = data,
    },
  }
  return jwt.encode(payload, TEST_KEY_BINARY, "HS256")
end

---Create a mock session for result caching tests.
---Uses the real transactionMapping to exercise the full decode→map pipeline.
---@return any
local function mockSession()
  local transactionMapping = require("yaxi.mapping.transaction")
  local connection = {
    transactionCodePreference = nil,
    paymentTypes = { PaymentTypeTransfer },
    mapTransaction = function(self, tx)
      return transactionMapping.mapTransaction(tx, self)
    end,
  }

  local sess = setmetatable({}, Session)
  sess.apiKeySecret = FAKE_TEST_KEY_SECRET
  sess.connection = connection
  sess.balancesCache = nil
  sess.transactionsCache = nil
  sess.balancesResult = nil
  sess.result = nil
  return sess
end

---Create a mock Result OBResponse.
---@param resultJWT string
---@return table
local function mockResult(resultJWT)
  local rc = require("routex-client")
  local obj = setmetatable({}, rc.Result)
  obj.jwt = resultJWT
  return obj
end

local TX_SALARY = fixtures.TX_SALARY
local TX_DIRECT_DEBIT = fixtures.TX_DIRECT_DEBIT

context("yaxi.result", function()
  context("decodeResultData", function()
    test("decodes a YAXI result JWT and returns the data payload", function()
      local original = { foo = "bar", count = 42 }
      local token = encodeResultJWT(original)
      local decoded = result.decodeResultData(token, FAKE_TEST_KEY_SECRET)
      assert.are_same(original, decoded)
    end)
  end)

  context("cacheBalancesResult", function()
    test("populates balancesCache from a balances result", function()
      local balancesData = {
        balances = {
          {
            account = { iban = DEMO_IBAN },
            balances = {
              { balanceType = "Booked", amount = "12500.00", currency = "EUR" },
              { balanceType = "Available", amount = "12000.00", currency = "EUR" },
            },
          },
        },
      }
      local token = encodeResultJWT(balancesData)
      local sess = mockSession()
      sess.balancesResult = mockResult(token)

      result.cacheBalancesResult(sess)

      assert.is_not_nil(sess.balancesCache)
      local cached = sess.balancesCache[DEMO_IBAN]
      assert.is_not_nil(cached)
      assert.are_equal(12500.00, cached.balance)
      assert.are_equal(-500.00, cached.pendingBalance)
    end)

    test("handles multiple accounts", function()
      local balancesData = {
        balances = {
          {
            account = { iban = DEMO_IBAN },
            balances = { { balanceType = "Booked", amount = "12458.31", currency = "EUR" } },
          },
          {
            account = { iban = "DE89370400440532013000" },
            balances = { { balanceType = "Available", amount = "5000.00", currency = "EUR" } },
          },
        },
      }
      local token = encodeResultJWT(balancesData)
      local sess = mockSession()
      sess.balancesResult = mockResult(token)

      result.cacheBalancesResult(sess)

      assert.are_equal(12458.31, sess.balancesCache[DEMO_IBAN].balance)
      assert.are_equal(5000.00, sess.balancesCache["DE89370400440532013000"].balance)
    end)
  end)

  context("cacheTransactionsResult", function()
    test("decodes and maps real transactions through the full pipeline", function()
      local token = encodeResultJWT({ TX_SALARY, TX_DIRECT_DEBIT })
      local sess = mockSession()
      sess.result = mockResult(token)

      result.cacheTransactionsResult(sess, DEMO_IBAN)

      assert.is_not_nil(sess.transactionsCache)
      local cached = sess.transactionsCache[DEMO_IBAN]
      assert.are_equal(2, #cached)

      -- Salary (credit)
      assert.are_equal(3656.58, cached[1].amount)
      assert.are_equal("DATEV eG", cached[1].name)
      assert.is_true(cached[1].booked)

      -- Direct debit
      assert.are_equal(-5.99, cached[2].amount)
      assert.are_equal("PayPal Europe S.a.r.l. et Cie S.C.A", cached[2].name)
      assert.are_equal("P6PYPY6Y5N2YU", cached[2].mandateReference)
    end)

    test("filters out unmappable transactions", function()
      local transactions = {
        TX_SALARY,
        { status = "Booked" }, -- no amount → mapTransaction returns nil
      }
      local token = encodeResultJWT(transactions)
      local sess = mockSession()
      sess.result = mockResult(token)

      result.cacheTransactionsResult(sess, DEMO_IBAN)

      assert.are_equal(1, #sess.transactionsCache[DEMO_IBAN])
    end)
  end)

  context("buildRefreshResponse", function()
    test("assembles balance, transactions, and paymentTypes", function()
      local sess = mockSession()
      sess.balancesCache = {
        [DEMO_IBAN] = { balance = 12458.31, pendingBalance = 12000.00 },
      }
      sess.transactionsCache = {
        [DEMO_IBAN] = {
          { amount = 3656.58, bookingDate = 0 },
          { amount = -5.99, bookingDate = 0 },
        },
      }

      local response = result.buildRefreshResponse(sess, DEMO_IBAN, { PaymentTypeTransfer })

      assert.are_equal(12458.31, response.balance)
      assert.are_equal(12000.00, response.pendingBalance)
      assert.are_equal(2, #response.transactions)
      assert.are_same({ PaymentTypeTransfer }, response.paymentTypes)
    end)

    test("defaults to balance=0 when no cached balance", function()
      local sess = mockSession()
      sess.balancesCache = {}
      sess.transactionsCache = { [DEMO_IBAN] = {} }

      local response = result.buildRefreshResponse(sess, DEMO_IBAN)

      assert.are_equal(0, response.balance)
      assert.is_nil(response.pendingBalance)
    end)

    test("defaults to empty transactions when no cache", function()
      local sess = mockSession()
      sess.balancesCache = { [DEMO_IBAN] = { balance = 12458.31 } }
      sess.transactionsCache = nil

      local response = result.buildRefreshResponse(sess, DEMO_IBAN)

      assert.are_same({}, response.transactions)
    end)
  end)
end)
