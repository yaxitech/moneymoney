-- SPDX-License-Identifier: MIT
-- Unit tests for yaxi.mm.http (MMHttpClient).

dofile("tests/mm_env.lua")

local assert = require("luassert")

local http = require("routex-client.http")
local MMHttpClient = require("yaxi.mm.http").MMHttpClient

context("yaxi.mm.http", function()
  local origConnection = _G.Connection
  local captured = {}

  setup(function()
    -- busted insulates plain global writes per spec file; the module under
    -- test resolves `Connection` from the real global table
    rawset(_G, "Connection", function()
      local conn = {}
      conn.request = function(_self, method, _url, _postContent, _postContentType, headers)
        captured.method = method
        captured.headers = headers
        return "", "UTF-8", "application/json", "", {}
      end
      return conn
    end)
  end)

  teardown(function()
    rawset(_G, "Connection", origConnection)
  end)

  test("sends a capitalized Accept header on every request", function()
    local client = MMHttpClient:new(0.4)

    -- GET without any accept header
    client:request(http.Request:builder("https://api.example.com/info"):method("GET"):build())
    assert.are_equal("application/json", captured.headers.Accept)
    assert.is_nil(captured.headers.accept)

    -- Lowercase `accept` as set by the routex client
    local request = http.Request
      :builder("https://api.example.com/accounts")
      :method("POST")
      :header("accept", "application/vnd.yaxi.v5")
      :build()
    client:request(request)
    assert.are_equal("application/vnd.yaxi.v5, application/json", captured.headers.Accept)
    assert.is_nil(captured.headers.accept)
  end)
end)
