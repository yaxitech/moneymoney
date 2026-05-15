-- SPDX-License-Identifier: MIT
-- Author: Vincent Haupert <vincent.haupert@yaxi.tech>

-- YAXI Transaction Mapper — YAXI transaction → `MM.Transaction`

local log = (require("routex-client.logging") --[[@as lualogging]]).defaultLogger()

local util = require("yaxi.util")

local notEmpty = util.notEmpty

local M = {}

---Convert a `YYYY-MM-DD` date string to a UTC midnight POSIX timestamp.
---@param yyyymmdd string
---@return integer
local function dateToTimestamp(yyyymmdd)
  local year, month, day = yyyymmdd:match("(%d+)-(%d+)-(%d+)")
  if not year or not month or not day then
    error("Invalid date format: " .. tostring(yyyymmdd))
  end
  -- Use noon local time to safely compute the UTC offset (avoids DST edges)
  local noon = os.time({
    year = tonumber(year),
    month = tonumber(month),
    day = tonumber(day),
    hour = 12,
  } --[[@as std.osdateparam]])
  local utc = os.date("!*t", noon) --[[@as std.osdateparam]]
  local loc = os.date("*t", noon) --[[@as std.osdateparam]]
  utc.isdst = loc.isdst
  local offset = os.difftime(os.time(loc), os.time(utc))
  return noon - 12 * 3600 + math.floor(offset)
end

---Extract a booking text from `bankTransactionCodes` using `TransactionCode()`.
---@param bankTransactionCodes YAXI.RoutexClient.Result.Transaction.BankTransactionCodes[]?
---@param preferences string[]?
---@return string?
local function extractTransactionCode(bankTransactionCodes, preferences)
  local res = nil

  for _, code in ipairs(bankTransactionCodes or {}) do
    local param, codeType
    if code.iso then
      param = code.iso.subFamily or code.iso.family or code.iso.domain
      codeType = "iso"
    elseif code.swift then
      param = code.swift
      codeType = "swift"
    elseif code.bai then
      param = code.bai
      codeType = "bai"
    elseif code.national and code.national.code then
      param = code.national.code
      codeType = "national"
    elseif code.other and code.other.code then
      param = code.other.code
      codeType = "other"
    end

    local mmCode = param and TransactionCode(param) or nil ---@type MM.TransactionCodeResult?
    local codeName = mmCode and mmCode.name or nil ---@type string?
    if codeName ~= nil then
      -- Check if this code type is preferred
      for _, pref in ipairs(preferences or {}) do
        if pref == codeType then
          return codeName
        end
      end
      if not res then
        res = codeName
      end
    end
  end

  return res
end

---Safely parse a `YYYY-MM-DD` date string, returning `nil` on failure.
---@param yyyymmdd string?
---@return integer?
local function safeDateToTimestamp(yyyymmdd)
  if not yyyymmdd then
    return nil
  end
  local ok, result = pcall(dateToTimestamp, yyyymmdd)
  if ok then
    return result --[[@as integer]]
  end
  return nil
end

---Map a YAXI transaction to an `MM.Transaction`.
---Returns `nil` for transactions that cannot be mapped (e.g. missing amount).
---@param tx YAXI.RoutexClient.Result.Transaction
---@param connection YAXI.MoneyMoney.Connection
---@return MM.Transaction?
function M.mapTransaction(tx, connection)
  local amount = tx.amount and tx.amount.amount and tonumber(tx.amount.amount)
  if not amount then
    log:warn("Skipping transaction without parseable amount (id=%s)", tx.transactionId or tx.endToEndId or "?")
    return nil
  end

  -- Determine booking date with fallback chain
  local bookingDate = safeDateToTimestamp(tx.bookingDate) or safeDateToTimestamp(tx.transactionDate) or os.time()

  -- Select counterparty: creditor for debits, debtor for credits
  ---@type YAXI.RoutexClient.Result.Transaction.Party?
  local party = amount < 0 and tx.creditor or tx.debtor

  local purpose = notEmpty(tx.remittanceInformation and table.concat(tx.remittanceInformation, "\n") or nil)

  local purposeCodeName = nil ---@type string?
  if tx.purposeCode then
    local ok, resolved = pcall(PurposeCode, tx.purposeCode)
    if ok and resolved then
      purposeCodeName = notEmpty((resolved --[[@as MM.PurposeCodeResult]]).name)
    end
  end

  local bookingText = extractTransactionCode(tx.bankTransactionCodes, connection.transactionCodePreference)
  if not bookingText then
    bookingText = purposeCodeName
  end
  if not bookingText then
    bookingText = notEmpty(tx.additionalInformation)
  end

  ---@type MM.Transaction
  local transaction = {
    amount = amount,
    currency = tx.amount and tx.amount.currency,
    bookingDate = bookingDate,
    valueDate = safeDateToTimestamp(tx.valueDate),
    booked = tx.status == "Booked",
    name = party and party.name,
    accountNumber = party and party.iban,
    bankCode = party and party.bic,
    ultimateName = party and party.ultimate,
    purpose = purpose or purposeCodeName,
    purposeCode = tx.purposeCode,
    bookingText = bookingText,
    endToEndReference = tx.endToEndId,
    mandateReference = tx.mandateId,
    creditorId = tx.creditorId,
    transactionId = tx.accountServicerReference or tx.transactionId or tx.paymentId or tx.endToEndId,
  }

  return transaction
end

---Convert a POSIX timestamp to a UTC `YYYY-MM-DD` date string.
---@param timestamp integer
---@return string
function M.timestampToDate(timestamp)
  local res = os.date("!%Y-%m-%d", timestamp)
  assert(type(res) == "string", "Expected a YYYY-MM-DD string")
  return res
end

return M
