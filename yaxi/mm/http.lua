-- SPDX-License-Identifier: MIT
-- Author: Vincent Haupert <vincent.haupert@yaxi.tech>

local http = require("routex-client.http")
local rc = require("routex-client")
local RoutexClient = rc.RoutexClient

--region MMHttpClient

---@class MMHttpClient: YAXI.Http.IClient
---@field private _connection MM.Connection?
local MMHttpClient = {}
MMHttpClient.__index = MMHttpClient
setmetatable(MMHttpClient, { __index = http.IHttpClient })

---@param version number
function MMHttpClient:new(version)
  local obj = setmetatable({}, self)
  obj.version = version
  return obj
end

function MMHttpClient:request(request)
  -- The `Connection` object owns the pooled HTTPS connection; reuse it to
  -- avoid a TLS handshake per request. The constructor arguments only apply
  -- to WebSocket connections, so set the user agent via the attribute.
  if not self._connection then
    self._connection = Connection()
    self._connection.useragent = ("RoutexClientMoneyMoney/%s (Lua)"):format(self.version)
  end
  local connection = self._connection

  -- MoneyMoney only returns HTTP error responses to the script when the
  -- request carries a recognized capitalized `Accept` header; otherwise an
  -- HTTP error aborts the whole session. Always send a single such header.
  local headers = request.headers or {}
  local parts = {}
  for _, key in ipairs({ "accept", "Accept" }) do
    if headers[key] and headers[key] ~= "" then
      parts[#parts + 1] = headers[key]
    end
    headers[key] = nil
  end
  local accept = table.concat(parts, ", ")
  if accept == "" then
    accept = "application/json"
  elseif not accept:find("application/json", 1, true) then
    accept = accept .. ", application/json"
  end
  headers.Accept = accept
  -- A `user-agent` header would override `connection.useragent`
  headers["user-agent"] = nil
  request.headers = headers

  local content, _charset, _mime_type, _filename, responseHeaders =
    connection:request(request.method, request.url, request.data or "", headers["content-type"] or "", headers)

  -- MoneyMoney's `Connection():request()` does not expose the HTTP status code.
  -- The actual YAXI response body is encrypted at this layer, so we can only detect
  -- errors that MoneyMoney itself surfaces when there is no response body (e.g.
  -- `{"error": <status>, "error_description": "..."}`).
  local status = 200
  local ok, dict = pcall(function()
    return JSON(content):dictionary()
  end)
  if ok and type(dict) == "table" and type(dict["error"]) == "number" and dict["error_description"] then
    local code = dict["error"] --[[@as integer]]
    if code >= 400 and code <= 599 then
      status = code
    end
  end

  return http.Response:new(status, responseHeaders, content)
end

--endregion MMHttpClient

--region Monkey-patch `RoutexClient._readOBResponse`

-- MoneyMoney's `Connection():request()` does not expose HTTP status codes, so all
-- responses arrive with `status = 200`. `RoutexClient._handleResponse` only maps
-- error JSON (e.g. `{"InvalidCredentials":[]}`) to typed errors when `status >= 400`,
-- causing them to fall through to `OBResponse.fromJSON` which doesn't recognize them.
--
-- This patch wraps `_readOBResponse` to check whether the decoded JSON contains a
-- valid `OBResponse` key. If not, it re-invokes `_handleResponse` with `status = 400`
-- so the original error mapping logic kicks in. This means every response body gets
-- decoded (and decrypted) twice — wasteful, but preferable to silently swallowing
-- errors like `InvalidCredentials` as unrecognized JSON.

-- Access private methods via raw table indexing to bypass type checker visibility rules.
-- This is intentional: we are monkey-patching `RoutexClient` internals.
local RC = RoutexClient --[[@as table]]

---@diagnostic disable-next-line: unnecessary-if
if not RC._readOBResponsePatched then
  local _originalReadOBResponse = RC._readOBResponse --[[@as function]]
  local _handleResponse = RC._handleResponse --[[@as function]]

  local jsonDecode = require("routex-client.vendor.json").decode
  local jsonEncode = require("routex-client.vendor.json").encode

  ---@param response YAXI.Http.Response
  ---@return YAXI.RoutexClient.OBResponse
  RC._readOBResponse = function(response)
    local ok, result = pcall(_originalReadOBResponse, response)
    if ok then
      return result --[[@as YAXI.RoutexClient.OBResponse]]
    end

    -- `OBResponse.fromJSON` didn't recognize the response — likely an error payload
    -- that slipped through because `status` was 200. Re-invoke with 400 to trigger
    -- the original error mapping (e.g. `InvalidCredentials` → `InvalidCredentialsError`).
    --
    -- The server may return a bare JSON string like `"UnsupportedProduct"` instead of
    -- the expected object form `{"UnsupportedProduct": {...}}`. Normalize it so that
    -- `_handleResponse`'s error mapping can match it.
    local decodeOk, body = pcall(jsonDecode, response.body)
    if decodeOk and type(body) == "string" then
      response.body = jsonEncode({ [body] = {} })
    end

    response.status = 400
    _handleResponse(response)

    -- `_handleResponse` didn't throw either — re-throw the original error
    error(result)
  end

  RC._readOBResponsePatched = true
end

--endregion Monkey-patch `RoutexClient._readOBResponse`

--region Monkey-patch `RoutexRefreshClient._readResponse`

-- Same status-code blindness as above, but worse for the refresh client: its
-- success shape is `{result?, session?, connectionData?}`, so an error body like
-- `{"InterruptError":{}}` arriving with `status = 200` doesn't fail parsing — it
-- silently becomes an empty response. Detect bodies without any success field
-- and re-invoke `_handleResponse` with `status = 400` to raise the typed error
-- (e.g. `InterruptError`, on which the extension falls back to the interactive
-- client).

local RRC = require("routex-client.refresh").RoutexRefreshClient --[[@as table]]

---@diagnostic disable-next-line: unnecessary-if
if not RRC._readResponsePatched then
  local _originalReadResponse = RRC._readResponse --[[@as function]]
  local _handleResponse = RRC._handleResponse --[[@as function]]

  local jsonDecode = require("routex-client.vendor.json").decode
  local jsonEncode = require("routex-client.vendor.json").encode

  ---@param response YAXI.Http.Response
  ---@return YAXI.RoutexRefreshClient.Response
  RRC._readResponse = function(response)
    local decodeOk, body = pcall(jsonDecode, response.body)
    if decodeOk then
      -- Normalize bare JSON string errors like `"UnsupportedProduct"` (see above)
      if type(body) == "string" then
        response.body = jsonEncode({ [body] = {} })
        body = { [body] = {} }
      end
      if
        type(body) == "table"
        and body.result == nil
        and body.session == nil
        and body.connectionData == nil
        and next(body) ~= nil
      then
        response.status = 400
        _handleResponse(response)

        -- `_handleResponse` didn't recognize the error variant
        error(rc.UnexpectedError:new(response.body))
      end
    end

    return _originalReadResponse(response)
  end

  RRC._readResponsePatched = true
end

--endregion Monkey-patch `RoutexRefreshClient._readResponse`

return {
  MMHttpClient = MMHttpClient,
}
