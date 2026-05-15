-- SPDX-License-Identifier: MIT
-- Author: Vincent Haupert <vincent.haupert@yaxi.tech>

dofile("tests/mm_env.lua")

local assert = require("luassert")

local Session = require("yaxi.session")
local enum = require("yaxi.enum")
local interrupt = require("yaxi.interrupt")
local service = require("yaxi.service")
local VopMode = enum.VopMode

local extension = require("yaxi.extension")
extension.setup({ apiKeyId = "test", apiKeySecret = "dGVzdA==" })

local PAYMENT = {
  type = PaymentTypeTransfer,
  name = "Max Mustermann",
  accountNumber = "DE89370400440532013000",
  amount = 1.00,
  currency = "EUR",
  purpose = "Test transfer",
}

local function resetState()
  EndSession()
  for k in pairs(LocalStorage) do
    LocalStorage[k] = nil
  end
end

---Inject a payment session whose connection has the given VoP mode.
---@param vop YAXI.MoneyMoney.VopMode
local function initWithMockPaymentSession(vop)
  local origNew = Session.new
  ---@diagnostic disable-next-line: duplicate-set-field
  Session.new = function(_cls, conn)
    local sess = setmetatable({}, Session)
    sess.sessionType = "payment"
    sess.connection = conn
    sess.connection.vop = vop
    sess.credentials = { connectionId = "mock" } --[[@as YAXI.RoutexClient.Credentials]]
    return sess
  end
  InitializeSession2(ProtocolWebBanking, "YAXI Demo", 1, { "", "" } --[[@as MM.Credentials]], true, {}, "payment")
  ---@diagnostic disable-next-line: duplicate-set-field
  Session.new = origNew
end

---Stub `callTransfer` and `mapToPaymentResponse` so `SubmitPayment` runs without HTTP.
---@return fun(): boolean called Returns true if `callTransfer` ran during the call(s) under test
local function stubAndRecordCallTransfer()
  local origCallTransfer = service.callTransfer
  local origMapToPaymentResponse = interrupt.mapToPaymentResponse
  local called = false
  service.callTransfer = function()
    called = true
    return nil
  end
  interrupt.mapToPaymentResponse = function()
    return { status = "accepted", orderId = "mock-order" }
  end
  return function()
    service.callTransfer = origCallTransfer
    interrupt.mapToPaymentResponse = origMapToPaymentResponse
    return called
  end
end

context("SubmitPayment VoP warning gate", function()
  teardown(resetState)

  test("VopMode.None: step 1 returns the warning without initiating the transfer", function()
    resetState()
    initWithMockPaymentSession(VopMode.None)
    local finish = stubAndRecordCallTransfer()

    local res = SubmitPayment(1, {}, PAYMENT, nil, nil) --[[@as MM.PaymentResponse]]
    local callTransferRan = finish()

    assert.is_false(callTransferRan)
    assert.are_equal("pending", res.status)
    assert.is_true(res.poll)
    assert.is_string(res.vop)
    ---@cast res.vop -nil
    assert.is_truthy(res.vop:find("Verification of Payee"))
  end)

  test("VopMode.None: step 2 (after warning) initiates the transfer", function()
    resetState()
    initWithMockPaymentSession(VopMode.None)
    local finish = stubAndRecordCallTransfer()

    SubmitPayment(1, {}, PAYMENT, nil, nil)
    SubmitPayment(2, {}, PAYMENT, nil, { "", "", true } --[[@as MM.TanCredentials]])

    assert.is_true(finish())
  end)

  test("VopMode.None with suppressVopWarning: step 1 initiates the transfer directly", function()
    resetState()
    extension.setup({ apiKeyId = "test", apiKeySecret = "dGVzdA==", suppressVopWarning = true })
    initWithMockPaymentSession(VopMode.None)
    local finish = stubAndRecordCallTransfer()

    SubmitPayment(1, {}, PAYMENT, nil, nil)

    assert.is_true(finish())
    extension.setup({ apiKeyId = "test", apiKeySecret = "dGVzdA==" })
  end)

  test("VopMode.Decoupled: step 1 initiates the transfer directly", function()
    resetState()
    initWithMockPaymentSession(VopMode.Decoupled)
    local finish = stubAndRecordCallTransfer()

    SubmitPayment(1, {}, PAYMENT, nil, nil)

    assert.is_true(finish())
  end)
end)
