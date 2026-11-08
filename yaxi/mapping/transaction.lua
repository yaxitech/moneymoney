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

---German business transaction code (Geschäftsvorfallcode) as an integer.
---@param code YAXI.RoutexClient.Result.Transaction.BankTransactionCodes
---@return integer?
local function germanCode(code)
  local gvc = code.national and code.national.country == "DE" and math.tointeger(tonumber(code.national.code))
  return gvc and gvc >= 0 and gvc <= 999 and gvc or nil
end

-- Placeholders that fall back to the enclosing ISO level
local ISO_PLACEHOLDERS = { OTHR = true, NTAV = true }

---Name the transaction type with `TransactionCode()`, which resolves
---`DOMN-FAMI-SUBF` (ISO), `NDDT` (SWIFT), and `NDDT+105` (GVC, then SWIFT).
---The German business transaction code goes first: banks derive the ISO and
---SWIFT codes from it, and these mappings are sometimes wrong.
---@param bankTransactionCodes YAXI.RoutexClient.Result.Transaction.BankTransactionCodes[]?
---@return string?
local function transactionType(bankTransactionCodes)
  local keys = { gvc = {}, iso = {}, swift = {}, other = {} }
  for _, code in ipairs(bankTransactionCodes or {}) do
    local gvc = germanCode(code)
    if gvc then
      -- `XXX` is no SWIFT code, so the lookup stops at the GVC
      table.insert(keys.gvc, string.format("NXXX+%03d", gvc))
    elseif code.iso then
      local levels = {}
      for _, level in ipairs({ code.iso.domain, code.iso.family, code.iso.subFamily }) do
        table.insert(levels, (not level or ISO_PLACEHOLDERS[level]) and "XXXX" or level)
      end
      table.insert(keys.iso, table.concat(levels, "-"))
    elseif code.swift then
      table.insert(keys.swift, #code.swift == 3 and "N" .. code.swift or code.swift)
    elseif code.other then
      table.insert(keys.other, code.other.code)
    end
  end

  for _, group in ipairs({ keys.gvc, keys.iso, keys.swift, keys.other }) do
    for _, key in ipairs(group) do
      local ok, result = pcall(TransactionCode, key)
      local name = ok and result and notEmpty(result.name)
      if name then
        return name
      end
    end
  end
  return nil
end

---First `other` bank code that reads like text instead of a code: codes
---consist of uppercase ASCII letters, digits, and separators.
---@param bankTransactionCodes YAXI.RoutexClient.Result.Transaction.BankTransactionCodes[]?
---@return string?
local function plainTextCode(bankTransactionCodes)
  for _, code in ipairs(bankTransactionCodes or {}) do
    local text = code.other and code.other.code
    if text and text:find("%a") and text:find("[%l%s\128-\255]") then
      return text
    end
  end
  return nil
end

---Look up the purpose code's name, skipping the uninformative `OTHR`.
---@param purposeCode string?
---@return string?
local function purposeCodeName(purposeCode)
  if not purposeCode or purposeCode == "OTHR" then
    return nil
  end
  local ok, result = pcall(PurposeCode, purposeCode)
  return ok and result and notEmpty(result.name) or nil
end

---End-to-end reference without placeholders like `NOTPROVIDED`.
---@param endToEndId string?
---@return string?
function M.endToEndReference(endToEndId)
  if endToEndId and endToEndId:upper():match("^%s*NOT[ _]?PROVIDED%s*$") then
    return nil
  end
  return notEmpty(endToEndId)
end

---@type table<string, { originalAmount: string, exchangeRate: string, fee: string }>
local CURRENCY_LABELS = {
  de = { originalAmount = "Originalbetrag", exchangeRate = "Wechselkurs", fee = "Gebühr" },
  en = { originalAmount = "Original amount", exchangeRate = "Exchange rate", fee = "Fee" },
}

---@param value number
---@param currency string
---@return string
local function formatAmount(value, currency)
  return MM.localizeAmount("#,##0.00", math.abs(value)) .. " " .. currency
end

---Describe the original amount, exchange rates, and fees, one line each.
---@param tx YAXI.RoutexClient.Result.Transaction
---@param amount number Billed amount
---@return string[]
local function currencyDetails(tx, amount)
  local labels = CURRENCY_LABELS[MM.language] or CURRENCY_LABELS.en
  local lines = {} ---@type string[]

  local original = tx.originalAmount
  local originalValue = original and tonumber(original.amount)
  if
    original
    and originalValue
    and (original.currency ~= tx.amount.currency or math.abs(originalValue) ~= math.abs(amount))
  then
    table.insert(lines, labels.originalAmount .. ": " .. formatAmount(originalValue, original.currency))
  end

  for _, exchange in ipairs(tx.exchanges or {}) do
    local rate = tonumber(exchange.exchangeRate)
    if rate then
      -- "1 <unit> = <rate> <quoted>"
      local unit = exchange.unitCurrency or exchange.sourceCurrency
      local quoted = unit == exchange.sourceCurrency and (exchange.targetCurrency or tx.amount.currency)
        or exchange.sourceCurrency
      local text = MM.localizeNumber("#,##0.######", rate)
      if quoted ~= unit then
        text = string.format("1 %s = %s %s", unit, text, quoted)
      end
      table.insert(lines, labels.exchangeRate .. ": " .. text)
    end
  end

  for _, fee in ipairs(tx.fees or {}) do
    local value = fee.amount and tonumber(fee.amount.amount)
    if value then
      table.insert(lines, labels.fee .. ": " .. formatAmount(value, fee.amount.currency))
    end
  end

  return lines
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
    transactionCode = transactionCode or germanCode(code)
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
---@return MM.Transaction?
function M.mapTransaction(tx)
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
    or dateToTimestamp(os.date("%Y-%m-%d") --[[@as string]])

  -- Creditor for debits, debtor for credits; a reversal keeps the parties of
  -- the original transaction
  local outgoing = amount < 0
  if tx.reversal then
    outgoing = not outgoing
  end
  local party = outgoing and tx.creditor or tx.debtor

  local purposeLines = {} ---@type string[]
  for _, line in ipairs(tx.remittanceInformation or {}) do
    table.insert(purposeLines, line)
  end
  for _, line in ipairs(currencyDetails(tx, amount)) do
    table.insert(purposeLines, line)
  end

  local bookingText = transactionType(tx.bankTransactionCodes)
    or purposeCodeName(tx.purposeCode)
    or notEmpty(tx.additionalInformation)
    or plainTextCode(tx.bankTransactionCodes)
  local transactionCode, bookingKey = extractNativeCodes(tx.bankTransactionCodes)

  ---@type MM.Transaction
  local transaction = {
    amount = amount,
    currency = tx.amount and tx.amount.currency,
    timezone = "UTC",
    bookingDate = bookingDate,
    valueDate = M.safeDateToTimestamp(tx.valueDate),
    booked = SETTLED_STATUS[tx.status] or false,
    name = party and party.name,
    accountNumber = party and party.iban,
    bankCode = party and party.bic,
    ultimateName = party and party.ultimate,
    purpose = notEmpty(table.concat(purposeLines, "\n")),
    purposeCode = tx.purposeCode,
    bookingText = bookingText,
    transactionCode = transactionCode,
    bookingKey = bookingKey,
    endToEndReference = M.endToEndReference(tx.endToEndId),
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
