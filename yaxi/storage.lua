-- SPDX-License-Identifier: MIT
-- Author: Vincent Haupert <vincent.haupert@yaxi.tech>

-- Typed access to MoneyMoney's `LocalStorage`. Tables read back carry no metatables.

local StorageKey = require("yaxi.enum").StorageKey

local M = {}

---@return YAXI.RoutexClient.AccountReference[]?
function M.getAccounts()
  return LocalStorage[StorageKey.Accounts]
end

---@param refs YAXI.RoutexClient.AccountReference[]
function M.setAccounts(refs)
  LocalStorage[StorageKey.Accounts] = refs
end

---YAXI account data by IBAN.
---@return table<string, YAXI.RoutexClient.Result.Account>
function M.getAccountsData()
  return LocalStorage[StorageKey.AccountsData] or {}
end

---@param byIban table<string, YAXI.RoutexClient.Result.Account>
function M.setAccountsData(byIban)
  LocalStorage[StorageKey.AccountsData] = byIban
end

---Discovered TAN method `hbciMethod` codes by connection ID.
---@return table<string, string[]>
function M.getTanMethods()
  return LocalStorage[StorageKey.TanMethods] or {}
end

---@param byConnectionId table<string, string[]>
function M.setTanMethods(byConnectionId)
  LocalStorage[StorageKey.TanMethods] = byConnectionId
end

---Service call counts by month (`"YYYY-MM"`) and service.
---@return table<string, table<string, integer>>
function M.getUsage()
  return LocalStorage[StorageKey.Usage] or {}
end

---@param usage table<string, table<string, integer>>
function M.setUsage(usage)
  LocalStorage[StorageKey.Usage] = usage
end

---Last refresh timestamps by IBAN.
---@return table<string, integer>
function M.getLastRefresh()
  return LocalStorage[StorageKey.LastRefresh] or {}
end

---@param byIban table<string, integer>
function M.setLastRefresh(byIban)
  LocalStorage[StorageKey.LastRefresh] = byIban
end

---@param connectionId string
---@return binary?
function M.getConnectionData(connectionId)
  return LocalStorage[connectionId]
end

---@param connectionId string
---@param connectionData binary?
function M.setConnectionData(connectionId, connectionData)
  LocalStorage[connectionId] = connectionData
end

---@param connectionId string
function M.clearSession(connectionId)
  LocalStorage[connectionId .. ":session"] = nil
end

return M
