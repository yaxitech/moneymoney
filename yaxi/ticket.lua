-- SPDX-License-Identifier: MIT
-- Author: Vincent Haupert <vincent.haupert@yaxi.tech>

local base64 = require("routex-client.util.base64")
local jwt = require("routex-client.jwt")

---@class YAXI.MoneyMoney.Ticket.Header
---@field typ "JWT"
---@field alg "HS256"
---@field kid string

---@class YAXI.MoneyMoney.Ticket.Payload
---@field data { id: string, service: string, data: table<string, any>? }
---@field exp integer Ticket validity date as a POSIX timestamp

---@class YAXI.MoneyMoney.Ticket.Generator
---@field private _apiKeyId string YAXI API key ID
---@field private _apiKeySecret string Raw (decoded) API key secret
local Generator = {}
Generator.__index = Generator

---Create a new `Generator` instance.
---@param apiKeyId string YAXI API key ID
---@param apiKeySecret string Base64-encoded API key secret
---@return YAXI.MoneyMoney.Ticket.Generator
function Generator:new(apiKeyId, apiKeySecret)
  ---@type YAXI.MoneyMoney.Ticket.Generator
  local obj = setmetatable({}, self)

  obj._apiKeyId = apiKeyId
  obj._apiKeySecret = base64.decode(apiKeySecret) or error("Failed to Base64-decode the API key secret")

  return obj
end

---Issue a new YAXI service ticket (JWT signed with the API key secret).
---@param ticketId string UUIDv4 string representation
---@param service "Accounts"|"CollectPayment"|"Balances"|"Transactions"|"Transfer"|string YAXI service name
---@param data table? Additional data specific to `service`
---@param exp integer? Expiration as POSIX timestamp (default: now + 5 min)
---@return string Signed YAXI ticket JWT
function Generator:issue(ticketId, service, data, exp)
  if #ticketId ~= 36 then
    error("Invalid ticket ID: expected 36 bytes UUID")
  end

  local headers = {
    kid = self._apiKeyId,
  }

  local nullValue = "__NULL__"
  local payload = {
    exp = exp or os.time() + (5 * 60),
    data = {
      id = ticketId,
      service = service,
      data = data or nullValue,
    },
  }

  local ticket = jwt.encode(payload, self._apiKeySecret --[[@as binary]], "HS256", headers, nullValue)

  return ticket
end

--#region Issue Accounts ticket

---Issue a ticket for the `Accounts` service.
---@param ticketId string UUIDv4 string representation
---@param exp integer? Expiration as POSIX timestamp (default: now + 5 min)
---@return string Signed YAXI ticket JWT
function Generator:accounts(ticketId, exp)
  return self:issue(ticketId, "Accounts", nil, exp)
end

--#endregion Issue Accounts ticket

--#region Issue Balances ticket

---Issue a ticket for the `Balances` service.
---@param ticketId string UUIDv4 string representation
---@param exp integer? Expiration as POSIX timestamp (default: now + 5 min)
---@return string Signed YAXI ticket JWT
function Generator:balances(ticketId, exp)
  return self:issue(ticketId, "Balances", nil, exp)
end

--#endregion Issue Balances ticket

--#region Issue Transactions ticket

---@class YAXI.MoneyMoney.Ticket.Payload.Transactions
---@field account YAXI.MoneyMoney.Ticket.Payload.Transactions.Account Account to gather transactions for
---@field range YAXI.MoneyMoney.Ticket.Payload.Transactions.Range Date range to fetch
---@field webhook string? Webhook URL; if provided, the `Result` JWT is delivered to it instead of returned to the client

---@class YAXI.MoneyMoney.Ticket.Payload.Transactions.Range
---@field from string Start date in `YYYY-MM-DD` format
---@field to string? End date in `YYYY-MM-DD` format

