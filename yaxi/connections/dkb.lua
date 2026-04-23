-- SPDX-License-Identifier: MIT
-- Author: Vincent Haupert <vincent.haupert@yaxi.tech>

-- DKB connection.

local util = require("yaxi.util")

---@type YAXI.MoneyMoney.Connection.Config
return {
  id = "connection-c5d149fe-02fe-4fc6-b83c-21572d389967",
  service = "YAXI DKB",
  bic = "BYLADEM1001",
  url = "https://dkb.de",
  since = os.time({
    year = 2000,
    month = 1,
    day = 1,
  }),
  paymentTypes = {
    PaymentTypeTransfer,
    PaymentTypeInstantTransfer,
    PaymentTypeScheduledTransfer,
  },
  ---@type MM.TanMethod[]
  tanMethods = {
    {
      name = MM.localizeText("DKB App"),
      hbciMethod = "940",
      poll = true,
      isPreferred = true,
    },
    {
      name = "chipTAN QR",
      hbciMethod = "913",
    },
    {
      name = "chipTAN optisch",
      hbciMethod = "911",
    },
    {
      name = "chipTAN USB / Bluetooth",
      hbciMethod = "912",
    },
    {
      name = "chipTAN manuell",
      hbciMethod = "910",
    },
  },
  transactionCodePreference = { "other" },

  ---Rename DKB TAN methods from `"Name | Medium"` format and assign `hbciMethod`s.
  mapChallenge = function(_self, challenge, _obResponse)
    if challenge.tanMethods then
      for _, tanMethod in ipairs(challenge.tanMethods) do
        -- Split `"Name | Medium"` format
        local parts = util.split(tanMethod.name, "|")
        if #parts == 2 then
          tanMethod.name = util.strip(parts[1]) ---@diagnostic disable-line: assign-type-mismatch
          tanMethod.mediumName = util.strip(parts[2])
        end

        local nameLower = tanMethod.name:lower()
        if nameLower:find("seal") then
          tanMethod.name = MM.localizeText("DKB App") ---@diagnostic disable-line: assign-type-mismatch
          if tanMethod.mediumName then
            tanMethod.mediumName = tanMethod.mediumName:gsub("^.+ auf (.*)", "%1")
          end
          tanMethod.isPreferred = true
          tanMethod.hbciMethod = "940"
        elseif nameLower:find("chiptan") then
          if tanMethod.mediumName then
            tanMethod.mediumName = tanMethod.mediumName:gsub("^.+:%s*(.*)", "%1")
          end
          if nameLower:find("manuell") then
            tanMethod.name = "chipTAN manuell"
            tanMethod.hbciMethod = "910"
          elseif nameLower:find("qr") then
            tanMethod.name = "chipTAN QR"
            tanMethod.hbciMethod = "913"
          elseif nameLower:find("usb") or nameLower:find("bluetooth") then
            tanMethod.name = "chipTAN USB / Bluetooth" ---@diagnostic disable-line: assign-type-mismatch
            tanMethod.hbciMethod = "912"
          elseif nameLower:find("optisch") or nameLower:find("flicker") then
            tanMethod.name = "chipTAN optisch"
            tanMethod.hbciMethod = "911"
          end
        end
      end
    end
    return challenge
  end,
}
