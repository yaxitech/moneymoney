-- SPDX-License-Identifier: MIT
-- Author: Vincent Haupert <vincent.haupert@yaxi.tech>

-- YAXI Standing Order Mapper: YAXI standing order -> `MM.ScheduledPayment`

local log = (require("routex-client.logging") --[[@as lualogging]]).defaultLogger()

local formatDate = require("routex-client.util.date").formatDate
local transactionMapping = require("yaxi.mapping.transaction")
local util = require("yaxi.util")

local dateToTimestamp = transactionMapping.safeDateToTimestamp

local M = {}

---Map a YAXI frequency to a MoneyMoney recurrence unit and period.
---Returns `nil` for frequencies MoneyMoney cannot express (e.g., every 10 days).
---@param frequency YAXI.RoutexClient.Result.StandingOrder.Frequency?
---@return MM.StandingOrderUnit? unit
---@return integer? period
local function mapFrequency(frequency)
  local f = frequency --[[@as { months: number?, days: number?, variableMonths: integer[]? }?]]
  if not f then
    return nil
  end
  if f.months and f.months > 0 then
    return "M", math.tointeger(f.months)
  end
  if f.days and f.days > 0 and f.days % 7 == 0 then
    return "W", math.tointeger(f.days // 7)
  end
  -- Evenly spaced months, e.g., January, April, July, and October: quarterly
  local months = f.variableMonths
  if months and #months > 0 and 12 % #months == 0 then
    local sorted = table.move(months, 1, #months, 1, {})
    table.sort(sorted)
    local period = 12 // #sorted
    for i = 2, #sorted do
      if sorted[i] - sorted[i - 1] ~= period then
        return nil
      end
    end
    return "M", period
  end
  return nil
end

---Next execution on or after `today`, or `nil` if it is unknown or the standing
---order has ended.
---Ignores the bank's execution rule for weekends and holidays.
---@param so YAXI.RoutexClient.Result.StandingOrder
---@param unit MM.StandingOrderUnit?
---@param period integer?
---@param today string `YYYY-MM-DD`
---@return string?
local function nextExecution(so, unit, period, today)
  local todayTs = dateToTimestamp(today)
  local startDate = so.startDate
  if not startDate then
    -- Monthly orders on a fixed day don't depend on the start; anchor them in
    -- the previous month so the first execution falls on or after `today`
    if unit ~= "M" or period ~= 1 or not so.day or not todayTs then
      return nil
    end
    local now = os.date("!*t", todayTs) --[[@as osdate]]
    local year = now.month == 1 and now.year - 1 or now.year
    startDate = formatDate({ year = year, month = (now.month - 2) % 12 + 1, day = 1 }) --[[@as string]]
  end
  local nextDate = startDate
  local startTs = dateToTimestamp(startDate)
  if startTs and todayTs and startTs < todayTs and period then
    if unit == "M" then
      local start = os.date("!*t", startTs) --[[@as osdate]]
      local now = os.date("!*t", todayTs) --[[@as osdate]]
      local k = ((now.year - start.year) * 12 + now.month - start.month) // period
      repeat
        local months = start.month - 1 + k * period
        local year, month = start.year + months // 12, months % 12 + 1
        -- Day 0 of the following month is the last day of this one
        local monthEnd = os.date("*t", os.time({ year = year, month = month + 1, day = 0, hour = 12 })) --[[@as osdate]]
        local day = math.min(math.tointeger(so.day) or start.day, monthEnd.day)
        nextDate = formatDate({ year = year, month = month, day = day }) --[[@as string]]
        k = k + 1
      until nextDate >= today
    else
      local step = 7 * period * 86400
      nextDate = transactionMapping.timestampToDate(startTs + math.ceil((todayTs - startTs) / step) * step)
    end
  end
  if nextDate < today or (so.endDate and nextDate > so.endDate) then
    return nil
  end
  return nextDate
end

-- Day code for the month's last day
local LAST_DAY = 99

---Day of the month (`LAST_DAY` for its last day) or ISO weekday of the
---executions. Without an explicit day, the start date's day or weekday.
---@param so YAXI.RoutexClient.Result.StandingOrder
---@param unit MM.StandingOrderUnit?
---@return integer?
local function executionDay(so, unit)
  local startTs = dateToTimestamp(so.startDate)
  if unit == "M" then
    local day = math.tointeger(so.day)
    if not day and startTs then
      day = (os.date("!*t", startTs) --[[@as osdate]]).day
    end
    return day == 31 and LAST_DAY or day
  end
  if unit == "W" and startTs then
    -- 1970-01-01 was a Thursday
    return (startTs // 86400 + 3) % 7 + 1
  end
  return nil
end

---Map a YAXI standing order to an `MM.ScheduledPayment`.
---Returns `nil` for standing orders without a parseable amount or that have
---ended.
---@param so YAXI.RoutexClient.Result.StandingOrder
---@param today string? `YYYY-MM-DD`; defaults to the current local date
---@return MM.ScheduledPayment?
function M.mapStandingOrder(so, today)
  local amount = so.amount and tonumber(so.amount.amount)
  if not amount then
    log:warn("Skipping standing order without parseable amount (start=%s)", so.startDate)
    return nil
  end
  today = today or os.date("%Y-%m-%d")
  if so.endDate and so.endDate < today then
    log:debug("Skipping standing order that ended on %s", so.endDate)
    return nil
  end

  local creditor = so.creditor
  local purpose = util.notEmpty(so.remittanceInformation and table.concat(so.remittanceInformation, "\n") or nil)
  local unit, period = mapFrequency(so.frequency)
  local nextDate = nextExecution(so, unit, period, today)

  ---@type MM.ScheduledPayment
  return {
    type = PaymentTypeStandingOrder,
    -- YAXI assigns no identifier; hash what stays the same over the order's
    -- life, as banks let users change its amount and purpose
    orderId = MM.sha256(
      table.concat({ so.startDate or "", creditor and creditor.iban or "", so.amount.currency }, "\n")
    ),
    name = creditor and creditor.name,
    accountNumber = creditor and creditor.iban,
    bankCode = creditor and creditor.bic,
    purpose = purpose,
    purposeCode = so.purposeCode,
    endToEndReference = so.endToEndId,
    amount = amount,
    currency = so.amount.currency,
    scheduledDate = dateToTimestamp(nextDate),
    standingOrderStart = dateToTimestamp(so.startDate),
    standingOrderEnd = dateToTimestamp(so.endDate),
    standingOrderUnit = unit,
    standingOrderPeriod = period,
    standingOrderDay = executionDay(so, unit),
  }
end

---Map YAXI standing orders to `MM.ScheduledPayment`s with unique `orderId`s.
---Orders sharing start date and creditor fall back to their amount and
---purpose, then to their position among identical orders.
---@param standingOrders YAXI.RoutexClient.Result.StandingOrder[]
---@param today string? `YYYY-MM-DD`; defaults to the current local date
---@return MM.ScheduledPayment[]
function M.mapStandingOrders(standingOrders, today)
  local payments = {} ---@type MM.ScheduledPayment[]
  local counts = {} ---@type table<string, integer>
  for _, so in ipairs(standingOrders) do
    local payment = M.mapStandingOrder(so, today)
    if payment then
      table.insert(payments, payment)
      counts[payment.orderId] = (counts[payment.orderId] or 0) + 1
    end
  end

  local seen = {} ---@type table<string, integer>
  for _, payment in ipairs(payments) do
    if counts[payment.orderId] > 1 then
      local id = MM.sha256(table.concat({ payment.orderId, tostring(payment.amount), payment.purpose or "" }, "\n"))
      seen[id] = (seen[id] or 0) + 1
      payment.orderId = seen[id] > 1 and MM.sha256(id .. "\n" .. seen[id]) or id
    end
  end
  return payments
end

return M