---@class YAXI.MoneyMoney.Ticket.Payload.Transactions.Account
---@field iban string IBAN
---@field currency string? ISO 4217 Alpha 3 currency code; should always be provided if known (needed to identify sub-accounts)

---Issue a ticket for the `Transactions` service.
---@param ticketId string UUIDv4 string representation
---@param data YAXI.MoneyMoney.Ticket.Payload.Transactions
---@param exp integer? Expiration as POSIX timestamp (default: now + 5 min)
---@return string Signed YAXI ticket JWT
function Generator:transactions(ticketId, data, exp)
  return self:issue(ticketId, "Transactions", data, exp)
end

--#endregion Issue Transactions ticket

--#region Issue CollectPayment ticket

--- Restrictions on remittance and creditor name:
--- - Some banks require a minimum remittance of a few characters.
--- - Long texts may be truncated, typically with a limit of 140 characters for remittance and 70 for the creditor name.
--- - Providers accept different character sets for the creditor name and remittance. The safe baseline is:
---   ```
---   abcdefghijklmnopqrstuvwxyz
---   ABCDEFGHIJKLMNOPQRSTUVWXYZ
---   0123456789
---   /-?:().,' +
---   Space
---   ```
---   Other characters may be accepted, rejected, stripped or replaced.
---@class YAXI.MoneyMoney.Ticket.Payload.CollectPayment
---@field amount YAXI.MoneyMoney.Ticket.Payload.CollectPayment.Amount
---@field creditorAccount YAXI.MoneyMoney.Ticket.Payload.CollectPayment.CreditorAccount
---@field creditorName string Mind the character set restrictions
---@field remittance string Mind the character set restrictions
---@field instant boolean? `true` forces instant, `false` forces non-instant, `nil` prefers instant with fallback
---@field fields YAXI.MoneyMoney.Ticket.Payload.CollectPayment.Field[]? Additional fields to include in the `Result`

---@class YAXI.MoneyMoney.Ticket.Payload.CollectPayment.Amount
---@field amount number|string Numeric amount (floating point or string to avoid precision errors)
---@field currency string ISO 4217 Alpha 3 currency code

---@class YAXI.MoneyMoney.Ticket.Payload.CollectPayment.CreditorAccount
---@field iban string IBAN

---@alias YAXI.MoneyMoney.Ticket.Payload.CollectPayment.Field
---| "debtorIban"
---| "debtorName"

---Issue a ticket for the `CollectPayment` service.
---@param ticketId string UUIDv4 string representation
---@param data YAXI.MoneyMoney.Ticket.Payload.CollectPayment
---@param exp integer? Expiration as POSIX timestamp (default: now + 5 min)
---@return string Signed YAXI ticket JWT
function Generator:collectPayment(ticketId, data, exp)
  return self:issue(ticketId, "CollectPayment", data, exp)
end

--#endregion Issue CollectPayment ticket

--#region Issue Transfer ticket

---Issue a ticket for the `Transfer` service.
---Unlike `CollectPayment`, `Transfer` tickets carry no embedded payment data —
---payment details are sent directly in the service call.
---@param ticketId string UUIDv4 string representation
---@param exp integer? Expiration as POSIX timestamp (default: now + 5 min)
---@return string Signed YAXI ticket JWT
function Generator:transfer(ticketId, exp)
  return self:issue(ticketId, "Transfer", nil, exp)
end

--#endregion Issue Transfer ticket

---Get the `data.id` claim from a ticket JWT without verifying the signature.
---@param ticket string A YAXI service ticket
---@return string
local function getId(ticket)
  local claims = jwt.decode(ticket, nil, nil, {
    verifySignature = false,
    verifyExp = false,
  })
  return claims and claims.data and claims.data.id or error("The ticket doesn't have a `data.id` claim")
end

---@class YAXI.MoneyMoney.Ticket
---@field Generator YAXI.MoneyMoney.Ticket.Generator
---@field getId fun(ticket: string): string
return {
  Generator = Generator,
  getId = getId,
}
