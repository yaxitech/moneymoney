---@meta

-- Partial type overlay for the `lualogging`-compatible module exported by
-- `routex-client.logging`. Covers the surface used by this codebase. Source of
-- truth: `routex-client-lua/vendor/logging/init.lua`. Not all upstream APIs
-- are stubbed (e.g. `compilePattern`, `getPrint`, `tostring`).

---@alias lualogging.Level "DEBUG" | "INFO" | "WARN" | "ERROR" | "FATAL" | "OFF"

---@class lualogging.Logger
---@field level lualogging.Level
local Logger = {}

---@param level lualogging.Level
---@param fmt string|any
---@param ... any
function Logger:log(level, fmt, ...) end

---@param fmt string|any
---@param ... any
function Logger:debug(fmt, ...) end

---@param fmt string|any
---@param ... any
function Logger:info(fmt, ...) end

---@param fmt string|any
---@param ... any
function Logger:warn(fmt, ...) end

---@param fmt string|any
---@param ... any
function Logger:error(fmt, ...) end

---@param fmt string|any
---@param ... any
function Logger:fatal(fmt, ...) end

---@param level lualogging.Level
function Logger:setLevel(level) end

---@class lualogging
---@field DEBUG lualogging.Level
---@field INFO lualogging.Level
---@field WARN lualogging.Level
---@field ERROR lualogging.Level
---@field FATAL lualogging.Level
---@field OFF lualogging.Level
local logging = {}

---@param append fun(self: lualogging.Logger, level: lualogging.Level, message: string): boolean
---@param startLevel? lualogging.Level
---@return lualogging.Logger
function logging.new(append, startLevel) end

---@param logger? lualogging.Logger
---@return lualogging.Logger
function logging.defaultLogger(logger) end

---@param level? lualogging.Level
---@return lualogging.Level
function logging.defaultLevel(level) end

---@param pattern? string
---@return string?
function logging.defaultTimestampPattern(pattern) end

---@param patterns? table<lualogging.Level, string>
---@param default? string
---@return table<lualogging.Level, string>
function logging.buildLogPatterns(patterns, default) end

---@param lpattern string
---@param dpattern string
---@param level lualogging.Level
---@param message string
---@return string
function logging.prepareLogMsg(lpattern, dpattern, level, message) end

---@param fmt? string
---@param t? number
---@return string
function logging.date(fmt, t) end

---@param lst string[]
---@param ... any
---@return table
function logging.getDeprecatedParams(lst, ...) end

return logging
