-- SPDX-License-Identifier: MIT
-- Author: Vincent Haupert <vincent.haupert@yaxi.tech>

-- Log appender bridging `lualogging` to MoneyMoney's `MM.printDebug`/`print`.

local logging = require("routex-client.logging")
local prepareLogMsg = logging.prepareLogMsg or error("prepareLogMsg not found in logging module")

local M = setmetatable({}, {
  __call = function(self, ...)
    -- calling on the module instantiates a new logger
    return self.new(...)
  end,
})

---Resolve the source location of the log caller.
---`lualogging`'s built-in `%source` detection is broken in MoneyMoney because the
---`sourceDebugLevel` calibration loop fails in this environment, so we resolve
---the caller ourselves from inside the appender at a known stack depth.
---Uses `info.source` (full path) instead of `short_src` (truncated by Lua to ~60 chars).
---@return string
local function resolveSource()
  if not debug or not debug.getinfo then
    return "?:?"
  end
  -- Walk the stack upwards from the appender to find the first frame
  -- outside of the logging library itself.
  for level = 2, 10 do
    local info = debug.getinfo(level, "Sl")
    if not info then
      break
    end
    local src = info.source or ""
    if not src:find("logging") and not src:find("logger%.lua") then
      -- `info.source` is prefixed with `@` for file sources; strip it,
      -- then strip everything up to and including `Extensions/`
      src = src:gsub("^@", "")
      src = src:gsub("^.*Extensions/", "")
      return string.format("%s:%d", src, info.currentline or 0)
    end
  end
  return "?:?"
end

---Create a new MoneyMoney log appender.
---@param params table|string Logger configuration or legacy `logPattern` string
---@param ... any Additional deprecated positional arguments
---@return table logger A `lualogging` logger instance
function M.new(params, ...)
  params = logging.getDeprecatedParams({ "logPattern" }, params, ...)
  local startLevel = params.logLevel or logging.defaultLevel()
  local timestampPattern = params.timestampPattern or logging.defaultTimestampPattern()

  -- Do NOT use `%source` — `lualogging`'s `sourceDebugLevel` detection is broken
  -- in MoneyMoney. We resolve source info ourselves in `resolveSource()`.
  -- Pad level names to 5 chars for alignment (`DEBUG`/`ERROR`/`FATAL`=5, `INFO`/`WARN`=4).
  local prefix = params.prefix or ""
  local function pat(paddedLevel)
    return string.format("[%s%s] %s", prefix, paddedLevel, "%message")
  end
  local defaultLogPatterns = {
    [logging.DEBUG] = pat("DEBUG"),
    [logging.INFO] = pat("INFO "),
    [logging.WARN] = pat("WARN "),
    [logging.ERROR] = pat("ERROR"),
    [logging.FATAL] = pat("FATAL"),
  }

  local logPatterns = logging.buildLogPatterns(params.logPatterns or defaultLogPatterns, params.logPattern)

  local SOURCE_LEVELS = {
    [logging.DEBUG] = true,
    [logging.ERROR] = true,
    [logging.FATAL] = true,
  }

  return logging.new(function(_, level, message)
    local preparedMessage = prepareLogMsg(logPatterns[level], logging.date(timestampPattern), level, message)
    if SOURCE_LEVELS[level] then
      preparedMessage = preparedMessage .. " (" .. resolveSource() .. ")"
    end
    if level == logging.DEBUG or level == logging.INFO then
      MM.printDebug(preparedMessage)
    else
      print(preparedMessage)
    end
    return true
  end, startLevel)
end

logging.MM = M
return M
