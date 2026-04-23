-- SPDX-License-Identifier: MIT
-- Unit tests for yaxi.interrupt module.

dofile("tests/mm_env.lua")

local assert = require("luassert") ---@type luassert

local Connection = require("yaxi.connections")
local Session = require("yaxi.session")
local enum = require("yaxi.enum")
local interrupt = require("yaxi.interrupt")

local VopMode = enum.VopMode

local rc = require("routex-client")
local Result = rc.Result
local Dialog = rc.Dialog
local Redirect = rc.Redirect
local Confirmation = rc.Confirmation
local Selection = rc.Selection
local Field = rc.Field
local InputType = rc.InputType
local DialogContext = rc.DialogContext

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

---Create a mock Result OBResponse.
---@param jwt? string
---@param connectionData? string
---@return YAXI.RoutexClient.Result
local function mockResult(jwt, connectionData)
  local obj = setmetatable({}, Result)
  obj.jwt = jwt or "mock-jwt"
  obj.connectionData = connectionData
  return obj
end

---Create a mock Dialog with a Confirmation input.
---@param message? string
---@param context? string
---@return YAXI.RoutexClient.Dialog
local function mockConfirmationDialog(message, context)
  local input = setmetatable({}, Confirmation)
  input.context = "mock-context"

  local dialog = setmetatable({}, Dialog)
  dialog.message = message or "Please confirm"
  dialog.input = input
  dialog.context = context
  return dialog
end

---Create a mock Dialog with a Selection input.
---@param options? table
---@param message? string
---@return YAXI.RoutexClient.Dialog
local function mockSelectionDialog(options, message)
  local input = setmetatable({}, Selection)
  input.options = options or {}
  input.context = "mock-context"

  local dialog = setmetatable({}, Dialog)
  dialog.message = message
  dialog.input = input
  return dialog
end

---Create a mock Dialog with a Field input.
---@param message? string
---@param inputType? string
---@param minLen? number
---@param maxLen? number
---@param image? table
---@return YAXI.RoutexClient.Dialog
local function mockFieldDialog(message, inputType, minLen, maxLen, image)
  local input = setmetatable({}, Field)
  input.type = inputType or InputType.Number
  input.minLength = minLen
  input.maxLength = maxLen
  input.context = "mock-context"

  local dialog = setmetatable({}, Dialog)
  dialog.message = message
  dialog.input = input
  dialog.image = image
  return dialog
end

---Create a mock Redirect OBResponse.
---@param url string
---@return YAXI.RoutexClient.Redirect
local function mockRedirect(url)
  local obj = setmetatable({}, Redirect)
  obj.url = url
  obj.context = "mock-context"
  return obj
end

---Create a mock Session using a real `Connection` instance.
---@param connectionOverrides? table
---@return any
local function mockSession(connectionOverrides)
  local config = {
    id = "test-connection",
    service = "Test Bank",
  }
  if connectionOverrides then
    for k, v in pairs(connectionOverrides) do
      config[k] = v
    end
  end

  local sess = setmetatable({}, Session)
  sess.connection = Connection:new(config)
  sess.activeTicket = nil
  sess.activeService = nil
  sess.dialog = nil
  sess.redirect = nil
  sess.result = nil
  return sess
end

