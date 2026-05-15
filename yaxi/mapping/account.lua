-- SPDX-License-Identifier: MIT
-- Author: Vincent Haupert <vincent.haupert@yaxi.tech>

-- YAXI Account Mapper — YAXI account → `MM.Account`

local log = (require("routex-client.logging") --[[@as lualogging]]).defaultLogger()

local M = {}

---@type table<YAXI.RoutexClient.AccountType, MM.AccountTypeConst>
local typeMap = {
  Current = AccountTypeGiro,
  Card = AccountTypeCreditCard,
  Savings = AccountTypeSavings,
  CallMoney = AccountTypeSavings,
  TimeDeposit = AccountTypeFixedTermDeposit,
  Loan = AccountTypeLoan,
  Securities = AccountTypePortfolio,
  Insurance = AccountTypeInsuranceContracts,
  Commerce = AccountTypeOther,
  Rewards = AccountTypeOther,
}

---Derive supported payment types for a YAXI account from its capabilities.
---Returns the connection defaults when capabilities are absent or when
---`SinglePayment` is present; returns `nil` otherwise.
---@param yaxiAccount YAXI.RoutexClient.Result.Account?
---@param connection YAXI.MoneyMoney.Connection
---@return MM.PaymentTypeConst[]?
function M.derivePaymentTypes(yaxiAccount, connection)
  if not yaxiAccount then
    return nil
  end
  if not yaxiAccount.capabilities then
    return connection.paymentTypes
  end
  for _, cap in ipairs(yaxiAccount.capabilities) do
    if cap == "SinglePayment" then
      return connection.paymentTypes
    end
  end
  return nil
end

---Map a YAXI account to an `MM.Account`.
---@param yaxiAccount YAXI.RoutexClient.Result.Account
---@param connection YAXI.MoneyMoney.Connection
---@return MM.Account
function M.mapAccount(yaxiAccount, connection)
  ---@type MM.Account
  local account = {
    iban = yaxiAccount.iban,
    accountNumber = yaxiAccount.number,
    bic = yaxiAccount.bic or connection.bic,
    bankCode = yaxiAccount.bankCode,
    currency = yaxiAccount.currency,
    name = yaxiAccount.displayName or yaxiAccount.name or yaxiAccount.productName,
    owner = yaxiAccount.ownerName,
    comment = yaxiAccount.productName,
  }

  if yaxiAccount.type then
    account.type = typeMap[yaxiAccount.type]
    if not account.type then
      log:warn("Unknown YAXI account type: %s", yaxiAccount.type)
    end
  end

  if account.type == AccountTypePortfolio then
    account.portfolio = true
  end

  return account
end

return M
