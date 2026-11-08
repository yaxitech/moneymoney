-- SPDX-License-Identifier: MIT
-- Author: Vincent Haupert <vincent.haupert@yaxi.tech>

-- MoneyMoney runtime environment mock for busted tests.
--
-- Provides: package.path, MM constants, MM namespace, Connection (lua-http),
-- JSON, TransactionCode, PurposeCode, WebBanking, LocalStorage, requireEnv.
--
-- Type annotations reference the LuaCATS definitions in addons/moneymoney/library/mm.lua.

-- Package path: project root + yaxi modules + routex-client submodule.
-- Busted runs from the project root, so relative paths work.
package.path = table.concat({
  "?.lua",
  "?/init.lua",
  "yaxi/?.lua",
  "yaxi/?/init.lua",
  "yaxi/routex-client-lua/?.lua",
  "yaxi/routex-client-lua/?/init.lua",
  package.path,
}, ";")

--region Constants

-- MM constants are opaque at the type level (aliased to `string` in the LuaCATS
-- definitions) and hold MoneyMoney's display names at runtime. We omit @type
-- annotations here to avoid assign-type-mismatch warnings.

AccountTypeGiro = "Giro account"
AccountTypeSavings = "Savings account"
AccountTypeFixedTermDeposit = "Fixed term deposit"
AccountTypeLoan = "Loan account"
AccountTypeCreditCard = "Credit card"
AccountTypePortfolio = "Portfolio"
AccountTypeInsuranceContracts = "Insurance contracts"
AccountTypeOther = "Unknown"

PaymentTypeTransfer = "Transfer"
PaymentTypeInstantTransfer = "Instant transfer"
PaymentTypeScheduledTransfer = "Scheduled transfer"
PaymentTypeStandingOrder = "Standing order"

ProtocolWebBanking = "Web Banking"

LoginFailed = "LoginFailed"

--endregion Constants

--region MM namespace

---@class MM
MM = {
  uuid = function()
    -- RFC 4122 v4 UUID
    local bytes = {}
    for i = 1, 16 do
      bytes[i] = math.random(0, 255)
    end
    bytes[7] = (bytes[7] & 0x0F) | 0x40 -- version 4
    bytes[9] = (bytes[9] & 0x3F) | 0x80 -- variant 1
    return string.format(
      "%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x",
      bytes[1],
      bytes[2],
      bytes[3],
      bytes[4],
      bytes[5],
      bytes[6],
      bytes[7],
      bytes[8],
      bytes[9],
      bytes[10],
      bytes[11],
      bytes[12],
      bytes[13],
      bytes[14],
      bytes[15],
      bytes[16]
    )
  end,
  language = "en",
  localizeText = function(s)
    return s
  end,
  ---Ignores the format and currency; always two decimals.
  ---@param _format string
  ---@param amount number|string
  ---@param _currency string?
  ---@return string
  localizeAmount = function(_format, amount, _currency)
    return string.format("%.2f", tonumber(amount))
  end,
  ---Ignores the format; up to six decimals.
  ---@param _format string
  ---@param num number
  ---@return string
  localizeNumber = function(_format, num)
    return (string.format("%.6f", num):gsub("0+$", ""):gsub("%.$", ""))
  end,
  printStatus = function() end,
  ---@param _seconds number
  sleep = function(_seconds) end,
  printDebug = function(...)
    -- Like `print`: all values via `tostring`, tab-separated
    local parts = {}
    for i = 1, select("#", ...) do
      parts[i] = tostring(select(i, ...))
    end
    io.stderr:write(table.concat(parts, "\t") .. "\n")
  end,
  ---Implements the `"UTF-8"` behavior; the charset parameter is ignored.
  ---@param s string
  ---@param _charset? string
  ---@return string
  urlencode = function(s, _charset)
    return (s:gsub("[^%w%-_.~]", function(c)
      return string.format("%%%02X", string.byte(c))
    end))
  end,
  ---@param data string
  ---@return string hex
  binToHex = function(data)
    return (data:gsub(".", function(c)
      return string.format("%02X", string.byte(c))
    end))
  end,
  ---@param data string
  ---@return string hex Uppercase hex digest, matching the real MoneyMoney
  sha256 = function(data)
    local sha2 = require("routex-client.vendor.tls13.crypto.hash.sha2")
    local ctx = sha2.sha256() ---@diagnostic disable-line: call-non-callable
    ctx:update(data)
    local raw = ctx:finish()
    return (raw:gsub(".", function(c)
      return string.format("%02X", string.byte(c))
    end))
  end,
}

