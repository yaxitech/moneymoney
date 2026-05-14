-- SPDX-License-Identifier: MIT
-- Author: Vincent Haupert <vincent.haupert@yaxi.tech>

-- YAXI `Connection` — Base class and registry.
--
-- Adding a bank: create a config file returning a `YAXI.MoneyMoney.Connection.Config`
-- table and add one `require` to the BANKS list at the bottom of this file.
-- See the existing bank files (e.g. `demo.lua`, `dkb.lua`) for examples and
-- `YAXI.MoneyMoney.Connection.Config` for the full type definition.
--
-- Methods using `_self` (dot-call) ignore self in their default implementation
-- but may be overridden by config callbacks that do use it (e.g. `mapAccount`).

local log = (require("routex-client.logging") --[[@as lualogging]]).defaultLogger()
local rc = require("routex-client")
local PaymentProduct = rc.PaymentProduct

local enum = require("yaxi.enum")
local StorageKey = enum.StorageKey
local VopMode = enum.VopMode

---@class YAXI.MoneyMoney.Connection.Config
---@field id string YAXI connection UUID
---@field service string MoneyMoney service name (e.g. `"YAXI DKB"`)
---@field bic string?
---@field url string?
---@field since integer? Earliest transaction date as POSIX timestamp
---@field paymentTypes MM.PaymentTypeConst[]?
---@field tanMethods MM.TanMethod[]? Static TAN methods for `GetTanMethods`
---@field transactionCodePreference string[]? Preferred `bankTransactionCode` type (e.g. `"other"`, `"iso"`)
---@field appToApp string? If set, `Redirect` challenges show a QR code instead of the in-app WebView, allowing the user to scan and open in their banking app
---@field vop YAXI.MoneyMoney.VopMode? VoP mode. Default: `VopMode.None`.
---@field mapChallenge (fun(self: YAXI.MoneyMoney.Connection, challenge: MM.SessionChallenge, obResponse: YAXI.RoutexClient.OBResponse): MM.SessionChallenge)? Override to customize challenge display
---@field mapAccount (fun(self: YAXI.MoneyMoney.Connection, yaxiAccount: YAXI.RoutexClient.Result.Account): MM.Account)? Override to customize account mapping

---@class YAXI.MoneyMoney.Connection : YAXI.MoneyMoney.Connection.Config
---@field paymentTypes MM.PaymentTypeConst[]
---@field tanMethods MM.TanMethod[]
local Connection = {}
Connection.__index = Connection

---@type table<string, YAXI.MoneyMoney.Connection>
Connection.registry = {}

---Create a new `Connection` instance.
---@param config YAXI.MoneyMoney.Connection.Config
---@return YAXI.MoneyMoney.Connection
function Connection:new(config)
  ---@type YAXI.MoneyMoney.Connection
  local obj = setmetatable({}, self)
  obj.id = config.id or error("Connection requires an `id`")
  obj.service = config.service or error("Connection requires a `service`")
  obj.bic = config.bic
  obj.url = config.url
  obj.since = config.since
  obj.paymentTypes = config.paymentTypes or {}
  obj.tanMethods = config.tanMethods or {}
  obj.transactionCodePreference = config.transactionCodePreference
  obj.appToApp = config.appToApp
  obj.vop = config.vop or VopMode.None
  -- Instance callbacks shadow class methods when provided
  obj.mapChallenge = config.mapChallenge
  obj.mapAccount = config.mapAccount
  return obj
end

---Map YAXI `Selection` dialog options to `MM.TanMethod`s.
---@param options YAXI.RoutexClient.Dialog.Input.Selection.Option[]
---@return MM.TanMethod[]
function Connection.mapTanMethods(_self, options)
  ---@type MM.TanMethod[]
  local methods = {}
  for _, opt in ipairs(options) do
    ---@type MM.TanMethod
    local method = {
      name = opt.label,
      webMethod = opt.key,
      mediumName = opt.explanation,
    }
    table.insert(methods, method)
  end
  return methods
end

---Post-process an `MM.SessionChallenge` before returning to MoneyMoney.
---Called after default mapping (including `mapTanMethods`). Mutate or replace
---the challenge as needed (e.g. rename TAN methods, assign `hbciMethod`).
---Must return the challenge. Override via the `mapChallenge` config callback.
---@param challenge MM.SessionChallenge
---@param _obResponse YAXI.RoutexClient.OBResponse
---@return MM.SessionChallenge
function Connection.mapChallenge(_self, challenge, _obResponse)
  return challenge
end

---Map a YAXI account to an `MM.Account`.
---Connections can override this via the `mapAccount` config callback.
---@param yaxiAccount YAXI.RoutexClient.Result.Account
---@return MM.Account
function Connection:mapAccount(yaxiAccount)
  local accountMapping = require("yaxi.mapping.account")
  return accountMapping.mapAccount(yaxiAccount, self)
end

---Map a YAXI transaction to an `MM.Transaction`.
---Returns `nil` if the transaction cannot be mapped.
---@param tx YAXI.RoutexClient.Result.Transaction
---@return MM.Transaction?
function Connection:mapTransaction(tx)
  local transactionMapping = require("yaxi.mapping.transaction")
  return transactionMapping.mapTransaction(tx, self)
end

