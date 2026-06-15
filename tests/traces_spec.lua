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

  context("write", function()
    local ticketMod = require("yaxi.ticket")

    ---A fake routex client that records which trace id it was asked to fetch and
    ---returns AGE-encrypted content tagged with `label`.
    ---@param label string
    local function fakeClient(label)
      local fetched = {}
      return {
        fetched = fetched,
        traceId = function()
          return label .. "-trace-id"
        end,
        trace = function(_self, _ticket, traceId)
          table.insert(fetched, traceId)
          return ("-----BEGIN AGE ENCRYPTED FILE-----\n%s\n-----END AGE ENCRYPTED FILE-----"):format(label)
        end,
      }
    end

    ---@param which "refresh"|"interactive"|nil Which client is the active one
    local function mockSession(which)
      local interactive = fakeClient("interactive")
      local refresh = fakeClient("refresh")
      ---@type any
      local session = {
        client = interactive,
        refreshClient = refresh,
        activeClient = (which == "refresh" and refresh) or (which == "interactive" and interactive) or nil,
        connection = { service = "MockBank" },
        ticketGenerator = {
          accounts = function()
            return "trace-fetch-ticket"
          end,
        },
        activeService = "balances",
        activeTicket = "active-ticket",
      }
      return session, interactive, refresh
    end

    local function readFile(path)
      local f = io.open(path, "r")
      assert.is_truthy(f)
      local content = f:read("*a") ---@diagnostic disable-line: need-check-nil
      f:close() ---@diagnostic disable-line: need-check-nil
      return content
    end

    local origGetId
    before_each(function()
      origGetId = ticketMod.getId
      ---@diagnostic disable-next-line: duplicate-set-field
      ticketMod.getId = function()
        return "tid"
      end
    end)
    after_each(function()
      ticketMod.getId = origGetId
    end)

    test("fetches the trace from the client that issued the failing call", function()
      local session, interactive, refresh = mockSession("refresh")

      local path = traces.write(session)

      assert.is_string(path)
      ---@cast path string
      -- The failing call went through the refresh client: fetch its trace, not
      -- the interactive client's (stale) one.
      assert.are_same({ "refresh-trace-id" }, refresh.fetched)
      assert.are_equal(0, #interactive.fetched)

      local content = readFile(path)
      assert.is_truthy(content:find("\nrefresh\n", 1, true))
      assert.is_falsy(content:find("\ninteractive\n", 1, true))
      os.remove(path)
    end)

    test("falls back to the interactive client when no active client is set", function()
      local session, interactive, refresh = mockSession(nil)

      local path = traces.write(session)

      assert.is_string(path)
      ---@cast path string
      assert.are_same({ "interactive-trace-id" }, interactive.fetched)
      assert.are_equal(0, #refresh.fetched)
      os.remove(path)
    end)
  end)
end)
