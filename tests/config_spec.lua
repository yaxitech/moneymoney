-- SPDX-License-Identifier: MIT

dofile("tests/mm_env.lua")

local assert = require("luassert")
local config = require("yaxi.config")
local logging = require("routex-client.logging") --[[@as lualogging]]

context("yaxi.config", function()
  local origPath = package.path
  ---@type string
  local extDir

  before_each(function()
    local dir = os.tmpname()
    os.remove(dir)
    extDir = dir .. "/MoneyMoney/Extensions"
    os.execute(string.format("mkdir -p %q", extDir))
    package.path = extDir .. "/?.lua;" .. origPath
  end)

  after_each(function()
    package.path = origPath
  end)

  ---@param content string
  local function writeConfig(content)
    local f = io.open(extDir .. "/yaxi-config.json", "w")
    assert.is_truthy(f)
    ---@cast f -nil
    f:write(content)
    f:close()
  end

  ---@return lualogging.Logger log, string[] warnings
  local function recordingLogger()
    local warnings = {}
    local log = logging.new(function(_, level, message)
      if level == logging.WARN then
        table.insert(warnings, message)
      end
      return true
    end)
    return log, warnings
  end

  test("keeps a valid log level", function()
    writeConfig('{"logLevel": "DEBUG"}')
    local log, warnings = recordingLogger()
    assert.are_equal("DEBUG", config.load(log).logLevel)
    assert.are_same({}, warnings)
  end)

  test("drops an invalid log level with a warning", function()
    writeConfig('{"logLevel": "debug"}')
    local log, warnings = recordingLogger()
    assert.is_nil(config.load(log).logLevel)
    assert.are_equal(1, #warnings)
  end)
end)
