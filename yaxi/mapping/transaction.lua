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
  local utc = os.date("!*t", noon)
  local loc = os.date("*t", noon)
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

---Extract the German business transaction code (Geschäftsvorfallcode) and
---the SWIFT booking key from the bank transaction codes.
---@param bankTransactionCodes YAXI.RoutexClient.Result.Transaction.BankTransactionCodes[]?
---@return integer? transactionCode
---@return string? bookingKey
local function extractNativeCodes(bankTransactionCodes)
  ---@type integer?, string?
  local transactionCode, bookingKey
  for _, code in ipairs(bankTransactionCodes or {}) do
    if not transactionCode and code.national and code.national.country == "DE" then
      local gvc = tonumber(code.national.code)
      transactionCode = gvc and math.tointeger(gvc)
    end
    if not bookingKey and code.swift then
      bookingKey = code.swift
    end
  end
  return transactionCode, bookingKey
end

---Safely parse a `YYYY-MM-DD` date string, returning `nil` on failure.
---@param yyyymmdd string?
---@return integer?
function M.safeDateToTimestamp(yyyymmdd)
  if not yyyymmdd then
    return nil
  end
  local ok, result = pcall(dateToTimestamp, yyyymmdd)
  if ok then
    return result
  end
  return nil
end

---Transaction statuses that represent a settled transaction.
---@type table<string, true>
local SETTLED_STATUS = {
  Booked = true,
  Invoiced = true,
  Paid = true,
}

---Map a YAXI transaction to an `MM.Transaction`.
---Returns `nil` for transactions that cannot be mapped (e.g. missing amount)
---or that must not be reported (canceled).
---@param tx YAXI.RoutexClient.Result.Transaction
---@param connection YAXI.MoneyMoney.Connection
---@return MM.Transaction?
function M.mapTransaction(tx, connection)
  local amount = tx.amount and tx.amount.amount and tonumber(tx.amount.amount)
  if not amount then
    log:warn("Skipping transaction without parseable amount (id=%s)", tx.transactionId or tx.endToEndId or "?")
    return nil
  end

  if tx.status == "Canceled" then
    log:debug("Skipping canceled transaction (id=%s)", tx.transactionId or "?")
    return nil
  end

  -- Pending transactions often carry only a value date; "now" would shift
  -- on every refresh
  local bookingDate = M.safeDateToTimestamp(tx.bookingDate)
    or M.safeDateToTimestamp(tx.transactionDate)
    or M.safeDateToTimestamp(tx.valueDate)
    or os.time()

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

  local transactionCode, bookingKey = extractNativeCodes(tx.bankTransactionCodes)

  ---@type MM.Transaction
  local transaction = {
    amount = amount,
    currency = tx.amount and tx.amount.currency,
    bookingDate = bookingDate,
    valueDate = M.safeDateToTimestamp(tx.valueDate),
    booked = SETTLED_STATUS[tx.status] or false,
    name = party and party.name,
    accountNumber = party and party.iban,
    bankCode = party and party.bic,
    ultimateName = party and party.ultimate,
    purpose = purpose or purposeCodeName,
    purposeCode = tx.purposeCode,
    bookingText = bookingText,
    transactionCode = transactionCode,
    bookingKey = bookingKey,
    endToEndReference = tx.endToEndId,
    mandateReference = tx.mandateId,
    creditorId = tx.creditorId,
    -- Deduplication key; never `endToEndId`, which is often "NOTPROVIDED"
    -- and repeats across standing order occurrences
    transactionId = tx.accountServicerReference or tx.entryReference or tx.transactionId or tx.paymentId,
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
