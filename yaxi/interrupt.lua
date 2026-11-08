-- SPDX-License-Identifier: MIT
-- Author: Vincent Haupert <vincent.haupert@yaxi.tech>

-- YAXI Interrupt Mapping — `OBResponse` → MoneyMoney session challenge / payment response

local log = (require("routex-client.logging") --[[@as lualogging]]).defaultLogger()

local rc = require("routex-client")
local Confirmation = rc.Confirmation
local Selection = rc.Selection
local Field = rc.Field
local InputType = rc.InputType
local DialogContext = rc.DialogContext

local svcMod = require("yaxi.service")
local ticketMod = require("yaxi.ticket")
local util = require("yaxi.util")

local MAX_PAYMENT_STEPS = 10 -- guard against runaway server interrupt loops

local M = {}

-- Data-driven TAN method guessing rules. Evaluated top-to-bottom; first match wins.
-- Each rule lists `patterns` (all must be present in the lowercase message) and a `name`.
--
-- Never use decoupled app method names here (e.g., `pushTAN`, `BestSign`):
-- MoneyMoney renders those without the input field these dialogs need.
---@class YAXI.MoneyMoney.TanRule
---@field patterns string[] All patterns must be found in the message
---@field name string Resulting TAN method name (matched by MM via regex, not exact `MM.TanMethodName`)

---@type YAXI.MoneyMoney.TanRule[]
local TAN_RULES = {
  -- chipTAN / Sm@rtTAN variants
  { patterns = { "qr" }, name = "chipTAN QR" },
  { patterns = { "flicker" }, name = "chipTAN optisch" },
  { patterns = { "optisch" }, name = "chipTAN optisch" },
  { patterns = { "manuell" }, name = "chipTAN manuell" },
  { patterns = { "usb" }, name = "chipTAN USB / Bluetooth" },
  { patterns = { "bluetooth" }, name = "chipTAN USB / Bluetooth" },
  { patterns = { "smart", "photo" }, name = "Sm@rtTAN photo" },
  -- photoTAN
  { patterns = { "photo" }, name = "photoTAN" },
  -- SMS / mobile
  { patterns = { "sms" }, name = "smsTAN" },
  { patterns = { "mobil" }, name = "mobileTAN" },
  -- Generic fallback
  { patterns = { "chiptan" }, name = "chipTAN" },
}

---Check whether all patterns in a rule match the given message.
---@param msg string Lowercase message
---@param rule YAXI.MoneyMoney.TanRule
---@return boolean
local function matchesRule(msg, rule)
  for _, pat in ipairs(rule.patterns) do
    if not msg:find(pat) then
      return false
    end
  end
  return true
end

---Extract image or chipTAN flicker data from a dialog for use as challenge
---content. MoneyMoney renders PNG/JPEG bytes and chipTAN flicker data (the
---plain HHD-UC string, or raw bytes as hex); other image types are dropped.
---@param dialog YAXI.RoutexClient.Dialog
---@return string? data
local function mediaChallengeData(dialog)
  local image = dialog.image
  if not image then
    return nil
  end
  if image.mimeType == "image/png" or image.mimeType == "image/jpeg" then
    return image.data
  end
  local hhdUc = image.hhdUcData
  if hhdUc then
    -- Plain HHD-UC is printable ASCII; frame anything else as a hex string.
    if hhdUc:find("[^%g%s]") then
      return MM.binToHex(hhdUc)
    end
    return hhdUc
  end
  return nil
end

