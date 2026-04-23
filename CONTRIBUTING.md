# Contributing

## Prerequisites

- **Lua 5.4**, **[StyLua](https://github.com/JohnnyMorganz/StyLua)**, and **[EmmyLua Check](https://github.com/EmmyLuaLs/emmylua-analyzer-rust)** (CI runs all three via `nix flake check`).
- A **language server** for type hints is strongly recommended: [EmmyLua](https://github.com/EmmyLuaLs/emmylua-analyzer-rust) or [LuaLS](https://github.com/LuaLS/lua-language-server).
- A free **YAXI API key** from [hub.yaxi.tech](https://hub.yaxi.tech).
  Create a key for the **Integration** environment — the demo bank used in tests is only available there.

If you use Nix, `nix develop` provides everything.

## Development

### Building

To bundle and install the extension locally:

```sh
cd bundler
npm run build   # produces YAXI.lua
npm run deploy  # builds and copies YAXI.lua into MoneyMoney's Extensions folder
```

MoneyMoney picks up the new version automatically.

### Code quality

```sh
# Run unit tests
busted --run=offline

# Run full suite (needs YAXI_API_KEY_ID and YAXI_API_KEY_SECRET in env)
busted

# Format
stylua .

# Type check
emmylua-check --warnings-as-errors .
```

CI runs `nix flake check` which includes all of the above.
PRs must pass.

## Adding a bank connection

### 1. Find the connection

Search for your bank on [yaxi.tech](https://yaxi.tech) or via the API:

```sh
curl https://api.yaxi.tech/search \
  -H 'Content-Type: application/json' \
  -d '{"filters": [{"term": "Your Bank"}]}'
```

Note the `connectionId` from the result.
If your bank isn't listed, you can request support for it by [opening an issue](https://github.com/yaxitech/moneymoney/issues).

### 2. Create the connection file

Add `yaxi/connections/yourbank.lua` returning a `YAXI.MoneyMoney.Connection.Config` table.
Minimal example:

```lua
-- SPDX-License-Identifier: MIT
---@type YAXI.MoneyMoney.Connection.Config
return {
  id = "connection-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",  -- from step 1
  service = "YAXI Your Bank",
  bic = "YOURBICXXXX",
  url = "https://yourbank.example.com",
  since = os.time({ year = 2000, month = 1, day = 1 }),    -- earliest transaction date
  tanMethods = {
    {
      name = "pushTAN",      -- controls MoneyMoney's TAN UI (see below)
      hbciMethod = "920",    -- matching key (see below)
      poll = true,           -- decoupled: MoneyMoney polls instead of asking for TAN input
      isPreferred = true,
    },
  },
  paymentTypes = {
    PaymentTypeTransfer,
    PaymentTypeInstantTransfer,
  },
}
```

See `YAXI.MoneyMoney.Connection.Config` in `yaxi/connections/init.lua` for all fields and existing connections (e.g., `dkb.lua`, `n26.lua`) for real examples.

### 3. Register it

Add a `require` line to the `BANKS` table in `yaxi/connections/init.lua`.

### 4. Test it

Use your YAXI API key to run the full test suite.
For manual testing, set up MoneyMoney with the "YAXI Your Bank" service.

### Key concepts

**`name`** on `MM.TanMethod` controls which UI MoneyMoney shows for the TAN challenge.
Use one of the recognized names defined in `addons/moneymoney/library/mm.lua` (`MM.TanMethodName`): `"pushTAN"`, `"chipTAN QR"`, `"photoTAN"`, `"mobileTAN"`, etc.
Aliases like `"appTAN"`, `"BestSign"`, `"SecureGo plus"` also work for decoupled push flows.

**`hbciMethod`** is a matching key used internally to auto-select the right TAN method during payments.
The preferred convention follows FinTS security function codes (3-digit numbers in the 900-997 range, bank-specific).
Use the bank's actual FinTS codes if known; otherwise pick unique values.
See existing connections for reference.

**`since`** is the earliest date MoneyMoney will request transactions for on the first sync.
Set it as far back as the bank supports.
Some banks reject overly broad date ranges, so pick the earliest date that works.

**`mapChallenge`** — override this callback when the bank's Selection dialog uses names that don't match what you want MoneyMoney to display (e.g., DKB sends `"Seal One | iPhone"` which gets remapped to `"DKB App"`).
It also lets you assign `hbciMethod` to dialog options for payment auto-selection.

## Reporting issues

Include:

- Bank name and connection (e.g., "YAXI DKB")
- Extension version and MoneyMoney version
- Steps to reproduce
- **Trace files** if available — they are AGE-encrypted and contain request/response metadata that helps us debug.
  See [Diagnostic Archive](https://docs.yaxi.tech/diagnostics.html#_diagnostic_archive) for details on what they contain.
  Trace files are written to `$TMPDIR` with filenames starting with `trace_` and ending in `.age.txt`.
  The full path is shown in the error message raised to the MoneyMoney UI.
