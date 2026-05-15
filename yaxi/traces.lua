-- SPDX-License-Identifier: MIT
-- Author: Vincent Haupert <vincent.haupert@yaxi.tech>

local base64 = require("routex-client.util.base64")
local json = require("routex-client.vendor.json")
local log = (require("routex-client.logging") --[[@as lualogging]]).defaultLogger()
local manifest = require("yaxi.manifest")
local ticketMod = require("yaxi.ticket")
local util = require("yaxi.util")

local M = {}

---SHA-256 the first extension entry point found in `dir` (`YAXI.lua` or `yaxi.lua`).
---@param dir string
---@return string? hex Lowercase hex digest
function M.hashExtensionFile(dir)
  for _, name in ipairs({ "YAXI.lua", "yaxi.lua" }) do
    local f = io.open(dir .. "/" .. name, "r")
    if f then
      local content = f:read("*a")
      f:close()
      return MM.sha256(content):lower()
    end
  end
  return nil
end

---@type string?
local extensionDigest

do
  for p in string.gmatch(package.path, "[^;]+") do
    local dir = p:match("^(.*MoneyMoney/Extensions)")
    if dir then
      extensionDigest = M.hashExtensionFile(dir)
      break
    end
  end
end

---@type string?
local lastWrittenTraceId = nil

---Write an AGE-encrypted error trace to TMPDIR.
---Returns the file path, or nil if the trace is unavailable or unencrypted.
---No-ops when the same traceId was already written this session.
---@param session YAXI.MoneyMoney.Session
---@return string? tracePath
function M.write(session)
  local tmpdir = os.getenv("TMPDIR")
  if not tmpdir then
    return nil
  end

  local traceId = session.client:traceId()
  if not traceId or traceId == lastWrittenTraceId then
    return nil
  end

  local ticketForTrace = session.ticketGenerator:accounts(MM.uuid())
  local ok, trace = pcall(session.client.trace, session.client, ticketForTrace, traceId)
  if not ok or not trace then
    return nil
  end

  if not trace:find("-----BEGIN AGE ENCRYPTED FILE-----", 1, true) then
    log:debug("Skipping unencrypted trace")
    return nil
  end

  local connName = util.slugify(session.connection.service or "unknown")
  local serviceName = session.activeService or "unknown"
  local ticketId = session.activeTicket and ticketMod.getId(session.activeTicket) or "no-ticket"
  local filename =
    string.format("trace_%s_error_%s_%s_%s.age.txt", connName, serviceName, ticketId, base64.encodeUrlsafe(traceId))
  local tracePath = tmpdir:gsub("/+$", "") .. "/" .. filename

  local f = io.open(tracePath, "w")
  if not f then
    log:warn("Could not write trace to %s", tracePath)
    return nil
  end
  f:write("# " .. json.encode({
    connection = session.connection.service,
    extensionVersion = manifest.version,
    extensionDigest = extensionDigest,
    service = serviceName,
    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
  }) .. "\n")
  f:write(trace)
  f:close()
  log:debug("Wrote trace to %s", tracePath)

  lastWrittenTraceId = traceId
  return tracePath
end

return M
