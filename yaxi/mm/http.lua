-- SPDX-License-Identifier: MIT
-- Author: Vincent Haupert <vincent.haupert@yaxi.tech>

local http = require("routex-client.http")
local rc = require("routex-client")
local RoutexClient = rc.RoutexClient

--region MMHttpClient

---@class MMHttpClient: YAXI.Http.IClient
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
  local userAgent = ("RoutexClientMoneyMoney/%s (Lua)"):format(self.version)
  local connection = Connection(nil, nil, userAgent)

  if request.headers and request.headers["content-type"] == "application/json" then
    -- MoneyMoney's `Connection()` handler requires `Accept` (capital `A`) to include
    -- `application/json` when `content-type` is `application/json`, otherwise it aborts
    -- script execution and escapes to the frontend without giving us a chance to handle
    -- errors. Since HTTP header names are case-insensitive per RFC 7230, we merge the
    -- lowercase `accept` into the capitalized `Accept` and include `application/json`.
    local parts = {}
    ---@diagnostic disable-next-line: unnecessary-if
    if request.headers.accept then
      parts[#parts + 1] = request.headers.accept
    end
    ---@diagnostic disable-next-line: unnecessary-if
    if request.headers.Accept then
      parts[#parts + 1] = request.headers.Accept
    end
    local accept = table.concat(parts, ", ")
    if accept and not accept:find("application/json") then
      request.headers.Accept = string.format("%s, %s", accept, "application/json")
      request.headers.accept = nil
    end
  end

  local content, _charset, _mime_type, _filename, headers = connection:request(
    request.method,
    request.url,
    request.data or "",
    request.headers and request.headers["content-type"] or "",
    request.headers or {}
  )

  -- MoneyMoney's `Connection():request()` does not expose the HTTP status code.
  -- The actual YAXI response body is encrypted at this layer, so we can only detect
  -- errors that MoneyMoney itself surfaces when there is no response body (e.g.
  -- `{"error": <number>, "error_description": "..."}`).
  local status = 200
  local ok, parsed = pcall(JSON, content)
  if ok and parsed then
    local dict = (parsed --[[@as MM.JSON]]):dictionary()
    if type(dict["error"]) == "number" and dict["error_description"] then
      status = dict["error"] --[[@as integer]]
    end
  end

  return http.Response:new(status, headers, content)
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

return {
  MMHttpClient = MMHttpClient,
}
