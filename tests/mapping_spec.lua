-- SPDX-License-Identifier: MIT
-- Unit tests for YAXI mapping modules (balance, transaction, account).

dofile("tests/mm_env.lua")

local assert = require("luassert") ---@type luassert
local fixtures = require("tests.fixtures")

local accountMapping = require("yaxi.mapping.account")
local balanceMapping = require("yaxi.mapping.balance")
local transactionMapping = require("yaxi.mapping.transaction")

local TX_VISA_CARD = fixtures.TX_VISA_CARD
local TX_SALARY = fixtures.TX_SALARY
local TX_DIRECT_DEBIT = fixtures.TX_DIRECT_DEBIT
local TX_STANDING_ORDER = fixtures.TX_STANDING_ORDER

-- ---------------------------------------------------------------------------
-- Balance mapping
-- ---------------------------------------------------------------------------
context("yaxi.mapping.balance", function()
  context("pickBalance", function()
    test("returns Booked as primary and Available delta as pending", function()
      ---@diagnostic disable-next-line: missing-fields, param-type-mismatch
      local result = balanceMapping.pickBalance({
        { balanceType = "Booked", amount = "1000.50", currency = "EUR" },
        { balanceType = "Available", amount = "900.00", currency = "EUR" },
      })
      assert.are_equal(1000.50, result.balance)
      assert.are_equal(-100.50, result.pendingBalance)
    end)

    test("returns Available as primary when Booked is missing", function()
      ---@diagnostic disable-next-line: missing-fields, param-type-mismatch
      local result = balanceMapping.pickBalance({
        { balanceType = "Available", amount = "500.00", currency = "EUR" },
      })
      assert.are_equal(500.00, result.balance)
      assert.is_nil(result.pendingBalance)
    end)

    test("returns balance=0 for nil input", function()
      local result = balanceMapping.pickBalance(nil)
      assert.are_equal(0, result.balance)
      assert.is_nil(result.pendingBalance)
    end)

    test("uses Expected as primary when Booked is missing (Expected > Available priority)", function()
      ---@diagnostic disable-next-line: missing-fields, param-type-mismatch
      local result = balanceMapping.pickBalance({
        { balanceType = "Available", amount = "800.00", currency = "EUR" },
        { balanceType = "Expected", amount = "750.00", currency = "EUR" },
      })
      assert.are_equal(750.00, result.balance)
      assert.is_nil(result.pendingBalance)
    end)

    test("uses Expected as pending fallback when Available has creditLimitIncluded (unicredit/de pattern)", function()
      -- Booked(false) + Available(creditLimit) + Expected(false):
      -- Available must not be used as pending because it is credit-limit-inflated.
      ---@diagnostic disable-next-line: missing-fields, param-type-mismatch
      local result = balanceMapping.pickBalance({
        { balanceType = "Booked", amount = "29944.00", currency = "EUR", creditLimitIncluded = false },
        { balanceType = "Available", amount = "234567.89", currency = "EUR", creditLimitIncluded = true },
        { balanceType = "Expected", amount = "123456.78", currency = "EUR", creditLimitIncluded = false },
      })
      assert.are_equal(29944.00, result.balance)
      assert.are_equal(93512.78, result.pendingBalance)
    end)

    test("surfaces creditLimitIncluded Available delta as pending (fi/Sparkassen pattern)", function()
      -- Booked(false) + Available(creditLimit): delta includes the credit line.
      ---@diagnostic disable-next-line: missing-fields, param-type-mismatch
      local result = balanceMapping.pickBalance({
        { balanceType = "Booked", amount = "800.00", currency = "EUR", creditLimitIncluded = false },
        { balanceType = "Available", amount = "1800.00", currency = "EUR", creditLimitIncluded = true },
      })
      assert.are_equal(800.00, result.balance)
      assert.are_equal(1000.00, result.pendingBalance)
    end)

    test("prefers creditLimitIncluded=false over true within the same type (vwbank pattern)", function()
      -- Two Booked entries — the one without credit limit must win regardless of order.
      ---@diagnostic disable-next-line: missing-fields, param-type-mismatch
      local result = balanceMapping.pickBalance({
        { balanceType = "Booked", amount = "8301.93", currency = "EUR", creditLimitIncluded = true },
        { balanceType = "Booked", amount = "7301.93", currency = "EUR", creditLimitIncluded = false },
      })
      assert.are_equal(7301.93, result.balance)
      assert.is_nil(result.pendingBalance)
    end)

    test("prefers creditLimitIncluded=false across types (santander pattern)", function()
      -- Available(creditLimit) + Expected(false): Expected must be picked as primary
      -- because it is the only entry without a credit line, even though Available
      -- would normally have higher priority.
      ---@diagnostic disable-next-line: missing-fields, param-type-mismatch
      local result = balanceMapping.pickBalance({
        { balanceType = "Available", amount = "180387.25", currency = "EUR", creditLimitIncluded = true },
        { balanceType = "Expected", amount = "175387.25", currency = "EUR", creditLimitIncluded = false },
      })
      assert.are_equal(175387.25, result.balance)
      assert.is_nil(result.pendingBalance)
    end)

    test("falls back to creditLimitIncluded=true for primary when no clean entry exists", function()
      ---@diagnostic disable-next-line: missing-fields, param-type-mismatch
      local result = balanceMapping.pickBalance({
        { balanceType = "Available", amount = "500.00", currency = "EUR", creditLimitIncluded = true },
      })
      assert.are_equal(500.00, result.balance)
      assert.is_nil(result.pendingBalance)
    end)

    test("computes pending delta when both primary and pending have creditLimitIncluded=true", function()
      ---@diagnostic disable-next-line: missing-fields, param-type-mismatch
      local result = balanceMapping.pickBalance({
        { balanceType = "Booked", amount = "100.00", currency = "EUR", creditLimitIncluded = true },
        { balanceType = "Expected", amount = "140.00", currency = "EUR", creditLimitIncluded = true },
      })
      assert.are_equal(100.00, result.balance)
      assert.are_equal(40.00, result.pendingBalance)
    end)
  end)
end)

