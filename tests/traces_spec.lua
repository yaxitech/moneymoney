-- SPDX-License-Identifier: MIT

dofile("tests/mm_env.lua")

local assert = require("luassert")
local traces = require("yaxi.traces")

context("yaxi.traces", function()
  context("hashExtensionFile", function()
    test("hashes YAXI.lua when present", function()
      local dir = os.tmpname()
      os.remove(dir)
      os.execute(string.format("mkdir -p %q/MoneyMoney/Extensions", dir))
      local extDir = dir .. "/MoneyMoney/Extensions"
      local f = io.open(extDir .. "/YAXI.lua", "w")
      assert.is_truthy(f)
      f:write("-- test extension") ---@diagnostic disable-line: need-check-nil
      f:close() ---@diagnostic disable-line: need-check-nil

      local digest = traces.hashExtensionFile(extDir)
      assert.is_string(digest)
      assert.are_equal(64, #digest)
      assert.are_equal(MM.sha256("-- test extension"), digest)

      os.execute(string.format("rm -rf %q", dir))
    end)

    test("prefers YAXI.lua over yaxi.lua", function()
      -- Mock io.open: case-insensitive filesystems (macOS APFS) collapse
      -- the two filenames, so real files cannot exercise the preference.
      local realOpen = io.open
      local tried = {}
      io.open = function(path)
        table.insert(tried, path)
        if path:match("YAXI%.lua$") then
          return {
            read = function()
              return "upper"
            end,
            close = function() end,
          }
        end
        return nil
      end

      local ok, digest = pcall(traces.hashExtensionFile, "/fake/dir")
      io.open = realOpen
      if not ok then
        error(digest)
      end

      assert.are_equal(MM.sha256("upper"), digest)
      assert.are_equal("/fake/dir/YAXI.lua", tried[1])
    end)

    test("returns nil when no extension file exists", function()
      local dir = os.tmpname()
      os.remove(dir)
      os.execute(string.format("mkdir -p %q", dir))

      assert.is_nil(traces.hashExtensionFile(dir))

      os.execute(string.format("rm -rf %q", dir))
    end)
  end)
end)
