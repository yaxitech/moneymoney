-- SPDX-License-Identifier: MIT
-- Author: Vincent Haupert <vincent.haupert@yaxi.tech>

local M = {}

---@type table<string, true>
local LOG_LEVELS = { DEBUG = true, INFO = true, WARN = true, ERROR = true, FATAL = true, OFF = true }

---User configuration from `yaxi-config.json`.
---@class YAXI.MoneyMoney.Config
---@field apiKeyId string?
---@field apiKeySecret string?
---@field logLevel lualogging.Level?
---@field suppressVopWarning boolean?

---Extract the MoneyMoney Extensions directory from `package.path`.
---@return string?
local function extensionsDir()
  for p in string.gmatch(package.path, "[^;]+") do
    local dir = p:match("^(.*MoneyMoney/Extensions)")
    if dir then
      return dir
    end
  end
  return nil
end

---@param log lualogging.Logger
---@return YAXI.MoneyMoney.Config
local function read(log)
  local dir = extensionsDir()
  if not dir then
    log:error("Could not find Extensions directory in package.path: %s", package.path)
    return {}
  end
  local configPath = dir .. "/yaxi-config.json"
  local f = io.open(configPath, "r")
  if not f then
    log:error("Could not open config file: %s", configPath)
    return {}
  end
  local content = f:read("*a")
  f:close()
  if not content or #content == 0 then
    return {}
  end
  return JSON(content):dictionary()
end

---Read and parse `yaxi-config.json` from the Extensions directory.
---@param log lualogging.Logger
---@return YAXI.MoneyMoney.Config
function M.load(log)
  local config = read(log)
  if config.logLevel ~= nil and not LOG_LEVELS[config.logLevel] then
    log:warn("Ignoring invalid logLevel %s", tostring(config.logLevel))
    config.logLevel = nil
  end
  return config
end

return M