---Auto-select a TAN method from a `Selection` dialog during payment flow.
---Matches by `hbciMethod` against the mapped methods.
---@param mmTanMethods MM.TanMethod[]
---@param selectedMethod MM.TanMethod?
---@return MM.TanMethod?
function Connection.autoSelectTanMethod(_self, mmTanMethods, selectedMethod)
  if not selectedMethod or not selectedMethod.hbciMethod then
    return nil
  end
  for _, candidate in ipairs(mmTanMethods) do
    if candidate.hbciMethod == selectedMethod.hbciMethod then
      return candidate
    end
  end
  return nil
end

---Map `MM.PaymentTypeConst` to `YAXI.RoutexClient.PaymentProduct`.
---@param mmPaymentType MM.PaymentTypeConst
---@return YAXI.RoutexClient.PaymentProduct
function Connection.paymentProduct(_self, mmPaymentType)
  if mmPaymentType == PaymentTypeInstantTransfer then
    return PaymentProduct.SepaInstantCreditTransfer
  end
  -- `PaymentTypeTransfer` and `PaymentTypeScheduledTransfer` both use `SepaCreditTransfer`
  return PaymentProduct.SepaCreditTransfer
end

---Check whether an `MM.SessionChallenge` represents a TAN method selection
---by matching its `tanMethods` against this connection's static TAN method list.
---Matching is done by `hbciMethod` first, then by partial case-insensitive name match.
---@param challenge MM.SessionChallenge
---@return boolean isTanSelection
---@return string[] matchedHbciMethods hbciMethod codes of matched methods
function Connection:detectTanMethodSelection(challenge)
  if not challenge.tanMethods or #challenge.tanMethods == 0 then
    return false, {}
  end

  ---@type table<string, boolean>
  local staticByHbci = {}
  ---@type string[]
  local staticNames = {}
  for _, m in ipairs(self.tanMethods) do
    if m.hbciMethod then
      staticByHbci[m.hbciMethod] = true
    end
    table.insert(staticNames, m.name:lower())
  end

  ---@type string[]
  local matched = {}
  local matchCount = 0
  for _, m in ipairs(challenge.tanMethods) do
    local hit = false
    -- Match by hbciMethod
    if m.hbciMethod and staticByHbci[m.hbciMethod] then
      hit = true
    end
    -- Fallback: partial case-insensitive name match
    if not hit and m.name then
      local nameLower = m.name:lower()
      for _, sn in ipairs(staticNames) do
        if nameLower:find(sn, 1, true) or sn:find(nameLower, 1, true) then
          hit = true
          break
        end
      end
    end
    if hit then
      matchCount = matchCount + 1
      if m.hbciMethod then
        table.insert(matched, m.hbciMethod)
      end
    end
  end

  local isTanSelection = matchCount > 0
  if isTanSelection then
    log:debug("Detected TAN method selection: %d/%d matched", matchCount, #challenge.tanMethods)
  end
  return isTanSelection, matched
end

---Persist discovered TAN method `hbciMethod` codes to `LocalStorage`.
---@param hbciMethods string[]
function Connection:storeDiscoveredTanMethods(hbciMethods)
  ---@type table<string, string[]>
  local stored = LocalStorage[StorageKey.TanMethods] --[[@as table<string, string[]>?]] or {}
  stored[self.id] = hbciMethods
  LocalStorage[StorageKey.TanMethods] = stored --[[@as any]]
  log:debug("Stored %d discovered TAN methods for %s", #hbciMethods, self.service)
end

---Return the effective TAN methods for this connection, merging the static list
---with previously discovered user-specific methods. Methods not seen in a prior
---`Selection` dialog receive an `errorMessage` to signal they are not set up.
---@return MM.TanMethod[]
function Connection:getEffectiveTanMethods()
  ---@type table<string, string[]>
  local stored = LocalStorage[StorageKey.TanMethods] --[[@as table<string, string[]>?]] or {}
  local discovered = stored[self.id]

  -- No discovery yet — return static list as-is
  if not discovered then
    return self.tanMethods
  end

  ---@type table<string, boolean>
  local discoveredSet = {}
  for _, code in ipairs(discovered) do
    discoveredSet[code] = true
  end

  ---@type MM.TanMethod[]
  local methods = {}
  for _, m in ipairs(self.tanMethods) do
    local entry = {} ---@type MM.TanMethod ---@diagnostic disable-line: missing-fields
    for k, v in pairs(m) do
      entry[k] = v
    end
    if m.hbciMethod and not discoveredSet[m.hbciMethod] then
      entry.errorMessage =
        string.format(MM.localizeText("Please first activate the %s method on the website of your bank."), m.name)
    end
    table.insert(methods, entry)
  end
  return methods
end

-- Bank connection configs. Each `require` returns a config table.
-- Explicit `require()` calls are needed for the luabundle bundler to discover modules.
-- Adding a bank = creating a config file + adding one `require` here.
---@type YAXI.MoneyMoney.Connection.Config[]
local BANKS = {
  -- require("yaxi.connections.1822direkt"),
  require("yaxi.connections.c24"),
  require("yaxi.connections.comdirect"),
  require("yaxi.connections.demo"),
  require("yaxi.connections.deutsche_bank"),
  require("yaxi.connections.dkb"),
  require("yaxi.connections.gls"),
  require("yaxi.connections.ing"),
  -- require("yaxi.connections.kontist"),
  require("yaxi.connections.postbank"),
  require("yaxi.connections.n26"),
}

-- Registry population
for _, config in ipairs(BANKS) do
  local ok, err = pcall(function()
    local conn = Connection:new(config)
    Connection.registry[conn.service] = conn
  end)
  if not ok then
    log:warn("Failed to register connection '%s': %s", config.service or "unknown", err)
  end
end

return Connection
