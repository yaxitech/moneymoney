-- SPDX-License-Identifier: MIT
-- Author: Vincent Haupert <vincent.haupert@yaxi.tech>

-- Shared utility functions.

local M = {}

---Return `s` if it is a non-empty string, otherwise `nil`.
---@param s string?
---@return string?
function M.notEmpty(s)
  if s and s ~= "" then
    return s
  end
  return nil
end

---Split a string by the given Lua pattern.
---@param str string
---@param pat string
---@return string[]
function M.split(str, pat)
  local t = {}
  local pos = 1
  while true do
    local s, e = str:find(pat, pos)
    if not s then
      table.insert(t, str:sub(pos))
      break
    end
    table.insert(t, str:sub(pos, s - 1))
    pos = (e or s) + 1
  end
  return t
end

---Strip leading and trailing whitespace.
---@param s string
---@return string
function M.strip(s)
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

---Extract the OAuth `state` query parameter from a URL.
---@param url string
---@return string?
function M.extractOAuthState(url)
  for key, value in url:gmatch("([%w_%%]+)=([^&]*)") do
    if key == "state" then
      return value
    end
  end
  return nil
end

---Convert a string to a lowercase slug (alphanumeric and underscores only).
---@param s string
---@return string
function M.slugify(s)
  return (s:lower():gsub("[^%w]+", "_"):gsub("^_+", ""):gsub("_+$", ""))
end

---Collect all values from a table into an array.
---@param t table<any, any>
---@return any[]
function M.values(t)
  local result = {}
  for _, v in pairs(t) do
    result[#result + 1] = v
  end
  return result
end

---Format a value for debug logging: tables as JSON, everything else via `tostring`.
---@param v any
---@return string
function M.fmt(v)
  if type(v) == "table" then
    return JSON():set(v):json()
  end
  return tostring(v)
end

return M
