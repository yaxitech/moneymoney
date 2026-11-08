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

local function setupLogging()
  local logging = require("routex-client.logging") --[[@as lualogging]]
  local mmLogger = require("yaxi.mm.logger")({ prefix = "YAXI " })
  logging.defaultLogger(mmLogger)
end

setupLogging()

local log = (require("routex-client.logging") --[[@as lualogging]]).defaultLogger()
local config = require("yaxi.config").load(log)
log:setLevel(config.logLevel or "INFO")

local extension = require("yaxi.extension")
extension.setup({
  apiKeyId = config.apiKeyId or "",
  apiKeySecret = config.apiKeySecret or "",
  suppressVopWarning = config.suppressVopWarning or false,
})

log:info("YAXI loaded")
