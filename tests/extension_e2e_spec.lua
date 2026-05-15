-- SPDX-License-Identifier: MIT
-- Author: Vincent Haupert <vincent.haupert@yaxi.tech>

-- Extension-level end-to-end tests for the YAXI Demo connection.
--
-- These tests call the actual MoneyMoney extension callbacks (SupportsBank,
-- InitializeSession2, ListAccounts, RefreshAccount, EndSession) with the same
-- parameters MoneyMoney uses.
--
-- Each demo user ID triggers a specific interrupt flow:
--   "result"       → immediate result (no SCA)
--   "confirmation" → Confirmation dialog (polling)
--   "selection"    → Selection dialog (TAN method choice)
--   "input"        → Field dialog (TAN entry)
--   "redirect"     → Redirect (OAuth flow)
--   "random"       → all interrupt types, in random order
--
-- See https://docs.yaxi.tech/interrupts.html#_test_cases

local assert = require("luassert")

--- Verify ListAccounts returns mapped accounts and store them for later tests.
---@param accounts MM.Account[]?
---@return MM.Account[]
local function verifyListAccounts(accounts)
  assert.is_table(accounts)
  ---@cast accounts MM.Account[]
  assert.is_true(#accounts > 0)

  local acc = accounts[1]
  assert.is_truthy(acc)
  ---@cast acc MM.Account
  assert.is_string(acc.iban)
  assert.is_string(acc.currency)

  return accounts
end

--- Build an MM account table for RefreshAccount from a ListAccounts result.
---@param acc MM.Account
---@return MM.Account
local function buildRefreshAccountParam(acc)
  return {
    portfolio = false,
    owner = acc.owner,
    attributes = {},
    bic = acc.bic,
    type = "Unknown",
    comment = "",
    balanceDate = os.time(),
    subAccount = "",
    name = acc.name,
    iban = acc.iban,
    balance = 0,
    bankCode = acc.bankCode,
    accountNumber = acc.accountNumber,
    currency = acc.currency,
  }
end

--- Verify RefreshAccount returns balance and transactions.
---@param acc MM.Account
local function verifyRefreshAccount(acc)
  local result = RefreshAccount(buildRefreshAccountParam(acc), 0, function()
    return false
  end, 1, {})

  assert.is_table(result)
  ---@cast result MM.RefreshAccountResponse
  assert.is_number(result.balance)
  local transactions = result.transactions
  assert.is_table(transactions)
  ---@cast transactions MM.Transaction[]
  assert.is_true(#transactions > 0)

  local tx = transactions[1]
  assert.is_truthy(tx)
  ---@cast tx MM.Transaction
  assert.is_number(tx.amount)
  assert.is_number(tx.bookingDate)
end

--- Verify EndSession persists connection data.
local function verifyEndSession()
  EndSession()
  local demoConnId = "connection-96386142-60e5-4ca9-abcf-944efce5bc1e"
  assert.is_truthy(LocalStorage[demoConnId])
end

--- Reset all extension state to simulate a fresh MoneyMoney start.
--- EndSession flushes the module-level session; clearing LocalStorage
--- removes persisted connectionData that would skip SCA via recurring consent.
local function resetState()
  EndSession()
  for k in pairs(LocalStorage) do
    LocalStorage[k] = nil
  end
end

-- Tests within each context run sequentially and depend on shared session state.
context("Extension e2e — YAXI Demo #online", function()
  --region SupportsBank

  context("SupportsBank", function()
    test("accepts YAXI Demo via Web Banking protocol", function()
      local result = SupportsBank(ProtocolWebBanking, "YAXI Demo") --[[@as false|table]]
      assert.is_table(result)
      assert.is_string(result.url)

      local result2 = SupportsBank(ProtocolWebBanking, "YAXI Demo") --[[@as false|table]]
      assert.is_table(result2)
      assert.are.equal(result.url, result2.url)
    end)

    test("rejects unknown bank codes", function()
      assert.is_false(SupportsBank(ProtocolWebBanking, "Unknown Bank"))
    end)

    test("rejects non-WebBanking protocols", function()
      assert.is_false(SupportsBank(ProtocolFinTS, "YAXI Demo"))
    end)
  end)

  --endregion SupportsBank

  --region Account setup — result (no SCA)

  context("Account setup — result (no SCA)", function()
    setup(resetState)

    ---@type MM.Account[]?
    local accounts

    test("InitializeSession2 step=1 returns nil (immediate result)", function()
      local challenge = InitializeSession2(
        ProtocolWebBanking,
        "YAXI Demo",
        1,
        { "result", "" } --[[@as MM.Credentials]],
        true,
        {},
        "new account"
      )
      assert.is_nil(challenge)
    end)

    test("ListAccounts returns mapped accounts", function()
      accounts = ListAccounts({}) --[[@as MM.Account[] ]]
      accounts = verifyListAccounts(accounts)
    end)

    test("RefreshAccount returns balance and transactions", function()
      ---@diagnostic disable-next-line: need-check-nil, param-type-mismatch
      verifyRefreshAccount(accounts[1])
    end)

    test("EndSession persists connection data", function()
      verifyEndSession()
    end)
  end)

  --endregion Account setup — result

  --region Account setup — confirmation (polling)

  context("Account setup — confirmation (polling)", function()
    setup(resetState)

    test("InitializeSession2 step=1 returns poll challenge", function()
      local challenge = InitializeSession2(
        ProtocolWebBanking,
        "YAXI Demo",
        1,
        { "confirmation", "" } --[[@as MM.Credentials]],
        true,
        {},
        "new account"
      )

      assert.is_table(challenge)
      ---@cast challenge table
      assert.is_true(challenge.poll)
      assert.is_string(challenge.challenge)
    end)

    test("InitializeSession2 step=2 resolves confirmation", function()
      -- MM re-calls with credentials[3]=true for poll
      local challenge = InitializeSession2(
        ProtocolWebBanking,
        "YAXI Demo",
        2,
        { "", "The required authorization has not been carried out.", true } --[[@as MM.Credentials]],
        true,
        {},
        "new account"
      )
      assert.is_nil(challenge)
    end)

    test("ListAccounts returns mapped accounts", function()
      local accounts = ListAccounts({}) --[[@as MM.Account[] ]]
      verifyListAccounts(accounts)
    end)
  end)

  --endregion Account setup — confirmation

  --region Account setup — selection (TAN method choice)

  context("Account setup — selection (TAN method choice)", function()
    setup(resetState)

    ---@type MM.TanMethod?
    local selectedMethod

    test("InitializeSession2 step=1 returns tanMethods challenge", function()
      local challenge = InitializeSession2(
        ProtocolWebBanking,
        "YAXI Demo",
        1,
        { "selection", "" } --[[@as MM.Credentials]],
        true,
        {},
        "new account"
      )

      assert.is_table(challenge)
      ---@cast challenge table
      assert.is_table(challenge.tanMethods)
      ---@cast challenge { tanMethods: MM.TanMethod[] }
      assert.is_true(#challenge.tanMethods > 0)

      -- Demo mapChallenge renames IBAN-based options to appTAN/smsTAN
      local found = false
      for _, method in ipairs(challenge.tanMethods) do
        assert.is_string(method.webMethod)
        if method.name == "appTAN" or method.name == "smsTAN" then
          found = true
        end
      end
      assert.is_true(found)

      -- Pick the first method for step=2
      selectedMethod = challenge.tanMethods[1]
    end)

    test("InitializeSession2 step=2 resolves selection", function()
      assert.is_truthy(selectedMethod)
      -- MM passes the selected TAN method back in credentials
      local challenge = InitializeSession2(
        ProtocolWebBanking,
        "YAXI Demo",
        2,
        { selectedMethod } --[[@as MM.Credentials]],
        true,
        {},
        "new account"
      )
      assert.is_nil(challenge)
    end)

    test("ListAccounts returns mapped accounts", function()
      local accounts = ListAccounts({}) --[[@as MM.Account[] ]]
      verifyListAccounts(accounts)
    end)
  end)

  --endregion Account setup — selection

  --region Account setup — input (TAN entry)

  context("Account setup — input (TAN entry)", function()
    setup(resetState)

    test("InitializeSession2 step=1 returns field challenge", function()
      local challenge = InitializeSession2(
        ProtocolWebBanking,
        "YAXI Demo",
        1,
        { "input", "" } --[[@as MM.Credentials]],
        true,
        {},
        "new account"
      )

      assert.is_table(challenge)
      ---@cast challenge table
      assert.is_truthy(challenge.label)
    end)

    test("InitializeSession2 step=2 resolves input", function()
      -- MM passes the user's TAN/input value as credentials[1]
      local challenge = InitializeSession2(
        ProtocolWebBanking,
        "YAXI Demo",
        2,
        { "123456" } --[[@as MM.Credentials]],
        true,
        {},
        "new account"
      )
      assert.is_nil(challenge)
    end)

    test("ListAccounts returns mapped accounts", function()
      local accounts = ListAccounts({}) --[[@as MM.Account[] ]]
      verifyListAccounts(accounts)
    end)
  end)

  --endregion Account setup — input

  --region Account setup — redirect (OAuth)

  context("Account setup — redirect (OAuth)", function()
    setup(resetState)

    test("InitializeSession2 step=1 returns redirect challenge", function()
      local challenge = InitializeSession2(
        ProtocolWebBanking,
        "YAXI Demo",
        1,
        { "redirect", "" } --[[@as MM.Credentials]],
        true,
        {},
        "new account"
      )

      assert.is_table(challenge)
      ---@cast challenge table
      assert.is_string(challenge.challenge)
      ---@cast challenge { challenge: string }
      assert.is_truthy(challenge.challenge:find("https://"))
    end)

    test("InitializeSession2 step=2 resolves redirect", function()
      -- MM captures the OAuth code from the redirect callback and passes it
      -- as credentials[1]. The demo accepts any code.
      local challenge = InitializeSession2(
        ProtocolWebBanking,
        "YAXI Demo",
        2,
        { "demo-auth-code" } --[[@as MM.Credentials]],
        true,
        {},
        "new account"
      )
      assert.is_nil(challenge)
    end)

    test("ListAccounts returns mapped accounts", function()
      local accounts = ListAccounts({}) --[[@as MM.Account[] ]]
      verifyListAccounts(accounts)
    end)
  end)

  --endregion Account setup — redirect

  --region Account setup — random (all interrupt types)

  context("Account setup — random (all interrupt types)", function()
    setup(resetState)

    ---Build the credentials for step N based on the challenge returned by step N-1.
    ---Mirrors the values MoneyMoney would pass for each interrupt type.
    ---@param challenge table
    ---@return MM.Credentials
    local function credentialsForChallenge(challenge)
      if challenge.poll then
        return { "", "The required authorization has not been carried out.", true }
      elseif challenge.tanMethods then
        return { challenge.tanMethods[1] }
      elseif type(challenge.challenge) == "string" and challenge.challenge:find("https://") then
        return { "demo-auth-code" } --[[@as MM.Credentials]]
      else
        -- Field / TAN input
        return { "123456" } --[[@as MM.Credentials]]
      end
    end

    test("InitializeSession2 resolves through random interrupts", function()
      local challenge = InitializeSession2(
        ProtocolWebBanking,
        "YAXI Demo",
        1,
        { "random", "" } --[[@as MM.Credentials]],
        true,
        {},
        "new account"
      )

      local step = 2
      while challenge ~= nil do
        assert.is_table(challenge)
        ---@cast challenge table
        local creds = credentialsForChallenge(challenge)
        challenge = InitializeSession2(ProtocolWebBanking, "YAXI Demo", step, creds, true, {}, "new account")
        step = step + 1
        assert.is_true(step <= 10) -- guard against infinite loop
      end

      assert.is_nil(challenge)
    end)

    test("ListAccounts returns mapped accounts", function()
      local accounts = ListAccounts({}) --[[@as MM.Account[] ]]
      verifyListAccounts(accounts)
    end)
  end)

  --endregion Account setup — random

  --region Refresh session (result user — no SCA)

  context("Refresh session (result user)", function()
    test("InitializeSession2 for refresh returns nil", function()
      local challenge = InitializeSession2(
        ProtocolWebBanking,
        "YAXI Demo",
        1,
        { "result", "" } --[[@as MM.Credentials]],
        true,
        {},
        "refresh"
      )
      assert.is_nil(challenge)
    end)

    test("RefreshAccount fetches balance and transactions", function()
      local mmAccount = {
        portfolio = false,
        owner = "Dr. Peter Steiger",
        attributes = {},
        bic = "BYLADEM1001",
        type = "Unknown",
        comment = "",
        balanceDate = os.time(),
        subAccount = "",
        name = "Account",
        iban = "DE02120300000000202051",
        balance = 0,
        bankCode = "12030000",
        accountNumber = "202051",
        currency = "EUR",
      }

      local result = RefreshAccount(mmAccount, 0, function()
        return false
      end, 1, {})

      assert.is_table(result)
      ---@cast result table
      assert.is_number(result.balance)
      assert.is_table(result.transactions)
    end)

    test("EndSession succeeds", function()
      EndSession()
    end)
  end)

  --endregion Refresh session

  --region GetTanMethods

  context("GetTanMethods", function()
    test("returns TAN methods for YAXI Demo BIC", function()
      local methods = GetTanMethods({ bic = "YAXIDEM0" })
      assert.is_table(methods)
      assert.is_true(#methods > 0)
      local names = {}
      for _, m in ipairs(methods) do
        names[m.name] = true
      end
      assert.is_true(names["appTAN"])
      assert.is_true(names["smsTAN"])
      assert.is_true(names["photoTAN"])
    end)

    test("returns error for unknown BIC", function()
      local result = GetTanMethods({ bic = "UNKNOWN0" })
      assert.is_string(result)
    end)
  end)

  --endregion GetTanMethods

  --region SubmitPayment — result (no SCA)

  context("SubmitPayment — result (no SCA)", function()
    setup(resetState)

    ---@type MM.Account[]?
    local accounts

    ---@type MM.Payment
    local payment = {
      type = PaymentTypeTransfer,
      name = "Max Mustermann",
      accountNumber = "NL58YAXI1234567890",
      amount = 1.00,
      currency = "EUR",
      purpose = "Test transfer",
    }

    test("InitializeSession2 sets up session", function()
      local challenge = InitializeSession2(
        ProtocolWebBanking,
        "YAXI Demo",
        1,
        { "result", "" } --[[@as MM.Credentials]],
        true,
        {},
        "new account"
      )
      assert.is_nil(challenge)
    end)

    test("ListAccounts returns accounts", function()
      accounts = ListAccounts({}) --[[@as MM.Account[] ]]
      accounts = verifyListAccounts(accounts)
    end)

    test("InitializeSession2 for payment returns nil", function()
      local challenge = InitializeSession2(
        ProtocolWebBanking,
        "YAXI Demo",
        1,
        { "result", "" } --[[@as MM.Credentials]],
        true,
        {},
        "payment"
      )
      assert.is_nil(challenge)
    end)

    test("SubmitPayment step=1 returns accepted (no SCA)", function()
      ---@diagnostic disable-next-line: need-check-nil, param-type-mismatch
      local result = SubmitPayment(1, accounts[1], payment, nil, nil)
      assert.is_table(result)
      ---@cast result table
      assert.are.equal("accepted", result.status)
      assert.is_string(result.orderId)
    end)

    test("EndSession succeeds", function()
      EndSession()
    end)
  end)

  --endregion SubmitPayment — result

  --region SubmitPayment — confirmation (polling)

  context("SubmitPayment — confirmation (polling)", function()
    setup(resetState)

    ---@type MM.Account[]?
    local accounts

    ---@type MM.Payment
    local payment = {
      type = PaymentTypeTransfer,
      name = "Max Mustermann",
      accountNumber = "NL58YAXI1234567890",
      amount = 1.00,
      currency = "EUR",
      purpose = "Test transfer",
    }

    test("InitializeSession2 sets up session (new account)", function()
      local challenge = InitializeSession2(
        ProtocolWebBanking,
        "YAXI Demo",
        1,
        { "result", "" } --[[@as MM.Credentials]],
        true,
        {},
        "new account"
      )
      assert.is_nil(challenge)
    end)

    test("ListAccounts returns accounts", function()
      accounts = ListAccounts({}) --[[@as MM.Account[] ]]
      accounts = verifyListAccounts(accounts)
    end)

    test("InitializeSession2 for payment (confirmation user)", function()
      local challenge = InitializeSession2(
        ProtocolWebBanking,
        "YAXI Demo",
        1,
        { "confirmation", "" } --[[@as MM.Credentials]],
        true,
        {},
        "payment"
      )
      assert.is_nil(challenge)
    end)

    test("SubmitPayment step=1 returns poll challenge", function()
      ---@diagnostic disable-next-line: need-check-nil, param-type-mismatch
      local result = SubmitPayment(1, accounts[1], payment, nil, nil)
      assert.is_table(result)
      ---@cast result table
      assert.is_truthy(result.poll)
      assert.is_string(result.challenge)
      assert.is_string(result.orderId)
    end)

    test("SubmitPayment step=2 resolves to accepted", function()
      ---@diagnostic disable-next-line: need-check-nil, param-type-mismatch
      local result = SubmitPayment(2, accounts[1], payment, nil, { "", "", true } --[[@as MM.Credentials]])
      assert.is_table(result)
      ---@cast result table
      assert.are.equal("accepted", result.status)
      assert.is_string(result.orderId)
    end)

    test("EndSession succeeds", function()
      EndSession()
    end)
  end)

  --endregion SubmitPayment — confirmation

  --region SubmitPayment — selection (auto-select TAN)

  context("SubmitPayment — selection (auto-select TAN)", function()
    setup(resetState)

    ---@type MM.Account[]?
    local accounts

    ---@type MM.Payment
    local payment = {
      type = PaymentTypeTransfer,
      name = "Max Mustermann",
      accountNumber = "NL58YAXI1234567890",
      amount = 1.00,
      currency = "EUR",
      purpose = "Test transfer",
    }

    test("InitializeSession2 sets up session (new account)", function()
      local challenge = InitializeSession2(
        ProtocolWebBanking,
        "YAXI Demo",
        1,
        { "result", "" } --[[@as MM.Credentials]],
        true,
        {},
        "new account"
      )
      assert.is_nil(challenge)
    end)

    test("ListAccounts returns accounts", function()
      accounts = ListAccounts({}) --[[@as MM.Account[] ]]
      accounts = verifyListAccounts(accounts)
    end)

    test("InitializeSession2 for payment (selection user)", function()
      local challenge = InitializeSession2(
        ProtocolWebBanking,
        "YAXI Demo",
        1,
        { "selection", "" } --[[@as MM.Credentials]],
        true,
        {},
        "payment"
      )
      assert.is_nil(challenge)
    end)

    test("SubmitPayment step=1 auto-selects TAN and resolves", function()
      ---@diagnostic disable-next-line: need-check-nil, param-type-mismatch
      local result = SubmitPayment(1, accounts[1], payment, {
        name = "appTAN",
        hbciMethod = "900",
      }, nil)
      assert.is_table(result)
      ---@cast result table
      -- Auto-selection should resolve the Selection and return accepted or next interrupt
      assert.is_truthy(result.status == "accepted" or result.poll or result.challenge)
    end)

    test("EndSession succeeds", function()
      EndSession()
    end)
  end)

  --endregion SubmitPayment — selection

  --region SubmitPayment — input (TAN entry)

  context("SubmitPayment — input (TAN entry)", function()
    setup(resetState)

    ---@type MM.Account[]?
    local accounts

    ---@type MM.Payment
    local payment = {
      type = PaymentTypeTransfer,
      name = "Max Mustermann",
      accountNumber = "NL58YAXI1234567890",
      amount = 1.00,
      currency = "EUR",
      purpose = "Test transfer",
    }

    test("InitializeSession2 sets up session (new account)", function()
      local challenge = InitializeSession2(
        ProtocolWebBanking,
        "YAXI Demo",
        1,
        { "result", "" } --[[@as MM.Credentials]],
        true,
        {},
        "new account"
      )
      assert.is_nil(challenge)
    end)

    test("ListAccounts returns accounts", function()
      accounts = ListAccounts({}) --[[@as MM.Account[] ]]
      accounts = verifyListAccounts(accounts)
    end)

    test("InitializeSession2 for payment (input user)", function()
      local challenge = InitializeSession2(
        ProtocolWebBanking,
        "YAXI Demo",
        1,
        { "input", "" } --[[@as MM.Credentials]],
        true,
        {},
        "payment"
      )
      assert.is_nil(challenge)
    end)

    test("SubmitPayment step=1 returns TAN challenge", function()
      ---@diagnostic disable-next-line: need-check-nil, param-type-mismatch
      local result = SubmitPayment(1, accounts[1], payment, nil, nil)
      assert.is_table(result)
      ---@cast result table
      assert.is_truthy(result.challenge)
    end)

    test("SubmitPayment step=2 resolves to accepted", function()
      ---@diagnostic disable-next-line: need-check-nil, param-type-mismatch
      local result = SubmitPayment(2, accounts[1], payment, nil, { "123456" } --[[@as MM.Credentials]])
      assert.is_table(result)
      ---@cast result table
      assert.are.equal("accepted", result.status)
    end)

    test("EndSession succeeds", function()
      EndSession()
    end)
  end)

  --endregion SubmitPayment — input

  --region SubmitPayment — redirect (OAuth)

  context("SubmitPayment — redirect (OAuth)", function()
    setup(resetState)

    ---@type MM.Account[]?
    local accounts

    ---@type MM.Payment
    local payment = {
      type = PaymentTypeTransfer,
      name = "Max Mustermann",
      accountNumber = "NL58YAXI1234567890",
      amount = 1.00,
      currency = "EUR",
      purpose = "Test transfer",
    }

    test("InitializeSession2 sets up session (new account)", function()
      local challenge = InitializeSession2(
        ProtocolWebBanking,
        "YAXI Demo",
        1,
        { "result", "" } --[[@as MM.Credentials]],
        true,
        {},
        "new account"
      )
      assert.is_nil(challenge)
    end)

    test("ListAccounts returns accounts", function()
      accounts = ListAccounts({}) --[[@as MM.Account[] ]]
      accounts = verifyListAccounts(accounts)
    end)

    test("InitializeSession2 for payment (redirect user)", function()
      local challenge = InitializeSession2(
        ProtocolWebBanking,
        "YAXI Demo",
        1,
        { "redirect", "" } --[[@as MM.Credentials]],
        true,
        {},
        "payment"
      )
      assert.is_nil(challenge)
    end)

    test("SubmitPayment step=1 returns redirect URL", function()
      ---@diagnostic disable-next-line: need-check-nil, param-type-mismatch
      local result = SubmitPayment(1, accounts[1], payment, nil, nil)
      assert.is_table(result)
      ---@cast result table
      assert.is_string(result.challenge)
      ---@cast result { challenge: string }
      assert.is_truthy(result.challenge:find("https://"))
    end)

    test("SubmitPayment step=2 resolves redirect to accepted", function()
      ---@diagnostic disable-next-line: need-check-nil, param-type-mismatch
      local result = SubmitPayment(2, accounts[1], payment, nil, { "demo-auth-code" } --[[@as MM.Credentials]])
      assert.is_table(result)
      ---@cast result table
      assert.are.equal("accepted", result.status)
    end)

    test("EndSession succeeds", function()
      EndSession()
    end)
  end)

  --endregion SubmitPayment — redirect

  --region SubmitPayment — random (all interrupt types)

  context("SubmitPayment — random (all interrupt types)", function()
    setup(resetState)

    ---@type MM.Account[]?
    local accounts

    ---@type MM.Payment
    local payment = {
      type = PaymentTypeTransfer,
      name = "Max Mustermann",
      accountNumber = "NL58YAXI1234567890",
      amount = 1.00,
      currency = "EUR",
      purpose = "Test transfer",
    }

    ---Build credentials for step N based on the challenge from step N-1.
    ---@param res table
    ---@return MM.Credentials
    local function credentialsForPaymentChallenge(res)
      if res.poll then
        return { "", "", true }
      elseif type(res.challenge) == "string" and res.challenge:find("https://") then
        return { "demo-auth-code" } --[[@as MM.Credentials]]
      else
        return { "123456" } --[[@as MM.Credentials]]
      end
    end

    test("InitializeSession2 sets up session (new account)", function()
      local challenge = InitializeSession2(
        ProtocolWebBanking,
        "YAXI Demo",
        1,
        { "result", "" } --[[@as MM.Credentials]],
        true,
        {},
        "new account"
      )
      assert.is_nil(challenge)
    end)

    test("ListAccounts returns accounts", function()
      accounts = ListAccounts({}) --[[@as MM.Account[] ]]
      accounts = verifyListAccounts(accounts)
    end)

    test("InitializeSession2 for payment (random user)", function()
      local challenge = InitializeSession2(
        ProtocolWebBanking,
        "YAXI Demo",
        1,
        { "random", "" } --[[@as MM.Credentials]],
        true,
        {},
        "payment"
      )
      assert.is_nil(challenge)
    end)

    test("SubmitPayment resolves through random interrupts", function()
      -- MoneyMoney passes the selected tanMethod on every step
      local tanMethod = {
        name = "appTAN",
        hbciMethod = "900",
      }

      ---@diagnostic disable-next-line: need-check-nil, param-type-mismatch
      local res = SubmitPayment(1, accounts[1], payment, tanMethod, nil)
      assert.is_table(res)
      ---@cast res table

      local step = 2
      while res.status ~= "accepted" do
        local creds = credentialsForPaymentChallenge(res)
        ---@diagnostic disable-next-line: need-check-nil, param-type-mismatch
        res = SubmitPayment(step, accounts[1], payment, tanMethod, creds)
        assert.is_table(res)
        ---@cast res table
        step = step + 1
        assert.is_true(step <= 10)
      end

      assert.are.equal("accepted", res.status)
    end)

    test("EndSession succeeds", function()
      EndSession()
    end)
  end)

  --endregion SubmitPayment — random

  --region Trace writing

  context("Trace writing", function()
    local tmpdir = (os.getenv("TMPDIR") or "/tmp"):gsub("/+$", "")

    setup(function()
      resetState()
      local handle = io.popen(string.format("rm -f %q/trace_*.age.txt", tmpdir))
      ---@diagnostic disable-next-line: unnecessary-if
      if handle then
        handle:close()
      end
    end)

    ---@return string[]
    local function listTraces()
      local handle = io.popen(string.format("ls -1 %q/trace_*.age.txt 2>/dev/null", tmpdir))
      if not handle then
        return {}
      end
      local files = {}
      for line in handle:lines() do
        files[#files + 1] = line
      end
      handle:close()
      return files
    end

    test("writes error trace with _error_ tag", function()
      -- Use invalid credentials to trigger an error on the first API call
      local result = InitializeSession2(
        ProtocolWebBanking,
        "YAXI Demo",
        1,
        { "", "" } --[[@as MM.Credentials]],
        true,
        {},
        "new account"
      )
      assert.is_string(result)

      local traces = listTraces()
      assert.is_true(#traces >= 1)

      local hasErrorTrace = false
      for _, path in ipairs(traces) do
        if path:match("_error_") then
          hasErrorTrace = true
          break
        end
      end
      assert.is_true(hasErrorTrace)
    end)
  end)

  --endregion Trace writing
end)
