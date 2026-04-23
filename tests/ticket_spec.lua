-- SPDX-License-Identifier: MIT

-- Unit tests for yaxi.ticket module.

dofile("tests/mm_env.lua")

local ticketMod = require("yaxi.ticket")
local Generator = ticketMod.Generator
local getId = ticketMod.getId
local assert = require("luassert")
local base64 = require("routex-client.util.base64")
local json = require("routex-client.vendor.json")

local TEST_KEY_ID = "api-key-test-1234"
local FAKE_TEST_KEY_SECRET = "YAXI" -- valid Base64

--- Decode a Base64URL string (JWT segment) into a Lua table.
---@param s string
---@return table
local function decodeSegment(s)
  -- JWT uses URL-safe Base64; restore standard padding for decode
  local padded = s:gsub("-", "+"):gsub("_", "/")
  local rem = #padded % 4
  if rem > 0 then
    padded = padded .. string.rep("=", 4 - rem)
  end
  return json.decode(base64.decode(padded))
end

--- Split a JWT into its three raw segments.
---@param jwt string
---@return string header, string payload, string signature
local function splitJwt(jwt)
  local parts = {}
  for part in jwt:gmatch("[^.]+") do
    parts[#parts + 1] = part
  end
  return parts[1], parts[2], parts[3]
end

context("yaxi.ticket", function()
  local gen ---@type any
  local ticketId ---@type string

  before_each(function()
    gen = Generator:new(TEST_KEY_ID, FAKE_TEST_KEY_SECRET)
    ticketId = MM.uuid()
  end)

  context("Generator:new", function()
    test("succeeds with a valid Base64 secret", function()
      local g = Generator:new(TEST_KEY_ID, FAKE_TEST_KEY_SECRET)
      assert.is_not_nil(g)
    end)

    test("errors with an invalid Base64 secret", function()
      assert.has_error(function()
        Generator:new(TEST_KEY_ID, "!!!not-base64!!!")
      end)
    end)
  end)

  context("Generator:issue", function()
    test("has correct header fields (kid, alg, typ)", function()
      local tok = gen:issue(ticketId, "Accounts")
      local headerSeg = splitJwt(tok)
      local header = decodeSegment(headerSeg)

      assert.are_equal(TEST_KEY_ID, header.kid)
      assert.are_equal("HS256", header.alg)
      assert.are_equal("JWT", header.typ)
    end)

    -- 5
    test("has correct payload with ticketId, service, and exp", function()
      local exp = os.time() + 600
      local tok = gen:issue(ticketId, "Accounts", nil, exp)
      local _, payloadSeg = splitJwt(tok)
      local payload = decodeSegment(payloadSeg)

      assert.are_equal(exp, payload.exp)
      assert.are_equal(ticketId, payload.data.id)
      assert.are_equal("Accounts", payload.data.service)
    end)

    test("encodes nil data as JSON null (via '__NULL__' placeholder)", function()
      local tok = gen:issue(ticketId, "Accounts")
      local _, payloadSeg = splitJwt(tok)
      local payload = decodeSegment(payloadSeg)

      -- The generator substitutes "__NULL__" which jwt.encode turns into JSON null.
      -- After decoding, null becomes Lua nil.
      assert.is_nil(payload.data.data)
    end)

    test("includes explicit data in payload", function()
      local data = { account = { iban = "DE89370400440532013000" }, range = { from = "2025-01-01" } }
      local tok = gen:issue(ticketId, "Transactions", data)
      local _, payloadSeg = splitJwt(tok)
      local payload = decodeSegment(payloadSeg)

      assert.are_same(data, payload.data.data)
    end)

    test("errors when ticketId is not 36 characters", function()
      assert.has_error(function()
        gen:issue("short-id", "Accounts")
      end, "Invalid ticket ID: expected 36 bytes UUID")
    end)
  end)

  context("getId", function()
    test("returns the correct ticketId from a generated ticket", function()
      local tok = gen:issue(ticketId, "Accounts")
      local extractedId = getId(tok)

      assert.are_equal(ticketId, extractedId)
    end)

    test("errors on a malformed JWT without data.id", function()
      -- Build a minimal JWT with no data.id claim (header.payload.signature)
      local header = base64.encodeUrlsafe(json.encode({ alg = "none", typ = "JWT" }))
      local payload = base64.encodeUrlsafe(json.encode({ exp = os.time() + 300 }))
      local fakeJwt = header .. "." .. payload .. "."

      assert.has_error(function()
        getId(fakeJwt)
      end)
    end)
  end)
end)
