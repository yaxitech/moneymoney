-- SPDX-License-Identifier: MIT
-- Author: Vincent Haupert <vincent.haupert@yaxi.tech>

-- Enumerations and constants for the YAXI MoneyMoney extension.

local M = {}

---YAXI service names used in `session.activeService`, `getMethods`, and `recordCall`.
---@enum YAXI.RoutexClient.Service
M.Service = {
  Accounts = "accounts",
  Balances = "balances",
  Transactions = "transactions",
  Transfer = "transfer",
}

---Multi-phase tracking values for `session.phase` during `RefreshAccount`.
---@enum YAXI.MoneyMoney.Session.Phase
M.Phase = {
  Balances = "balances",
  Transactions = "transactions",
}

---Verification of Payee (VoP) mode.
---@enum YAXI.MoneyMoney.VopMode
M.VopMode = {
  Embedded = "embedded",
  Decoupled = "decoupled",
  None = "none",
}

---Keys used in MoneyMoney's `LocalStorage` by the extension.
---@enum YAXI.MoneyMoney.StorageKey
M.StorageKey = {
  Accounts = "yaxi-accounts",
  AccountsData = "yaxi-accounts-data",
  TanMethods = "yaxi-tan-methods",
  Usage = "yaxi-usage",
  LastRefresh = "yaxi-last-refresh",
}

return M
