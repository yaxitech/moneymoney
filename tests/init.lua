-- SPDX-License-Identifier: MIT
-- Author: Vincent Haupert <vincent.haupert@yaxi.tech>

-- Default busted helper: shared setup + extension loaded from source.

dofile("tests/mm_env.lua")

local extension = require("yaxi.extension")
extension.setup({
  apiKeyId = requireEnv("YAXI_API_KEY_ID"),
  apiKeySecret = requireEnv("YAXI_API_KEY_SECRET"),
})

-- Minimize API requests to stay within rate limits (150 req/60s):
-- reuse one RoutexClient (single key settlement) and cache info() per connection.
do
  local rc = require("routex-client")
  local RoutexClient = rc.RoutexClient
  local MMHttpClient = require("yaxi.mm.http").MMHttpClient
  local manifest = require("yaxi.manifest")

  local sharedClient = RoutexClient:new("https://api.yaxi.tech", MMHttpClient:new(manifest.version))
  sharedClient:setRedirectUri("https://service.moneymoney-app.com/1/redirect")

  RoutexClient.new = function()
    return sharedClient
  end

  local origInfo = RoutexClient.info
  ---@type table<string, any>
  local infoCache = {}
  RoutexClient.info = function(self, opts) ---@diagnostic disable-line: redundant-parameter
    local cached = infoCache[opts.connectionId]
    if cached then ---@diagnostic disable-line: unnecessary-if
      return cached
    end
    local result = origInfo(self, opts)
    infoCache[opts.connectionId] = result
    return result
  end
end