-- ---------------------------------------------------------------------------
-- Transaction mapping
-- ---------------------------------------------------------------------------
context("yaxi.mapping.transaction", function()
  local connection = { transactionCodePreference = nil } ---@type any

  context("mapTransaction", function()
    test("maps a direct debit with mandate and creditor ID", function()
      local result = transactionMapping.mapTransaction(TX_DIRECT_DEBIT, connection)
      assert.is_not_nil(result)
      ---@cast result -nil
      assert.are_equal(-5.99, result.amount)
      assert.are_equal("EUR", result.currency)
      assert.is_true(result.booked)
      -- Negative amount → creditor is counterparty
      assert.are_equal("PayPal Europe S.a.r.l. et Cie S.C.A", result.name)
      assert.are_equal("LU89751000135104200E", result.accountNumber)
      assert.are_equal("0057780300544/PP.1196.PP/. Spotify AB, Ihr Einkauf bei Spotify AB", result.purpose)
      assert.are_equal("0057780300544", result.endToEndReference)
      assert.are_equal("P6PYPY6Y5N2YU", result.mandateReference)
      assert.are_equal("LU96ZZZ0000000000000000058", result.creditorId)
    end)

    test("uses debtor as counterparty for credit (salary)", function()
      local result = transactionMapping.mapTransaction(TX_SALARY, connection)
      assert.is_not_nil(result)
      ---@cast result -nil
      assert.are_equal(3656.58, result.amount)
      -- Positive amount → debtor is counterparty
      assert.are_equal("DATEV eG", result.name)
      assert.are_equal("DE30760501010001519387", result.accountNumber)
      assert.are_equal("Lohn - Gehalt Abrechnung 07/2025", result.purpose)
    end)

    test("maps standing order with Unicode characters", function()
      local result = transactionMapping.mapTransaction(TX_STANDING_ORDER, connection)
      assert.is_not_nil(result)
      ---@cast result -nil
      assert.are_equal(-1000, result.amount)
      assert.are_equal("Stefanie Müller-Schmitt", result.name)
      assert.are_equal("DE89370400440532013000", result.accountNumber)
      assert.are_equal("Miete inkl. Betriebskosten, Flurstr. 4, Wohnungsnr. 5, Nürnberg", result.purpose)
      assert.are_equal("RINP", result.purposeCode)
    end)

    test("extracts bookingText from bankTransactionCodes", function()
      -- Our mock TransactionCode returns { name = code }, so swift "STO" → bookingText "STO"
      local result = transactionMapping.mapTransaction(TX_STANDING_ORDER, connection)
      assert.is_not_nil(result)
      ---@cast result -nil
      -- iso subFamily "STDO" is tried first and wins
      assert.are_equal("STDO", result.bookingText)
    end)

    test("prefers transaction code type from connection preference", function()
      local conn = { transactionCodePreference = { "swift" } } ---@type any
      local result = transactionMapping.mapTransaction(TX_VISA_CARD, conn)
      assert.is_not_nil(result)
      ---@cast result -nil
      assert.are_equal("DDT", result.bookingText)
    end)

    test("returns nil when amount is missing", function()
      local tx = { transactionId = "tx-no-amount" } ---@type any
      local result = transactionMapping.mapTransaction(tx, connection)
      assert.is_nil(result)
    end)

    test("sets booked=false for non-Booked status", function()
      -- Synthetic: no real Pending transactions in demo data
      local tx = {
        amount = { amount = "10.00", currency = "EUR" },
        status = "Pending",
        bookingDate = "2025-07-01",
      }
      local result = transactionMapping.mapTransaction(tx, connection)
      assert.is_not_nil(result)
      ---@cast result -nil
      assert.are_equal(false, result.booked)
    end)

    test("falls back to transactionDate when bookingDate is missing", function()
      -- Synthetic edge case: some banks omit bookingDate for pending transactions
      local tx = {
        amount = { amount = "50.00", currency = "EUR" },
        status = "Booked",
        transactionDate = "2025-07-15",
      }
      local result = transactionMapping.mapTransaction(tx, connection)
      assert.is_not_nil(result)
      ---@cast result -nil
      -- Verify the date roundtrips correctly through UTC conversion
      assert.are_equal("2025-07-15", os.date("!%Y-%m-%d", result.bookingDate))
    end)
  end)
end)