--endregion MM namespace

--region Global constructor functions

---@param json? string
---@return MM.JSON
JSON = function(json)
  local vendorJson = require("routex-client.vendor.json")

  ---@class MM.JSON
  local obj = {}
  if json and #json > 0 then
    obj._data = vendorJson.decode(json)
  end

  function obj:set(value)
    self._data = value
    return self
  end

  function obj:json()
    return vendorJson.encode(self._data or {})
  end

  function obj:dictionary()
    return self._data or {}
  end

  return obj
end

-- Excerpts of the code tables behind `TransactionCode` and `PurposeCode`
local ISO_CODES = {
  CCRD = "customer card transactions",
  ESCT = "SEPA credit transfer",
  ICDT = "issued credit transfers",
  IRCT = "issued real-time credit transfers",
  OTHR = "other",
  PMNT = "payments",
  POSD = "point-of-sale payment debit card",
  RCDT = "received credit transfers",
  STDO = "standing order",
}
local SWIFT_CODES = { DDT = "Direct debit", MSC = "Miscellaneous", STO = "Standing order", TRF = "Transfer" }
local GVC_CODES = {
  [105] = "Lastschrift",
  [106] = "Abwicklung von Kartenzahlungen",
  [117] = "Dauerauftrag",
  [153] = "Lohn/Gehalt/Rente",
  [166] = "Überweisung",
}
local PURPOSE_CODES = {
  CDDP = "card deferred payment",
  DCRD = "debit card payment",
  OTHR = "other",
  RINP = "rent",
  SALA = "salary payment",
}

---Resolves only these formats; anything else yields an empty name:
---`"SUBF"`, `"FAMI-SUBF"`, and `"DOMN-FAMI-SUBF"` (ISO, most specific level first),
---`"NDDT"` (SWIFT), and `"NDDT+105"` (GVC, then SWIFT).
---@param code string
---@return MM.TransactionCodeResult
TransactionCode = function(code)
  local n, at = #code, function(i)
    return code:sub(i, i)
  end
  local swiftPrefix = at(1) == "N" or at(1) == "F"
  local function gvcOrSwift()
    local gvc = code:sub(6, 8)
    return gvc:match("^%d%d%d$") and GVC_CODES[tonumber(gvc)] or SWIFT_CODES[code:sub(2, 4)]
  end

  local name
  if n == 14 and at(5) == "-" and at(10) == "-" then
    name = ISO_CODES[code:sub(11, 14)] or ISO_CODES[code:sub(6, 9)] or ISO_CODES[code:sub(1, 4)]
  elseif n >= 9 and swiftPrefix and at(5) == "+" and at(9) == "+" then
    name = gvcOrSwift()
  elseif n == 4 then
    name = ISO_CODES[code] or (swiftPrefix and SWIFT_CODES[code:sub(2, 4)] or nil)
  elseif n == 9 and at(5) == "-" then
    name = ISO_CODES[code:sub(6, 9)] or ISO_CODES[code:sub(1, 4)]
  elseif n == 8 and swiftPrefix and at(5) == "+" then
    name = gvcOrSwift()
  end
  return { name = name or "" }
end

