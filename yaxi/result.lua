-- SPDX-License-Identifier: MIT
-- Author: Vincent Haupert <vincent.haupert@yaxi.tech>

-- Result decoding and caching for YAXI service responses.

local log = (require("routex-client.logging") --[[@as lualogging]]).defaultLogger()

local balanceMapping = require("yaxi.mapping.balance")
local base64 = require("routex-client.util.base64")
local jwt = require("routex-client.jwt")

local M = {}

---Decode and verify a YAXI `Result` JWT (HMAC-SHA256), returning the `data` payload.
---
---The JWT payload structure is: `{ data: { id, service, data: <T> } }`.
---The outer `data` is the YAXI ticket claim; the inner `data` contains the
---service-specific result (e.g., accounts array, balances, transactions).
---@param resultJWT string
---@param apiKeySecret string Base64-encoded API key secret
---@return any The service-specific result data
function M.decodeResultData(resultJWT, apiKeySecret)
  local apiKeyBinary = base64.decode(apiKeySecret) or error("Failed to decode API key secret")
  local payload = jwt.decode(resultJWT, apiKeyBinary, "HS256")
  return payload.data.data
end

---Decode a balances `Result` and populate the session's `balancesCache` keyed by IBAN.
---@param sess YAXI.MoneyMoney.Session
function M.cacheBalancesResult(sess)
  assert(sess.balancesResult, "No balances result")
  local balancesData = M.decodeResultData(sess.balancesResult.jwt, sess.apiKeySecret)

  if balancesData.missingAccounts then
    for _, missing in ipairs(balancesData.missingAccounts) do
      log:warn("Missing account in balances response: %s", missing.iban)
    end
  end

  sess.balancesCache = sess.balancesCache or {}
  for _, payload in ipairs(balancesData.balances or {}) do
    local iban = payload.account and payload.account.iban
    if iban then
      sess.balancesCache[iban] = balanceMapping.pickBalance(payload.balances)
    end
  end

  log:debug("Cached balances for %d account(s)", #(balancesData.balances or {}))
end

---Decode a transactions `Result` and store in the session's `transactionsCache` for the given IBAN.
---@param sess YAXI.MoneyMoney.Session
---@param iban string
function M.cacheTransactionsResult(sess, iban)
  assert(sess.result, "No transactions result")
  local yaxiTransactions = M.decodeResultData(sess.result.jwt, sess.apiKeySecret)

  ---@type MM.Transaction[]
  local transactions = {}
  for _, tx in ipairs(yaxiTransactions or {}) do
    local mapped = sess.connection:mapTransaction(tx)
    if mapped then
      table.insert(transactions, mapped)
    end
  end

  sess.transactionsCache = sess.transactionsCache or {}
  sess.transactionsCache[iban] = transactions
  log:debug("Cached %d transactions for %s", #transactions, iban)
end

---Build the final `RefreshAccount` response from cached balances + transactions.
---@param sess YAXI.MoneyMoney.Session
---@param iban string
---@param paymentTypes MM.PaymentTypeConst[]? Per-account payment types reported in the response
---@return MM.RefreshAccountResponse
function M.buildRefreshResponse(sess, iban, paymentTypes)
  local balanceResult = sess.balancesCache and sess.balancesCache[iban]
  if not balanceResult then
    log:warn("No cached balance for %s, defaulting to 0", iban)
    balanceResult = { balance = 0 }
  end

  local transactions = sess.transactionsCache and sess.transactionsCache[iban] or {}

  log:debug(
    "Refresh result for %s: balance=%.2f, pendingBalance=%s, transactions=%d",
    iban,
    balanceResult.balance,
    balanceResult.pendingBalance and string.format("%.2f", balanceResult.pendingBalance) or "nil",
    #transactions
  )

  ---@type MM.RefreshAccountResponse
  return {
    balance = balanceResult.balance,
    pendingBalance = balanceResult.pendingBalance,
    transactions = transactions,
    paymentTypes = paymentTypes,
  }
end

return M