---Build an `MM.SessionChallenge` for a `Field` dialog (TAN/OTP input).
---@param dialog YAXI.RoutexClient.Dialog
---@return MM.SessionChallenge
local function buildFieldChallenge(dialog)
  local field = dialog.input --[[@as YAXI.RoutexClient.Dialog.Input.Field]]

  -- Treat missing lengths as unconstrained: MoneyMoney would force exactly
  -- 6 characters, and the input field accepts at most 15.
  local minLength = field.minLength and math.floor(field.minLength) or 1
  local maxLength = math.max(field.maxLength and math.floor(field.maxLength) or 15, minLength)

  ---@type MM.TanMethod
  local tanMethod = {
    name = "TAN",
    isNumeric = field.type == InputType.Number,
    -- MoneyMoney uppercases non-numeric input unless told otherwise
    isUppercase = false,
    minLength = minLength,
    maxLength = maxLength,
  }

  ---@type MM.SessionChallenge
  local challenge = {
    tanMethod = tanMethod,
    label = "Input",
  }

  local media = mediaChallengeData(dialog)
  if media then
    challenge.challenge = media
    -- Keep the bank's instruction visible while the challenge slot holds media
    challenge.title = dialog.message
  elseif dialog.message then
    -- Plain text fallback, displayed as challenge description
    challenge.challenge = dialog.message
  end

  if dialog.message then
    local msg = dialog.message:lower()

    -- Guess a more specific TAN method name from message keywords
    for _, rule in ipairs(TAN_RULES) do
      if matchesRule(msg, rule) then
        tanMethod.name = rule.name
        log:debug("Guessed TAN method name: %s", rule.name)
        break
      end
    end

    -- Anchor the start code to the keyword so an unrelated reference
    -- number cannot match
    local startCode = dialog.message:match("[Ss]tart[%s%-]?[Cc]ode:?%s*(%d+)")
    if startCode and #startCode >= 4 and #startCode <= 12 then
      challenge.startCode = startCode
      log:debug("Extracted chipTAN start code: %s", startCode)
    end

    -- Label
    if msg:find("tan") then
      challenge.label = "TAN"
    end
  end

  return challenge
end