---@param code string
---@return MM.PurposeCodeResult
PurposeCode = function(code)
  return { name = #code == 4 and PURPOSE_CODES[code] or "" }
end

---@param _params MM.WebBankingParams
WebBanking = function(_params) end

---@param _bankCode string
---@return MM.BankInfoResult?
BankInfo = function(_bankCode)
  return nil
end

--endregion Global constructor functions

--region Connection mock

-- Mock using lua-http for real HTTPS requests. Extension-level tests
-- (extension_e2e_spec) exercise the full stack through MMHttpClient which
-- calls this global.
do
  local ok, httpRequest = pcall(require, "http.request")
  if not ok then
    -- lua-http not available (unit tests); Connection mock requires it for E2E tests only
    goto skip_connection_mock
  end

  ---@param _wsUrl? string
  ---@param _protocols? string[]
  ---@param useragent? string
  ---@param language? string
  ---@return MM.Connection
  Connection = function(_wsUrl, _protocols, useragent, language)
    ---@class MM.Connection
    local conn = {}
    conn.useragent = useragent or ""
    conn.language = language or ""
    conn.redirects = true

    function conn:request(method, url, postContent, postContentType, headers)
      assert(httpRequest.new_from_uri, "http.request.new_from_uri not available")
      local req = httpRequest.new_from_uri(url)
      req.headers:upsert(":method", method)

      if self.useragent and #self.useragent > 0 then
        req.headers:upsert("user-agent", self.useragent)
      end

      for name, value in pairs(headers or {}) do
        -- HTTP/2 requires lowercase header names; MM passes mixed-case (e.g. "Accept")
        local lname = name:lower()
        if lname ~= "content-type" then
          req.headers:append(lname, value)
        end
      end

      if postContentType and #postContentType > 0 then
        req.headers:upsert("content-type", postContentType)
      end

      if postContent and #postContent > 0 then
        req:set_body(postContent)
      end

      local respHeaders, stream = req:go(10)
      if respHeaders == nil then
        error(string.format("HTTP request failed: %s", stream))
      end

      local body = stream:get_body_as_string()

      -- MoneyMoney returns a plain name-value table; drop HTTP/2 pseudo headers
      local responseHeaders = {}
      for name, value in respHeaders:each() do
        if not name:find("^:") then
          responseHeaders[name] = value
        end
      end

      return body, "UTF-8", "application/json", "", responseHeaders
    end

    return conn
  end

  ::skip_connection_mock::
end

--endregion Connection mock

--region LocalStorage

---In-memory stand-in for MoneyMoney's persistent LocalStorage.
LocalStorage = {}

--endregion LocalStorage

--region Redirect print to stderr

-- MoneyMoney's `print()` writes to the log window. In tests, redirect to stderr
-- so it doesn't pollute stdout (which busted's JUnit output uses).
local _realPrint = print
print = function(...)
  local args = { ... }
  for i = 1, select("#", ...) do
    args[i] = tostring(args[i])
  end
  io.stderr:write(table.concat(args, "\t") .. "\n")
end

--endregion Redirect print to stderr

--region Environment helpers

-- Create a temporary directory structure so that $TMPDIR/../Documents resolves
-- to a writable directory during tests (mirrors the MoneyMoney container layout).
do
  local base = os.tmpname()
  os.remove(base)
  os.execute(string.format("mkdir -p %q/tmp %q/Documents", base, base))

  ---Traces directory used by yaxi.traces (`$TMPDIR/../Documents`).
  YAXI_TEST_DOCUMENTS_DIR = base .. "/Documents"

  local realGetenv = os.getenv
  os.getenv = function(name)
    if name == "TMPDIR" then
      return base .. "/tmp"
    end
    return realGetenv(name)
  end
end

---Read a required environment variable or throw.
---@param name string
---@return string
function requireEnv(name)
  local value = os.getenv(name)
  if not value or value == "" then
    error(("Environment variable %s is required but not set"):format(name))
  end
  return value
end

--endregion Environment helpers
