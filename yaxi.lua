-- SPDX-License-Identifier: MIT
-- Author: Vincent Haupert <vincent.haupert@yaxi.tech>

-- MoneyMoney loader: sets up package.path and delegates to yaxi/init.lua.
-- The bundled release build (bundler/YAXI.lua) inlines yaxi/init.lua directly.

local function setupPackagePath(dirs)
  local paths = {}
  for p in string.gmatch(package.path, "[^;]*") do
    table.insert(paths, p)
  end

  local baseDir
  for _, p in ipairs(paths) do
    if p:find("MoneyMoney/Extensions") then
      baseDir = p:gsub("^(.*MoneyMoney/Extensions).*$", "%1")
      break
    end
  end

  if not baseDir then
    error(("Could not find MoneyMoney extension directory: %s"):format(package.path))
  end

  package.path = ""

  local extraPaths = {
    "?/init.lua",
    "?.lua",
  }
  for _, dir in ipairs(dirs) do
    table.insert(extraPaths, ("%s/?.lua"):format(dir))
    table.insert(extraPaths, ("%s/?/init.lua"):format(dir))
  end

  for _, extraPath in ipairs(extraPaths) do
    local fullPath = baseDir .. "/" .. extraPath
    package.path = package.path .. ";" .. fullPath
  end
end

setupPackagePath({
  "yaxi",
  "yaxi/routex-client-lua",
})
require("yaxi")
