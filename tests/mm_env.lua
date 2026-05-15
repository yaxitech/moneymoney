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
-- definitions) but are integers at runtime. We omit @type annotations here to
-- avoid assign-type-mismatch warnings.

AccountTypeGiro = 1
AccountTypeSavings = 2
AccountTypeFixedTermDeposit = 3
AccountTypeLoan = 4
AccountTypeCreditCard = 5
AccountTypePortfolio = 6
AccountTypeInsuranceContracts = 7
AccountTypeOther = 8

PaymentTypeTransfer = 1
PaymentTypeInstantTransfer = 10
PaymentTypeScheduledTransfer = 2

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
  localizeText = function(s)
    return s
  end,
  printStatus = function() end,
  printDebug = function(...)
    io.stderr:write(tostring(...) .. "\n")
  end,
  ---@param s string
  ---@param _charset? string
  ---@return string
  urlencode = function(s, _charset)
    return (s:gsub("[^%w%-_.~]", function(c)
      return string.format("%%%02X", string.byte(c))
    end))
  end,
  ---@param data string
  ---@return string hex Lowercase hex digest
  sha256 = function(data)
    local sha2 = require("routex-client.vendor.tls13.crypto.hash.sha2")
    local ctx = sha2.sha256() ---@diagnostic disable-line: call-non-callable
    ctx:update(data)
    local raw = ctx:finish()
    return (raw:gsub(".", function(c)
      return string.format("%02x", string.byte(c))
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

---@param code string
---@return MM.TransactionCodeResult
TransactionCode = function(code)
  return { name = code }
end

---@param code string
---@return MM.PurposeCodeResult
PurposeCode = function(code)
  return { name = code }
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

      return body, "UTF-8", "application/json", "", respHeaders
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
