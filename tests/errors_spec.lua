-- SPDX-License-Identifier: MIT

-- Unit tests for yaxi.errors module.

dofile("tests/mm_env.lua")

local assert = require("luassert")
local errors = require("yaxi.errors")

local rc = require("routex-client")
local InvalidCredentialsError = rc.InvalidCredentialsError
local CanceledError = rc.CanceledError
local UnauthorizedError = rc.UnauthorizedError
local ConsentExpiredError = rc.ConsentExpiredError
local RCError = rc.Error

context("yaxi.errors", function()
  context("errorHandler", function()
    test("returns a plain string error unchanged", function()
      local result = errors.errorHandler(nil, "Something went wrong")
      assert.are_equal("Something went wrong", result)
    end)

    test("formats an untyped table error as JSON", function()
      local result = errors.errorHandler(nil, { code = 42 })
      assert.is_string(result)
      assert.is_truthy(result:find("42"))
    end)

    test("returns LoginFailed for InvalidCredentialsError", function()
      local err = setmetatable({}, InvalidCredentialsError)
      err.name = "InvalidCredentialsError"
      err.message = "Wrong password"
      local result = errors.errorHandler(nil, err)
      assert.are_equal(LoginFailed, result)
    end)

    test("returns message for CanceledError", function()
      local err = setmetatable({}, CanceledError)
      err.name = "CanceledError"
      err.message = "User canceled the operation"
      local result = errors.errorHandler(nil, err)
      assert.are_equal("User canceled the operation", result)
    end)

    test("prefers userMessage when available", function()
      local err = setmetatable({}, RCError)
      err.name = "SomeError"
      err.message = "internal error"
      err.userMessage = "Please try again later"
      local result = errors.errorHandler(nil, err)
      assert.are_equal("Please try again later", result)
    end)

    test("formats name:message for errors without userMessage", function()
      local err = setmetatable({}, RCError)
      err.name = "ServerError"
      err.message = "internal error"
      local result = errors.errorHandler(nil, err)
      assert.are_equal("ServerError: internal error", result)
    end)

    test("clears connectionData for UnauthorizedError", function()
      local conn = { id = "test-conn", service = "TestBank" }
      LocalStorage["test-conn"] = "stale-data" --[[@as any]]
      local session = { connection = conn, activeService = nil, activeTicket = nil }

      local err = setmetatable({}, UnauthorizedError)
      err.name = "UnauthorizedError"
      err.message = "Token expired"

      errors.errorHandler(session, err)
      assert.is_nil(LocalStorage["test-conn"])
    end)

    test("clears connectionData for ConsentExpiredError", function()
      local conn = { id = "test-conn-2", service = "TestBank2" }
      LocalStorage["test-conn-2"] = "stale-consent" --[[@as any]]
      local session = { connection = conn, activeService = nil, activeTicket = nil }

      local err = setmetatable({}, ConsentExpiredError)
      err.name = "ConsentExpiredError"
      err.message = "Consent expired"

      errors.errorHandler(session, err)
      assert.is_nil(LocalStorage["test-conn-2"])
    end)
  end)

  context("protected", function()
    test("returns function result on success", function()
      local result = errors.protected(nil, function()
        return 42
      end)
      assert.are_equal(42, result)
    end)

    test("returns error string on failure", function()
      local result = errors.protected(nil, function()
        error("boom")
      end)
      assert.is_string(result)
      assert.is_truthy(tostring(result):find("boom"))
    end)

    test("passes arguments to the wrapped function", function()
      local result = errors.protected(nil, function(a, b)
        return a + b
      end, 3, 4)
      assert.are_equal(7, result)
    end)

    test("writes error trace on failure when session has active service", function()
      local traces = require("yaxi.traces")
      local origWrite = traces.write
      local errorWriteCalled = false
      traces.write = function(_sess)
        errorWriteCalled = true
      end

      local session = { activeService = "test", activeTicket = "ticket" }
      errors.protected(session, function()
        local err = setmetatable({}, RCError)
        err.name = "TestError"
        err.message = "test"
        error(err)
      end)
      assert.is_true(errorWriteCalled)

      traces.write = origWrite
    end)
  end)
end)