-- ---------------------------------------------------------------------------
-- Account mapping
-- ---------------------------------------------------------------------------
context("yaxi.mapping.account", function()
  context("mapAccount", function()
    local paymentTypes = { PaymentTypeTransfer, PaymentTypeInstantTransfer }
    local connection = { bic = "COBADEHDXXX", paymentTypes = paymentTypes } ---@type any

    test("maps Current account with fallback BIC", function()
      local yaxiAccount = {
        type = "Current",
        iban = "DE02120300000000202051",
        currency = "EUR",
        name = "Girokonto",
      }
      local result = accountMapping.mapAccount(yaxiAccount, connection)
      assert.are_equal(AccountTypeGiro, result.type)
      assert.are_equal("DE02120300000000202051", result.iban)
      assert.are_equal("EUR", result.currency)
      assert.are_equal("Girokonto", result.name)
      assert.are_equal("COBADEHDXXX", result.bic)
    end)

    test("maps Securities type to AccountTypePortfolio with portfolio=true", function()
      local result = accountMapping.mapAccount({
        type = "Securities",
        iban = "DE89370400440532013000",
        currency = "EUR",
        name = "Depot",
      }, connection)
      assert.are_equal(AccountTypePortfolio, result.type)
      assert.is_true(result.portfolio)
    end)

    test("sets type to nil for an unknown account type", function()
      local result = accountMapping.mapAccount({
        ---@diagnostic disable-next-line: assign-type-mismatch
        type = "Exotic",
        iban = "DE89370400440532013000",
        currency = "EUR",
        name = "Unknown",
      }, connection)
      assert.is_nil(result.type)
    end)

    test("uses account BIC when present", function()
      local result = accountMapping.mapAccount({
        type = "Current",
        iban = "DE02120300000000202051",
        bic = "BYLADEM1001",
        currency = "EUR",
        name = "Konto",
      }, connection)
      assert.are_equal("BYLADEM1001", result.bic)
    end)

    test("assigns paymentTypes when capabilities include SinglePayment", function()
      local result = accountMapping.mapAccount({
        type = "Current",
        iban = "DE02120300000000202051",
        currency = "EUR",
        name = "With Payment",
        capabilities = { "SinglePayment", "AccountDetails" },
      }, connection)
      ---@diagnostic disable-next-line: undefined-field
      assert.are_same(paymentTypes, result.paymentTypes)
    end)

    test("omits paymentTypes when capabilities lack SinglePayment", function()
      local result = accountMapping.mapAccount({
        type = "Current",
        iban = "DE02120300000000202051",
        currency = "EUR",
        name = "Read-only",
        capabilities = { "AccountDetails", "Balances" },
      }, connection)
      ---@diagnostic disable-next-line: undefined-field
      assert.is_nil(result.paymentTypes)
    end)
  end)
end)