---Map an `OBResponse` to an `MM.SessionChallenge`.
---Used by `InitializeSession2` and `RefreshAccount`.
---@param session YAXI.MoneyMoney.Session
---@param obResponse YAXI.RoutexClient.OBResponse
---@return MM.SessionChallenge?
function M.mapToChallenge(session, obResponse)
  session:storeResponse(obResponse)
  local connection = session.connection

  if session.result then
    return nil -- Success
  end

  ---@type MM.SessionChallenge
  local challenge

  if session.dialog then
    local dialog = session.dialog
    local input = dialog.input
    if not input then
      error("Dialog has no input")
    end

    if input:isInstanceOf(Confirmation) then
      log:debug("Challenge: Confirmation (poll, context=%s)", dialog.context)
      -- No `title`: MoneyMoney generates a fitting instruction text itself.
      challenge = {
        challenge = dialog.message or "Confirm with your bank",
        poll = true,
      }
    elseif input:isInstanceOf(Selection) then
      local selection = input --[[@as YAXI.RoutexClient.Dialog.Input.Selection]]
      log:debug("Challenge: Selection with %d options", #selection.options)
      challenge = {
        title = dialog.message,
        tanMethods = connection:mapTanMethods(selection.options),
      }
    elseif input:isInstanceOf(Field) then
      log:debug("Challenge: Field input")
      challenge = buildFieldChallenge(dialog)
    else
      error(string.format("Unhandled dialog type"))
    end
  elseif session.redirect then
    log:debug("Challenge: Redirect to %s", session.redirect.url)
    local state = util.extractOAuthState(session.redirect.url)
    challenge = {
      challenge = session.redirect.url,
      appToApp = connection.appToApp,
      state = state,
    }
  else
    error("Unexpected interrupt state: no dialog, redirect, or result")
  end

  -- Let the `Connection` customize the challenge
  challenge = connection:mapChallenge(challenge, obResponse)

  -- Persist discovered TAN methods for SCA selections only; account
  -- selections also arrive as `Selection` dialogs
  local dialogContext = session.dialog and (session.dialog.context or DialogContext.Sca)
  if challenge.tanMethods and dialogContext == DialogContext.Sca then
    local isTanSelection, matchedMethods = connection:detectTanMethodSelection(challenge)
    if isTanSelection and #matchedMethods > 0 then
      connection:storeDiscoveredTanMethods(matchedMethods)
    end
  end

  return challenge
end

---Auto-select a TAN method from a `Selection` dialog during payment.
---@param session YAXI.MoneyMoney.Session
---@param connection YAXI.MoneyMoney.Connection
---@param obResponse YAXI.RoutexClient.OBResponse
---@param tanMethod MM.TanMethod?
---@return YAXI.RoutexClient.OBResponse
local function autoSelectAndRespond(session, connection, obResponse, tanMethod)
  local dialog = assert(session.dialog, "No dialog to auto-select from")
  local selection = dialog.input --[[@as YAXI.RoutexClient.Dialog.Input.Selection]]

  -- Run through `mapChallenge` so bank-specific overrides can assign `hbciMethod`
  local tempChallenge = connection:mapChallenge({
    tanMethods = connection:mapTanMethods(selection.options),
  }, obResponse)
  local mappedMethods = tempChallenge.tanMethods or {}

  local isTanSelection, discoveredMethods = connection:detectTanMethodSelection(tempChallenge)
  if isTanSelection and #discoveredMethods > 0 then
    connection:storeDiscoveredTanMethods(discoveredMethods)
  end

  local matched = connection:autoSelectTanMethod(mappedMethods, tanMethod)
  if not matched then
    error(string.format("Could not auto-select TAN method. Available: %s", JSON():set(mappedMethods):json()))
  end

  log:info("Auto-selected TAN method for payment: %s", matched.name)
  return svcMod.respondToSelection(session, assert(matched.webMethod, "Matched TAN method has no webMethod"))
end

---Build a user-facing `MM.PaymentResponse` from the current session state.
---@param session YAXI.MoneyMoney.Session
---@return MM.PaymentResponse
local function buildPaymentChallenge(session)
  local orderId = session.activeTicket and ticketMod.getId(session.activeTicket) or nil
  ---@type MM.PaymentResponse
  local res

  if session.dialog then
    local dialog = session.dialog
    local input = dialog.input or error("Dialog has no input")

    -- Sent by decoupled-VoP banks only: the user confirms the VoP result in
    -- the banking app; polling merely tracks that decision. Embedded VoP
    -- would need a MoneyMoney-side confirmation instead.
    if input:isInstanceOf(Confirmation) and dialog.context == DialogContext.VopConfirmation then
      log:debug("VopConfirmation: name mismatch, surfacing to user")
      res = {
        status = "pending",
        challenge = dialog.message or "Confirm with your bank",
        poll = true,
        orderId = orderId,
        vop = dialog.message,
      }
    elseif input:isInstanceOf(Confirmation) then
      res = {
        status = "pending",
        challenge = dialog.message or "Confirm with your bank",
        poll = true,
        orderId = orderId,
      }
    elseif input:isInstanceOf(Field) then
      res = {
        challenge = mediaChallengeData(dialog) or dialog.message,
        orderId = orderId,
      }
    else
      error("Unhandled dialog type in payment response")
    end
  elseif session.redirect then
    res = {
      challenge = session.redirect.url,
      orderId = orderId,
    }
  else
    error("Unexpected state: no dialog, redirect, or result")
  end

  return res
end

---Map an `OBResponse` to an `MM.PaymentResponse`.
---Selection and VopCheck dialogs are auto-handled; all others surface to the caller.
---@param session YAXI.MoneyMoney.Session
---@param obResponse YAXI.RoutexClient.OBResponse
---@param tanMethod MM.TanMethod?
---@return MM.PaymentResponse|MM.SessionChallenge
function M.mapToPaymentResponse(session, obResponse, tanMethod)
  local connection = session.connection

  for _ = 1, MAX_PAYMENT_STEPS do
    session:storeResponse(obResponse)

    if session.result then
      log:debug("Payment accepted")
      local orderId = session.activeTicket and ticketMod.getId(session.activeTicket) or nil
      return { status = "accepted", orderId = orderId }
    end

    if session.dialog then
      local input = session.dialog.input or error("Dialog has no input")

      if input:isInstanceOf(Selection) then
        obResponse = autoSelectAndRespond(session, connection, obResponse, tanMethod)
      elseif input:isInstanceOf(Confirmation) and session.dialog.context == DialogContext.VopCheck then
        log:debug("VopCheck: auto-confirming pending check")
        -- The server dictates how long to wait before auto-confirming
        local confirmation = input --[[@as YAXI.RoutexClient.Dialog.Input.Confirmation]]
        MM.sleep(confirmation.pollingDelaySecs or 2)
        obResponse = svcMod.confirmDialog(session)
      else
        return buildPaymentChallenge(session)
      end
    elseif session.redirect then
      return buildPaymentChallenge(session)
    end
  end

  error("Payment interrupt loop exceeded maximum iterations")
end

return M
