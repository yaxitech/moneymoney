-- SPDX-License-Identifier: MIT
-- Unit tests for YAXI mapping modules (balance, transaction, account).

dofile("tests/mm_env.lua")

local assert = require("luassert") ---@type luassert
local fixtures = require("tests.fixtures")

local accountMapping = require("yaxi.mapping.account")
local balanceMapping = require("yaxi.mapping.balance")
local standingOrderMapping = require("yaxi.mapping.standing_order")
local transactionMapping = require("yaxi.mapping.transaction")

local TX_VISA_CARD = fixtures.TX_VISA_CARD
local TX_SALARY = fixtures.TX_SALARY
local TX_DIRECT_DEBIT = fixtures.TX_DIRECT_DEBIT
local TX_STANDING_ORDER = fixtures.TX_STANDING_ORDER
local SO_RENT = fixtures.SO_RENT
local SO_BROADCASTING = fixtures.SO_BROADCASTING

---Calendar days shown for a date across all time zones (UTC-12 to UTC+14).
---Without `timezone`, the day follows the user's time zone.
---@param timestamp integer?
---@param timezone string?
---@return string[]
local function shownDays(timestamp, timezone)
  if not timestamp then
    return {}
  end
  if timezone == "UTC" or timezone == "GMT" then
    return {
      os.date("!%Y-%m-%d", timestamp) --[[@as string]],
    }
  end
  local days = {}
  for _, offset in ipairs({ -12, 14 }) do
    local day = os.date("!%Y-%m-%d", timestamp + offset * 3600) --[[@as string]]
    if days[#days] ~= day then
      table.insert(days, day)
    end
  end
  return days
end

-- ---------------------------------------------------------------------------
-- Balance mapping
-- ---------------------------------------------------------------------------
context("yaxi.mapping.balance", function()
  context("pickBalance", function()
    local NOW = "2026-07-21T00:00:00Z"

    test("returns Booked as primary and Available delta as pending", function()
      local result = balanceMapping.pickBalance({
        { balanceType = "Booked", amount = "1000.50", currency = "EUR" },
        { balanceType = "Available", amount = "900.00", currency = "EUR" },
      })
      assert.are_equal(1000.50, result.balance)
      assert.are_equal(-100.50, result.pendingBalance)
    end)

    test("returns Available as primary when Booked is missing", function()
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
      local result = balanceMapping.pickBalance({
        { balanceType = "Booked", amount = "800.00", currency = "EUR", creditLimitIncluded = false },
        { balanceType = "Available", amount = "1800.00", currency = "EUR", creditLimitIncluded = true },
      })
      assert.are_equal(800.00, result.balance)
      assert.are_equal(1000.00, result.pendingBalance)
    end)

    test("prefers creditLimitIncluded=false over true within the same type (vwbank pattern)", function()
      -- Two Booked entries — the one without credit limit must win regardless of order.
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
      local result = balanceMapping.pickBalance({
        { balanceType = "Available", amount = "180387.25", currency = "EUR", creditLimitIncluded = true },
        { balanceType = "Expected", amount = "175387.25", currency = "EUR", creditLimitIncluded = false },
      })
      assert.are_equal(175387.25, result.balance)
      assert.is_nil(result.pendingBalance)
    end)

    test("falls back to creditLimitIncluded=true for primary when no clean entry exists", function()
      local result = balanceMapping.pickBalance({
        { balanceType = "Available", amount = "500.00", currency = "EUR", creditLimitIncluded = true },
      })
      assert.are_equal(500.00, result.balance)
      assert.is_nil(result.pendingBalance)
    end)

    test("computes pending delta when both primary and pending have creditLimitIncluded=true", function()
      local result = balanceMapping.pickBalance({
        { balanceType = "Booked", amount = "100.00", currency = "EUR", creditLimitIncluded = true },
        { balanceType = "Expected", amount = "140.00", currency = "EUR", creditLimitIncluded = true },
      })
      assert.are_equal(100.00, result.balance)
      assert.are_equal(40.00, result.pendingBalance)
    end)

    test("picks the freshest Booked by dateTime (interim over closing)", function()
      -- A prior bookkeeping day's closing balance and a fresher interim one: the later
      -- dateTime wins, regardless of reported order.
      local result = balanceMapping.pickBalance({
        { balanceType = "Booked", amount = "1000.00", currency = "EUR", dateTime = "2026-07-19T23:59:59Z" },
        { balanceType = "Booked", amount = "1200.00", currency = "EUR", dateTime = "2026-07-20T08:00:00Z" },
      }, NOW)
      assert.are_equal(1200.00, result.balance)
      assert.is_nil(result.pendingBalance)
    end)

    test("lets a fresher Available outrank an older Booked (recency wins across types)", function()
      -- The freshest entry wins regardless of type; Booked no longer takes priority
      -- over a more recent Available.
      local result = balanceMapping.pickBalance({
        { balanceType = "Booked", amount = "1000.00", currency = "EUR", dateTime = "2026-07-19T00:00:00Z" },
        { balanceType = "Available", amount = "1020.00", currency = "EUR", dateTime = "2026-07-20T08:00:00Z" },
      }, NOW)
      assert.are_equal(1020.00, result.balance)
      assert.is_nil(result.pendingBalance)
    end)

    test("prefers Booked over Available on an equal dateTime, with the freshest pending delta", function()
      -- Booked and Available share the newest dateTime, so Booked stays primary; the
      -- fresher of the two Available entries drives the pending delta.
      local result = balanceMapping.pickBalance({
        { balanceType = "Booked", amount = "500.00", currency = "EUR", dateTime = "2026-07-20T08:00:00Z" },
        { balanceType = "Available", amount = "480.00", currency = "EUR", dateTime = "2026-07-19T23:00:00Z" },
        { balanceType = "Available", amount = "530.00", currency = "EUR", dateTime = "2026-07-20T08:00:00Z" },
      }, NOW)
      assert.are_equal(500.00, result.balance)
      assert.are_equal(30.00, result.pendingBalance)
    end)

    test("ignores a dateTime in the future", function()
      -- A balance not yet valid (dateTime > now) is skipped in favor of the freshest
      -- past one.
      local result = balanceMapping.pickBalance({
        { balanceType = "Booked", amount = "1000.00", currency = "EUR", dateTime = "2026-07-22T00:00:00Z" },
        { balanceType = "Booked", amount = "900.00", currency = "EUR", dateTime = "2026-07-20T08:00:00Z" },
      }, NOW)
      assert.are_equal(900.00, result.balance)
      assert.is_nil(result.pendingBalance)
    end)

    test("skips entries without a dateTime for the guideline pick", function()
      -- The guideline considers only dated entries; a Booked without a dateTime loses
      -- to a dated one.
      local result = balanceMapping.pickBalance({
        { balanceType = "Booked", amount = "700.00", currency = "EUR" },
        { balanceType = "Booked", amount = "750.00", currency = "EUR", dateTime = "2026-07-20T08:00:00Z" },
      }, NOW)
      assert.are_equal(750.00, result.balance)
      assert.is_nil(result.pendingBalance)
    end)

    test("keeps a balance stamped slightly ahead of the local clock", function()
      -- Current-state balances carry the retrieval time; a client clock
      -- running a few seconds behind must not fall back to a stale entry.
      local aheadNow = os.date("!%Y-%m-%dT%H:%M:%S.500000000Z", os.time() + 2)
      local result = balanceMapping.pickBalance({
        { balanceType = "Booked", amount = "1000.00", currency = "EUR", dateTime = "2026-01-15T00:00:00.000000000Z" },
        { balanceType = "Available", amount = "8877.78", currency = "EUR", dateTime = aheadNow },
      })
      assert.are_equal(8877.78, result.balance)
    end)

    test("falls back to the type scan when no entry carries a dateTime", function()
      -- Without any dateTime the guideline cannot apply, so the Booked > Available type
      -- priority still selects the primary.
      local result = balanceMapping.pickBalance({
        { balanceType = "Available", amount = "900.00", currency = "EUR" },
        { balanceType = "Booked", amount = "1000.00", currency = "EUR" },
      }, NOW)
      assert.are_equal(1000.00, result.balance)
      assert.are_equal(-100.00, result.pendingBalance)
    end)
  end)
end)

-- ---------------------------------------------------------------------------
-- Transaction mapping
-- ---------------------------------------------------------------------------
context("yaxi.mapping.transaction", function()
  ---@param tx table
  ---@return MM.Transaction
  local function map(tx)
    tx.amount = tx.amount or { amount = "-10.00", currency = "EUR" }
    tx.status = tx.status or "Booked"
    local result = transactionMapping.mapTransaction(tx --[[@as YAXI.RoutexClient.Result.Transaction]])
    ---@cast result -nil
    return result
  end

  context("mapTransaction", function()
    test("maps a direct debit with mandate and creditor ID", function()
      local result = transactionMapping.mapTransaction(TX_DIRECT_DEBIT)
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
      -- German GVC and SWIFT booking key from the bank transaction codes
      assert.are_equal(105, result.transactionCode)
      assert.are_equal("DDT", result.bookingKey)
    end)

    test("uses debtor as counterparty for credit (salary)", function()
      local result = transactionMapping.mapTransaction(TX_SALARY)
      assert.is_not_nil(result)
      ---@cast result -nil
      assert.are_equal(3656.58, result.amount)
      -- Positive amount → debtor is counterparty
      assert.are_equal("DATEV eG", result.name)
      assert.are_equal("DE30760501010001519387", result.accountNumber)
      assert.are_equal("Lohn - Gehalt Abrechnung 07/2025", result.purpose)
    end)

    test("maps standing order with Unicode characters", function()
      local result = transactionMapping.mapTransaction(TX_STANDING_ORDER)
      assert.is_not_nil(result)
      ---@cast result -nil
      assert.are_equal(-1000, result.amount)
      assert.are_equal("Stefanie Müller-Schmitt", result.name)
      assert.are_equal("DE89370400440532013000", result.accountNumber)
      assert.are_equal("Miete inkl. Betriebskosten, Flurstr. 4, Wohnungsnr. 5, Nürnberg", result.purpose)
      assert.are_equal("RINP", result.purposeCode)
      assert.are_equal(117, result.transactionCode)
      assert.are_equal("STO", result.bookingKey)
    end)

    test("prefers the German business transaction code for the booking text", function()
      -- The ISO and SWIFT codes in these fixtures contradict the GVC
      assert.are_equal("Lastschrift", map(TX_DIRECT_DEBIT).bookingText)
      assert.are_equal("Abwicklung von Kartenzahlungen", map(TX_VISA_CARD).bookingText)
      assert.are_equal("Lohn/Gehalt/Rente", map(TX_SALARY).bookingText)
    end)

    test("falls back to ISO, SWIFT, other, and purpose codes for the booking text", function()
      ---@param codes table[]
      ---@param purposeCode string?
      ---@return string?
      local function bookingText(codes, purposeCode)
        return map({ bankTransactionCodes = codes, purposeCode = purposeCode }).bookingText
      end
      local cardIso = { iso = { domain = "PMNT", family = "CCRD", subFamily = "POSD" } }
      assert.are_equal("point-of-sale payment debit card", bookingText({ { swift = "DDT" }, cardIso }))
      -- A placeholder subfamily falls back to the family
      local otherIso = { iso = { domain = "PMNT", family = "RCDT", subFamily = "OTHR" } }
      assert.are_equal("received credit transfers", bookingText({ otherIso }))
      assert.are_equal("Direct debit", bookingText({ { swift = "DDT" }, { other = { code = "Kartenzahlung" } } }))
      assert.are_equal("Überweisung", bookingText({ { other = { code = "NTRF+166" } } }))
      -- Codes for other countries are no GVC
      local foreign = { national = { code = "105", country = "AT" } }
      assert.are_equal("salary payment", bookingText({ foreign }, "SALA"))
      assert.is_nil(bookingText({}, "OTHR"))
    end)

    test("uses plain-text bank codes as the last resort for the booking text", function()
      ---@param code string
      ---@param fields table?
      ---@return string?
      local function bookingText(code, fields)
        local tx = fields or {}
        tx.bankTransactionCodes = { { other = { code = code } } }
        return map(tx).bookingText
      end
      assert.are_equal("EURO-Überweisung", bookingText("EURO-Überweisung"))
      assert.are_equal("SEPA-ÜBERWEISUNG", bookingText("SEPA-ÜBERWEISUNG"))
      assert.are_equal("Gutschrift Echtzeit", bookingText("Gutschrift Echtzeit"))
      assert.are_equal("next instalment", bookingText("Kartenzahlung", { additionalInformation = "next instalment" }))
      assert.are_equal("salary payment", bookingText("Kartenzahlung", { purposeCode = "SALA" }))
      -- Codes, not texts
      assert.is_nil(bookingText("4101000"))
      assert.is_nil(bookingText("NXYZ+999+9310"))
      assert.is_nil(bookingText("NXYZ"))
      assert.is_nil(bookingText("07/0085"))
    end)

    test("keeps the dates in every time zone", function()
      local result = map({ bookingDate = "2025-07-15", valueDate = "2025-07-16" })
      assert.are_same({ "2025-07-15" }, shownDays(result.bookingDate, result.timezone))
      assert.are_same({ "2025-07-16" }, shownDays(result.valueDate, result.timezone))
    end)

    test("picks the counterparty of the original transaction for reversals", function()
      -- Returned direct debit: the parties are those of the debit
      local returned = map({
        amount = { amount = "5.99", currency = "EUR" },
        reversal = true,
        creditor = { name = "PayPal Europe", iban = "LU89751000135104200E" },
        debtor = { name = "Peter Steiger", iban = fixtures.DEMO_IBAN },
      })
      assert.are_equal("PayPal Europe", returned.name)
      assert.are_equal("LU89751000135104200E", returned.accountNumber)

      local reversedCredit = map({
        amount = { amount = "-3656.58", currency = "EUR" },
        reversal = true,
        creditor = { name = "Peter Steiger", iban = fixtures.DEMO_IBAN },
        debtor = { name = "DATEV eG" },
      })
      assert.are_equal("DATEV eG", reversedCredit.name)
    end)

    test("drops placeholder end-to-end references", function()
      assert.is_nil(map({ endToEndId = "NOTPROVIDED" }).endToEndReference)
      assert.is_nil(map({ endToEndId = "NOT PROVIDED " }).endToEndReference)
      assert.are_equal("E2E-1", map({ endToEndId = "E2E-1" }).endToEndReference)
    end)

    test("does not repeat the purpose code in the purpose", function()
      local result = map({ purposeCode = "SALA" })
      assert.are_equal("salary payment", result.bookingText)
      assert.is_nil(result.purpose)
    end)

    test("adds the original amount, exchange rates, and fees to the purpose", function()
      local tx = {
        amount = { amount = "-11.38", currency = "EUR" },
        remittanceInformation = { "AMAZON.COM" },
        originalAmount = { amount = "-12.34", currency = "USD" },
        exchanges = {
          { sourceCurrency = "USD", targetCurrency = "EUR", unitCurrency = "USD", exchangeRate = "0.9221" },
        },
        fees = { { amount = { amount = "0.20", currency = "EUR" } } },
      }
      assert.are_equal(
        "AMAZON.COM\nOriginal amount: 12.34 USD\nExchange rate: 1 USD = 0.9221 EUR\nFee: 0.20 EUR",
        map(tx).purpose
      )

      MM.language = "de"
      local ok, result = pcall(map, { originalAmount = { amount = "12.34", currency = "USD" } })
      MM.language = "en"
      assert.is_true(ok)
      assert.are_equal("Originalbetrag: 12.34 USD", result.purpose)

      -- The rate's unit currency decides the direction
      local quoted = map({
        exchanges = {
          { sourceCurrency = "USD", targetCurrency = "EUR", unitCurrency = "EUR", exchangeRate = "1.0845" },
        },
      })
      assert.are_equal("Exchange rate: 1 EUR = 1.0845 USD", quoted.purpose)
      -- An original amount equal to the billed amount adds nothing
      assert.is_nil(map({ originalAmount = { amount = "-10.00", currency = "EUR" } }).purpose)
    end)

    test("returns nil when amount is missing", function()
      local tx = { transactionId = "tx-no-amount" } ---@type any
      local result = transactionMapping.mapTransaction(tx)
      assert.is_nil(result)
    end)

    test("derives booked from the transaction status", function()
      ---@param status string
      ---@return MM.Transaction?
      local function mapWithStatus(status)
        return transactionMapping.mapTransaction({
          amount = { amount = "10.00", currency = "EUR" },
          status = status,
          bookingDate = "2025-07-01",
        } --[[@as any]])
      end
      ---@diagnostic disable-next-line: need-check-nil
      assert.are_equal(false, mapWithStatus("Pending").booked)
      -- Invoiced and Paid are settled card/commerce states
      ---@diagnostic disable-next-line: need-check-nil
      assert.is_true(mapWithStatus("Invoiced").booked)
      ---@diagnostic disable-next-line: need-check-nil
      assert.is_true(mapWithStatus("Paid").booked)
      -- Canceled transactions are not reported at all
      assert.is_nil(mapWithStatus("Canceled"))
    end)

    test("falls back to transactionDate when bookingDate is missing", function()
      -- Synthetic edge case: some banks omit bookingDate for pending transactions
      local tx = {
        amount = { amount = "50.00", currency = "EUR" },
        status = "Booked",
        transactionDate = "2025-07-15",
      }
      local result = transactionMapping.mapTransaction(tx)
      assert.is_not_nil(result)
      ---@cast result -nil
      -- Verify the date roundtrips correctly through UTC conversion
      assert.are_equal("2025-07-15", os.date("!%Y-%m-%d", result.bookingDate))

      -- Pending transactions often carry only a value date
      local pending = transactionMapping.mapTransaction({
        amount = { amount = "20.00", currency = "EUR" },
        status = "Pending",
        valueDate = "2025-07-20",
      })
      ---@diagnostic disable-next-line: need-check-nil
      assert.are_equal("2025-07-20", os.date("!%Y-%m-%d", pending.bookingDate))
    end)
  end)
end)

context("yaxi.connections.dkb", function()
  local dkb = require("yaxi.connections").registry["YAXI DKB"]

  test("replaces dots in card merchant names", function()
    ---@param name string
    ---@return string?
    local function mappedName(name)
      local result = dkb:mapTransaction({
        status = "Booked",
        amount = { amount = "-1.94", currency = "EUR" },
        creditor = { name = name },
      })
      return result and result.name
    end
    assert.are_equal("Lekkerland REWE To Go/Nuernberg", mappedName("Lekkerland.REWE.To.Go/Nuernberg"))
    assert.are_equal("Dr. Peter Steiger", mappedName("Dr. Peter Steiger"))
    assert.are_equal("example.com", mappedName("example.com"))
  end)
end)

-- ---------------------------------------------------------------------------
-- Standing order mapping
-- ---------------------------------------------------------------------------
context("yaxi.mapping.standing_order", function()
  local TODAY = "2026-10-05"

  ---@param standingOrder table
  ---@param today string?
  ---@return MM.ScheduledPayment
  local function map(standingOrder, today)
    standingOrder.amount = standingOrder.amount or { amount = "10", currency = "EUR" }
    local result = standingOrderMapping.mapStandingOrder(standingOrder, today or TODAY)
    ---@cast result -nil
    return result
  end

  ---@param timestamp integer?
  ---@return string?
  local function date(timestamp)
    return timestamp and os.date("!%Y-%m-%d", timestamp)
  end

  test("maps a monthly standing order", function()
    local result = map(SO_RENT)
    assert.are_equal(PaymentTypeStandingOrder, result.type)
    assert.is_string(result.orderId)
    assert.are_equal("Stefanie Müller-Schmitt", result.name)
    assert.are_equal("DE89370400440532013000", result.accountNumber)
    assert.are_equal(1000, result.amount)
    assert.are_equal("EUR", result.currency)
    assert.are_equal("Miete inkl. Betriebskosten, Flurstr. 4, Wohnungsnr. 5, Nürnberg", result.purpose)
    assert.are_equal("RINP", result.purposeCode)
    assert.are_equal("2023-02-01", date(result.standingOrderStart))
    assert.is_nil(result.standingOrderEnd)
    assert.are_same({ "M", 1, 1 }, { result.standingOrderUnit, result.standingOrderPeriod, result.standingOrderDay })
    assert.are_equal("2026-11-01", date(result.scheduledDate))
  end)

  ---@param standingOrders table[]
  ---@return string[]
  local function orderIds(standingOrders)
    local ids = {}
    for _, payment in ipairs(standingOrderMapping.mapStandingOrders(standingOrders, TODAY)) do
      table.insert(ids, payment.orderId)
    end
    return ids
  end

  ---@param fields table
  ---@return table
  local function rent(fields)
    local so = {
      startDate = "2023-02-01",
      frequency = { months = 1 },
      amount = { amount = "1000", currency = "EUR" },
      creditor = { name = "Stefanie Müller-Schmitt", iban = "DE89370400440532013000" },
      remittanceInformation = { "Miete" },
    }
    for k, v in pairs(fields) do
      so[k] = v
    end
    return so
  end

  test("keeps the order ID when the amount or purpose changes", function()
    local id = orderIds({ rent({}) })[1]
    assert.are_equal(id, orderIds({ rent({ amount = { amount = "1050", currency = "EUR" } }) })[1])
    assert.are_equal(id, orderIds({ rent({ remittanceInformation = { "Miete 2027" } }) })[1])
    assert.are_not_equal(id, orderIds({ rent({ startDate = "2024-02-01" }) })[1])
    assert.are_not_equal(id, orderIds({ rent({ creditor = { iban = "DE02120300000000202051" } }) })[1])
  end)

  test("keeps order IDs unique for orders with the same start and creditor", function()
    local garage = rent({ amount = { amount = "80", currency = "EUR" } })
    local ids = orderIds({ rent({}), garage, rent({}) })
    assert.are_equal(3, #ids)
    assert.are_not_equal(ids[1], ids[2])
    assert.are_not_equal(ids[1], ids[3])
    assert.are_not_equal(ids[2], ids[3])
    -- An order without a twin keeps its own ID
    assert.are_equal(orderIds({ rent({}) })[1], orderIds({ rent({}), rent({ startDate = "2024-02-01" }) })[1])
  end)

  test("encodes the execution day", function()
    ---@param fields table
    ---@return integer?
    local function day(fields)
      return map(rent(fields)).standingOrderDay
    end
    assert.are_equal(15, day({ day = 15 }))
    -- 31 means the month's last day
    assert.are_equal(99, day({ day = 31 }))
    -- Without a day, the start date's day; for weekly orders its weekday
    assert.are_equal(1, day({}))
    assert.are_equal(99, day({ startDate = "2026-01-31" }))
    assert.are_equal(1, day({ startDate = "2026-01-05", frequency = { days = 7 } }))
    assert.are_equal(7, day({ startDate = "2026-01-11", frequency = { days = 14 } }))
    assert.is_nil(day({ startDate = "2026-01-05", frequency = { days = 10 } }))
  end)

  test("maps evenly spaced months to a monthly period", function()
    local result = map(SO_BROADCASTING)
    assert.are_same({ "M", 3 }, { result.standingOrderUnit, result.standingOrderPeriod })
    assert.are_equal("2027-01-01", date(result.scheduledDate))
  end)

  test("omits recurrences MoneyMoney cannot express", function()
    ---@param frequency table
    local function recurrence(frequency)
      local result = map({ startDate = "2026-01-05", frequency = frequency })
      return { result.standingOrderUnit, result.standingOrderPeriod }
    end
    assert.are_same({ "W", 2 }, recurrence({ days = 14 }))
    assert.are_same({}, recurrence({ days = 10 }))
    assert.are_same({}, recurrence({ months = 0 }))
    assert.are_same({}, recurrence({ variableMonths = { 1, 2, 6 } }))
  end)

  test("maps a standing order without a start date", function()
    ---@param fields table
    ---@param today string
    ---@return string?
    local function scheduled(fields, today)
      return date(map(fields, today).scheduledDate)
    end
    local monthly = map({ frequency = { months = 1 }, day = 15 }, "2026-10-20")
    assert.is_string(monthly.orderId)
    assert.is_nil(monthly.standingOrderStart)
    assert.are_equal("2026-11-15", date(monthly.scheduledDate))
    assert.are_equal("2026-11-01", scheduled({ frequency = { months = 1 }, day = 1 }, "2026-11-01"))
    assert.are_equal("2026-02-28", scheduled({ frequency = { months = 1 }, day = 31 }, "2026-02-10"))
    assert.are_equal("2026-01-05", scheduled({ frequency = { months = 1 }, day = 5 }, "2025-12-20"))
    assert.is_nil(scheduled({ endDate = "2026-10-31", frequency = { months = 1 }, day = 1 }, "2026-10-20"))
    -- Without a start, only monthly orders on a fixed day have a known next execution
    assert.is_nil(scheduled({ frequency = { months = 3 }, day = 1 }, "2026-10-20"))
    assert.is_nil(scheduled({ frequency = { days = 7 } }, "2026-10-20"))
    assert.is_nil(scheduled({ frequency = { months = 1 } }, "2026-10-20"))
  end)

  test("computes the next execution", function()
    -- Clamped to the month's last day
    local monthEnd = map({ startDate = "2026-01-31", frequency = { months = 1 }, day = 31 }, "2026-02-10")
    assert.are_equal("2026-02-28", date(monthEnd.scheduledDate))
    -- Execution on the day itself still counts
    local weekly = map({ startDate = "2026-01-05", frequency = { days = 14 } }, "2026-02-02")
    assert.are_equal("2026-02-02", date(weekly.scheduledDate))
    local upcoming = map({ startDate = "2026-12-01", frequency = { months = 1 }, day = 1 })
    assert.are_equal("2026-12-01", date(upcoming.scheduledDate))
    -- The last execution lies before the next one
    local lastBefore = map({ startDate = "2025-01-01", endDate = TODAY, frequency = { months = 1 }, day = 1 })
    assert.is_nil(lastBefore.scheduledDate)
  end)

  test("skips standing orders that have ended", function()
    local ended = { startDate = "2025-01-01", endDate = "2026-09-01", amount = { amount = "10", currency = "EUR" } }
    assert.is_nil(standingOrderMapping.mapStandingOrder(ended, TODAY))
  end)

  test("keeps the dates in every time zone", function()
    local result = map({ startDate = "2026-01-05", endDate = "2027-01-04", frequency = { days = 14 } })
    assert.are_same({ "2026-01-05" }, shownDays(result.standingOrderStart, result.timezone))
    assert.are_same({ "2027-01-04" }, shownDays(result.standingOrderEnd, result.timezone))
    assert.are_same({ "2026-10-12" }, shownDays(result.scheduledDate, result.timezone))
  end)

  test("drops placeholder end-to-end references", function()
    assert.is_nil(map({ startDate = "2026-01-05", endToEndId = "NOTPROVIDED" }).endToEndReference)
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

    test("does not inject paymentTypes onto MM.Account", function()
      local result = accountMapping.mapAccount({
        type = "Current",
        iban = "DE02120300000000202051",
        currency = "EUR",
        name = "With Payment",
        capabilities = { "SinglePayment", "Balances" },
      }, connection)
      ---@diagnostic disable-next-line: undefined-field
      assert.is_nil(result.paymentTypes)
    end)
  end)

  context("derivePaymentTypes", function()
    local paymentTypes = { PaymentTypeTransfer, PaymentTypeInstantTransfer }
    local connection = { bic = "COBADEHDXXX", paymentTypes = paymentTypes } ---@type any

    test("returns connection paymentTypes when capabilities include SinglePayment", function()
      local result = accountMapping.derivePaymentTypes({
        capabilities = { "SinglePayment", "Balances" },
      }, connection)
      assert.are_same(paymentTypes, result)
    end)

    test("returns nil when capabilities lack SinglePayment", function()
      local result = accountMapping.derivePaymentTypes({
        capabilities = { "Balances", "Transactions" },
      }, connection)
      assert.is_nil(result)
    end)

    test("returns connection paymentTypes when capabilities are absent", function()
      local result = accountMapping.derivePaymentTypes({}, connection)
      assert.are_same(paymentTypes, result)
    end)

    test("returns nil for a missing YAXI account", function()
      assert.is_nil(accountMapping.derivePaymentTypes(nil, connection))
    end)
  end)
end)
