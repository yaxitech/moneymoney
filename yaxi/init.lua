-- SPDX-License-Identifier: MIT
-- Author: Vincent Haupert <vincent.haupert@yaxi.tech>
--
--    ██╗   ██╗ █████╗ ██╗  ██╗██╗
--    ╚██╗ ██╔╝██╔══██╗╚██╗██╔╝██║
--     ╚████╔╝ ███████║ ╚███╔╝ ██║
--      ╚██╔╝  ██╔══██║ ██╔██╗ ██║
--       ██║   ██║  ██║██╔╝ ██╗██║
--       ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝
--  ─── Open Banking for MoneyMoney ───
--
--  Get your free API key at https://hub.yaxi.tech
--  Configure it in yaxi-config.json (next to this file).
--

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

---Read and parse `yaxi-config.json` from the Extensions directory.
---@param log { error: fun(self: any, fmt: string, ...: any) }
---@return { apiKeyId: string?, apiKeySecret: string?, logLevel: string?, suppressVopWarning: boolean? }
local function loadConfig(log)
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

local function setupLogging()
  local logging = require("routex-client.logging")
  local mmLogger = require("yaxi.mm.logger")({ prefix = "YAXI " })
  logging.defaultLogger(mmLogger)
end

setupLogging()

local log = require("routex-client.logging").defaultLogger()
local config = loadConfig(log)
log:setLevel(config.logLevel or "INFO")

local extension = require("yaxi.extension")
extension.setup({
  apiKeyId = config.apiKeyId or "",
  apiKeySecret = config.apiKeySecret or "",
  suppressVopWarning = config.suppressVopWarning or false,
})

log:info("YAXI loaded")
