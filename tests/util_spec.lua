-- SPDX-License-Identifier: MIT

-- Unit tests for yaxi.util module.

dofile("tests/mm_env.lua")

local assert = require("luassert")
local util = require("yaxi.util")

context("yaxi.util", function()
  context("split", function()
    test("splits a string by a delimiter", function()
      local result = util.split("a,b,c", ",")
      assert.are_same({ "a", "b", "c" }, result)
    end)

    test("returns single element for string without delimiter", function()
      local result = util.split("hello", ",")
      assert.are_same({ "hello" }, result)
    end)

    test("handles leading delimiter", function()
      local result = util.split(",a,b", ",")
      assert.are_same({ "", "a", "b" }, result)
    end)

    test("handles trailing delimiter", function()
      local result = util.split("a,b,", ",")
      assert.are_same({ "a", "b", "" }, result)
    end)

    test("splits by pattern", function()
      local result = util.split("a - b - c", " %- ")
      assert.are_same({ "a", "b", "c" }, result)
    end)
  end)

  context("strip", function()
    test("strips whitespace including tabs and newlines", function()
      assert.are_equal("hello", util.strip("  hello  "))
      assert.are_equal("hello", util.strip("\t\nhello\t\n"))
    end)
  end)

  context("extractOAuthState", function()
    test("extracts state parameter from URL", function()
      local url = "https://bank.example.com/auth?response_type=code&state=abc123&scope=openid"
      assert.are_equal("abc123", util.extractOAuthState(url))
    end)

    test("returns nil when no state parameter", function()
      local url = "https://bank.example.com/auth?response_type=code&scope=openid"
      assert.is_nil(util.extractOAuthState(url))
    end)
  end)

  context("notEmpty", function()
    test("returns string for non-empty input", function()
      assert.are_equal("hello", util.notEmpty("hello"))
    end)

    test("returns nil for empty string", function()
      assert.is_nil(util.notEmpty(""))
    end)

    test("returns nil for nil", function()
      assert.is_nil(util.notEmpty(nil))
    end)
  end)

  context("slugify", function()
    test("lowercases and replaces non-alphanumeric with underscores", function()
      assert.are_equal("yaxi_demo", util.slugify("YAXI Demo"))
    end)

    test("strips leading and trailing underscores", function()
      assert.are_equal("test", util.slugify("--test--"))
    end)
  end)

  context("values", function()
    test("collects all values from a table", function()
      local result = util.values({ a = 1, b = 2 })
      table.sort(result)
      assert.are_same({ 1, 2 }, result)
    end)

    test("returns empty table for empty input", function()
      assert.are_same({}, util.values({}))
    end)
  end)

  context("fmt", function()
    test("formats tables as JSON", function()
      assert.is_truthy(util.fmt({ a = 1 }):find('"a"'))
    end)

    test("formats non-tables via tostring", function()
      assert.are_equal("42", util.fmt(42))
      assert.are_equal("true", util.fmt(true))
    end)
  end)
end)
