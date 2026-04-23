-- SPDX-License-Identifier: MIT
-- Author: Vincent Haupert <vincent.haupert@yaxi.tech>

local log = require("routex-client.logging").defaultLogger()

local M = {}

---@param balanceEntries YAXI.RoutexClient.Result.Balances.Payload.Entry[]
---@param types string[]
---@param creditLimitValues boolean[]
---@return YAXI.RoutexClient.Result.Balances.Payload.Entry?
local function findEntry(balanceEntries, types, creditLimitValues)
  for _, withCreditLimit in ipairs(creditLimitValues) do
    for _, balanceType in ipairs(types) do
      for _, entry in ipairs(balanceEntries) do
        if entry.balanceType == balanceType and (entry.creditLimitIncluded or false) == withCreditLimit then
          return entry
        end
      end
    end
  end
end

---Picks `balance` (Booked > Expected > Available) and, when the primary is Booked,
---`pendingBalance` as a delta (Expected/Available minus Booked). Entries with
---`creditLimitIncluded=true` are deprioritized but used as a last resort.
---@param balanceEntries YAXI.RoutexClient.Result.Balances.Payload.Entry[]?
---@return YAXI.MoneyMoney.Session.BalanceEntry
function M.pickBalance(balanceEntries)
  if not balanceEntries or #balanceEntries == 0 then
    log:warn("No balance entries available, defaulting to 0")
    return { balance = 0 }
  end

  -- Outer loop over {false, true}: every entry without a credit line is exhausted before
  -- falling back to one that includes it, regardless of balance type priority.
  local primary = findEntry(balanceEntries, { "Booked", "Expected", "Available" }, { false, true })
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
