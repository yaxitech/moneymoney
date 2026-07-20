-- SPDX-License-Identifier: MIT
-- Author: Vincent Haupert <vincent.haupert@yaxi.tech>

local log = (require("routex-client.logging") --[[@as lualogging]]).defaultLogger()

local M = {}

---Whether `entry` should replace the current `best` pick of a bucket: true when there
---is no pick yet, or when both carry a `dateTime` and `entry`'s is strictly more recent.
---ISO 8601 date-times compare lexicographically. When recency is indeterminate (either
---`dateTime` missing), the earlier pick is kept, preserving the reported order.
---@param entry YAXI.RoutexClient.Result.Balances.Payload.Entry
---@param best YAXI.RoutexClient.Result.Balances.Payload.Entry?
---@return boolean
local function isFresher(entry, best)
  if not best then
    return true
  end
  if entry.dateTime and best.dateTime then
    return entry.dateTime > best.dateTime
  end
  return false
end

---Freshest `Booked` or `Available` without a credit line and with `dateTime <= now`;
---an equal `dateTime` prefers `Booked`. Nil when none qualifies.
---@param balanceEntries YAXI.RoutexClient.Result.Balances.Payload.Entry[]
---@param now string Current time as an ISO 8601 date-time.
---@return YAXI.RoutexClient.Result.Balances.Payload.Entry?
local function pickFreshest(balanceEntries, now)
  ---@type YAXI.RoutexClient.Result.Balances.Payload.Entry?
  local best
  ---@type string?
  local bestDate
  for _, entry in ipairs(balanceEntries) do
    local dateTime = entry.dateTime
    if
      dateTime ~= nil
      and dateTime <= now
      and not entry.creditLimitIncluded
      and (entry.balanceType == "Booked" or entry.balanceType == "Available")
    then
      if not bestDate or dateTime > bestDate or (dateTime == bestDate and entry.balanceType == "Booked") then
        best = entry
        bestDate = dateTime
      end
    end
  end
  return best
end

---@param balanceEntries YAXI.RoutexClient.Result.Balances.Payload.Entry[]
---@param types string[]
---@param creditLimitValues boolean[]
---@return YAXI.RoutexClient.Result.Balances.Payload.Entry?
local function findEntry(balanceEntries, types, creditLimitValues)
  for _, withCreditLimit in ipairs(creditLimitValues) do
    for _, balanceType in ipairs(types) do
      -- Within a (creditLimitIncluded, balanceType) bucket, prefer the entry valid at
      -- the most recent `dateTime`, e.g. an interim booked balance over a prior
      -- bookkeeping day's closing balance. Ties keep the reported order.
      ---@type YAXI.RoutexClient.Result.Balances.Payload.Entry?
      local best
      for _, entry in ipairs(balanceEntries) do
        if entry.balanceType == balanceType and (entry.creditLimitIncluded or false) == withCreditLimit then
          if isFresher(entry, best) then
            best = entry
          end
        end
      end
      if best then
        return best
      end
    end
  end
end

---Picks the account `balance` and, for a `Booked` balance, a `pendingBalance` delta
---(Expected/Available minus Booked). The balance is the most recent `Booked` or
---`Available` without a credit line and valid at `now`, preferring `Booked` on an
---equal `dateTime`.
---@param balanceEntries YAXI.RoutexClient.Result.Balances.Payload.Entry[]?
---@param now? string Current time as an ISO 8601 date-time; defaults to now (UTC).
---@return YAXI.MoneyMoney.Session.BalanceEntry
function M.pickBalance(balanceEntries, now)
  if not balanceEntries or #balanceEntries == 0 then
    log:warn("No balance entries available, defaulting to 0")
    return { balance = 0 }
  end

  -- Fall back to a type scan, exhausting credit-line-free entries ({ false, true }) first.
  local primary = pickFreshest(balanceEntries, now or os.date("!%Y-%m-%dT%H:%M:%SZ") --[[@as string]])
    or findEntry(balanceEntries, { "Booked", "Expected", "Available" }, { false, true })
  if not primary then
    log:warn("No balance entry with parseable amount, defaulting to 0")
    return { balance = 0 }
  end

  if primary.creditLimitIncluded then
    log:warn(
      "No creditLimitIncluded=false balance found; falling back to %s (creditLimitIncluded=true)",
      primary.balanceType
    )
  end
  log:debug(
    "Picked %s balance (creditLimitIncluded=%s): %s",
    primary.balanceType,
    tostring(primary.creditLimitIncluded),
    primary.amount
  )

  ---@type YAXI.MoneyMoney.Session.BalanceEntry
  local result = { balance = tonumber(primary.amount) or 0 }

  if primary.balanceType == "Booked" then
    local pendingEntry = findEntry(balanceEntries, { "Expected", "Available" }, { false, true })
    if pendingEntry then
      local delta = (tonumber(pendingEntry.amount) or 0) - result.balance
      if delta ~= 0 then
        log:debug(
          "Picked %s pending balance delta (creditLimitIncluded=%s): %s",
          pendingEntry.balanceType,
          tostring(pendingEntry.creditLimitIncluded),
          delta
        )
        result.pendingBalance = delta
      end
    end
  end

  return result
end

return M
