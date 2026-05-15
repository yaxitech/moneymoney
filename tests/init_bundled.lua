-- SPDX-License-Identifier: MIT
-- Author: Vincent Haupert <vincent.haupert@yaxi.tech>

-- Bundled busted helper: shared setup + extension loaded from the single-file bundle.
-- Copies YAXI.lua and yaxi-config.json into a temporary MoneyMoney/Extensions
-- directory so that the bundle's extensionsDir() resolver finds them via package.path.

dofile("tests/mm_env.lua")

local vendorJson = require("routex-client.vendor.json")

local apiKeyId = requireEnv("YAXI_API_KEY_ID")
local apiKeySecret = requireEnv("YAXI_API_KEY_SECRET")

-- Create a temporary directory mimicking the MoneyMoney Extensions layout.
local base = os.tmpname()
os.remove(base)
local extDir = base .. "/MoneyMoney/Extensions"
assert(os.execute(string.format("mkdir -p %q", extDir)))

-- Copy the bundled extension into the temp directory as YAXI.lua.
local src = assert(io.open("bundler/YAXI.lua", "r"))
local source = src:read("*a")
src:close()

local dst = assert(io.open(extDir .. "/YAXI.lua", "w"))
dst:write(source)
dst:close()

-- Write a config file next to the bundle.
-- `suppressVopWarning = true` mirrors `tests/init.lua` so SubmitPayment tests
-- exercise the bank-side flow directly without the pre-`callTransfer` VoP warning.
local config = vendorJson.encode({
  apiKeyId = apiKeyId,
  apiKeySecret = apiKeySecret,
  suppressVopWarning = true,
})
local cf = assert(io.open(extDir .. "/yaxi-config.json", "w"))
cf:write(config)
cf:close()

-- Prepend the Extensions directory to package.path so that
-- the bundle's extensionsDir() pattern match succeeds.
package.path = extDir .. "/?.lua;" .. package.path

-- Load and execute the bundle.
assert(load(source, "@" .. extDir .. "/YAXI.lua"))()

-- Clean up the temporary directory after all tests have run.
require("busted").subscribe({ "suite", "end" }, function()
  os.execute(string.format("rm -rf %q", base))
end)