-- ---------------------------------------------------------------------------
-- mapToChallenge
-- ---------------------------------------------------------------------------
context("yaxi.interrupt", function()
  context("mapToChallenge", function()
    test("returns nil for a Result response (success)", function()
      local session = mockSession()
      local result = mockResult()
      local challenge = interrupt.mapToChallenge(session, result)
      assert.is_nil(challenge)
    end)

    test("returns poll challenge for a Confirmation dialog", function()
      local session = mockSession()
      local dialog = mockConfirmationDialog("Please confirm in your app", DialogContext.Sca)
      local challenge = interrupt.mapToChallenge(session, dialog)
      assert.is_not_nil(challenge)
      ---@cast challenge -nil
      assert.are_equal("Please confirm in your app", challenge.challenge)
      assert.is_true(challenge.poll)
    end)

    test("sets title to context for Confirmation with non-Sca context", function()
      local session = mockSession()
      local dialog = mockConfirmationDialog("Waiting for redirect", DialogContext.Redirect)
      local challenge = interrupt.mapToChallenge(session, dialog)
      assert.is_not_nil(challenge)
      ---@cast challenge -nil
      assert.are_equal("Waiting for redirect", challenge.challenge)
      assert.is_true(challenge.poll)
      assert.are_equal(DialogContext.Redirect, challenge.title)
    end)

    test("returns tanMethods for a Selection dialog", function()
      local session = mockSession()
      local options = {
        { key = "method-1", label = "SMS TAN" },
        { key = "method-2", label = "Push TAN" },
      }
      local dialog = mockSelectionDialog(options, "Choose TAN method")
      local challenge = interrupt.mapToChallenge(session, dialog)
      assert.is_not_nil(challenge)
      ---@cast challenge -nil
      local tanMethods = challenge.tanMethods
      assert.is_not_nil(tanMethods)
      ---@cast tanMethods -nil
      assert.are_equal(2, #tanMethods)
      ---@diagnostic disable-next-line: need-check-nil
      assert.are_equal("SMS TAN", tanMethods[1].name)
      ---@diagnostic disable-next-line: need-check-nil
      assert.are_equal("method-1", tanMethods[1].webMethod)
      ---@diagnostic disable-next-line: need-check-nil
      assert.are_equal("Push TAN", tanMethods[2].name)
      ---@diagnostic disable-next-line: need-check-nil
      assert.are_equal("method-2", tanMethods[2].webMethod)
    end)

    test("returns challenge with label='TAN' for a Field dialog with 'TAN' in message", function()
      local session = mockSession()
      local dialog = mockFieldDialog("Please enter your TAN", InputType.Text)
      local challenge = interrupt.mapToChallenge(session, dialog)
      assert.is_not_nil(challenge)
      ---@cast challenge -nil
      assert.are_equal("TAN", challenge.label)
      assert.are_equal("Please enter your TAN", challenge.challenge)
      ---@diagnostic disable-next-line: need-check-nil
      assert.are_equal("TAN", challenge.tanMethod.name)
    end)

    test("detects chipTAN QR from message keywords", function()
      local session = mockSession()
      local dialog = mockFieldDialog("Scan the QR code and enter your TAN", InputType.Number)
      local challenge = interrupt.mapToChallenge(session, dialog)
      assert.is_not_nil(challenge)
      ---@cast challenge -nil
      ---@diagnostic disable-next-line: need-check-nil
      assert.are_equal("chipTAN QR", challenge.tanMethod.name)
    end)

    test("detects photoTAN from message keywords", function()
      local session = mockSession()
      local dialog = mockFieldDialog("Scan the photoTAN image", InputType.Number)
      local challenge = interrupt.mapToChallenge(session, dialog)
      assert.is_not_nil(challenge)
      ---@cast challenge -nil
      ---@diagnostic disable-next-line: need-check-nil
      assert.are_equal("photoTAN", challenge.tanMethod.name)
    end)

    test("extracts 8-digit start code from message", function()
      local session = mockSession()
      local dialog = mockFieldDialog("Enter the TAN. Start-Code: 12345678", InputType.Number)
      local challenge = interrupt.mapToChallenge(session, dialog)
      assert.is_not_nil(challenge)
      ---@cast challenge -nil
      assert.are_equal("12345678", challenge.startCode)
    end)

    test("sets isNumeric=true for Number input type", function()
      local session = mockSession()
      local dialog = mockFieldDialog("Enter code", InputType.Number)
      local challenge = interrupt.mapToChallenge(session, dialog)
      assert.is_not_nil(challenge)
      ---@cast challenge -nil
      ---@diagnostic disable-next-line: need-check-nil
      assert.is_true(challenge.tanMethod.isNumeric)
    end)

    test("returns redirect challenge with URL", function()
      local session = mockSession()
      local redirect = mockRedirect("https://bank.example.com/auth")
      local challenge = interrupt.mapToChallenge(session, redirect)
      assert.is_not_nil(challenge)
      ---@cast challenge -nil
      assert.are_equal("https://bank.example.com/auth", challenge.challenge)
    end)

    test("extracts state parameter from redirect URL", function()
      local session = mockSession()
      local redirect = mockRedirect("https://bank.example.com/auth?response_type=code&state=abc123&scope=openid")
      local challenge = interrupt.mapToChallenge(session, redirect)
      assert.is_not_nil(challenge)
      ---@cast challenge -nil
      assert.are_equal(
        "https://bank.example.com/auth?response_type=code&state=abc123&scope=openid",
        challenge.challenge
      )
      assert.are_equal("abc123", challenge.state)
    end)
  end)

  -- ---------------------------------------------------------------------------
  -- mapToPaymentResponse
  -- ---------------------------------------------------------------------------
  context("mapToPaymentResponse", function()
    test("returns status='accepted' for a Result response", function()
      local session = mockSession()
      local result = mockResult()
      local res = interrupt.mapToPaymentResponse(session, result)
      assert.are_equal("accepted", res.status)
    end)

    test("returns pending poll for a Confirmation dialog", function()
      local session = mockSession()
      local dialog = mockConfirmationDialog("Confirm payment", DialogContext.Sca)
      local res = interrupt.mapToPaymentResponse(session, dialog)
      assert.are_equal("pending", res.status)
      assert.are_equal("Confirm payment", res.challenge)
      assert.is_true(res.poll)
    end)

    test("returns PaymentResponse with challenge for a Field dialog", function()
      local session = mockSession()
      local dialog = mockFieldDialog("Enter your TAN to authorize", InputType.Number, 6, 6)
      local res = interrupt.mapToPaymentResponse(session, dialog)
      -- MM.PaymentResponse only supports challenge+poll, not tanMethod/label/startCode
      assert.are_equal("Enter your TAN to authorize", res.challenge)
      assert.is_nil(res.tanMethod)
      assert.is_nil(res.label)
    end)

    test("returns PaymentResponse with image challenge for a Field dialog with image", function()
      local session = mockSession()
      local imageData = "\137PNG\r\n\26\n" -- PNG header bytes
      local dialog = mockFieldDialog("Scan the image", InputType.Number, 6, 6, {
        mimeType = "image/png",
        data = imageData,
      })
      local res = interrupt.mapToPaymentResponse(session, dialog)
      assert.are_equal(imageData, res.challenge)
    end)

    test("returns PaymentResponse with URL for Redirect during payment", function()
      local session = mockSession()
      local redirect = mockRedirect("https://bank.example.com/oauth?state=abc123")
      local res = interrupt.mapToPaymentResponse(session, redirect)
      assert.are_equal("https://bank.example.com/oauth?state=abc123", res.challenge)
      -- appToApp and state are NOT in PaymentResponse
      assert.is_nil(res.appToApp)
      assert.is_nil(res.state)
    end)

    test("auto-confirms VopCheck and recurses to result", function()
      -- Stub service.confirmDialog to return a Result
      local svcMod = require("yaxi.service")
      local origConfirmDialog = svcMod.confirmDialog
      svcMod.confirmDialog = function(_session)
        return mockResult()
      end

      local session = mockSession()
      local dialog = mockConfirmationDialog("VoP check pending", DialogContext.VopCheck)
      local res = interrupt.mapToPaymentResponse(session, dialog)
      assert.are_equal("accepted", res.status)

      svcMod.confirmDialog = origConfirmDialog
    end)

    test("surfaces VopConfirmation message via vop field", function()
      local session = mockSession()
      local dialog =
        mockConfirmationDialog("Name mismatch: Max Mustermann vs. Erika Musterfrau", DialogContext.VopConfirmation)
      local res = interrupt.mapToPaymentResponse(session, dialog)
      assert.are_equal("pending", res.status)
      assert.is_true(res.poll)
      assert.are_equal("Name mismatch: Max Mustermann vs. Erika Musterfrau", res.vop)
    end)

    test("injects VoP warning for banks without VoP support", function()
      local session = mockSession({ vop = VopMode.None })
      local dialog = mockConfirmationDialog("Confirm payment", DialogContext.Sca)
      local res = interrupt.mapToPaymentResponse(session, dialog, nil, false)
      assert.is_not_nil(res.vop)
      ---@cast res.vop -nil
      assert.is_truthy(res.vop:find("Verification of Payee"))
    end)

    test("suppresses VoP warning when suppressVopWarning is true", function()
      local session = mockSession({ vop = VopMode.None })
      local dialog = mockConfirmationDialog("Confirm payment", DialogContext.Sca)
      local res = interrupt.mapToPaymentResponse(session, dialog, nil, true)
      assert.is_nil(res.vop)
    end)

    test("no VoP warning for banks with decoupled VoP", function()
      local session = mockSession({ vop = VopMode.Decoupled })
      local dialog = mockConfirmationDialog("Confirm payment", DialogContext.Sca)
      local res = interrupt.mapToPaymentResponse(session, dialog, nil, false)
      assert.is_nil(res.vop)
    end)
  end)
end)
