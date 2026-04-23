-- SPDX-License-Identifier: MIT
-- Author: Vincent Haupert <vincent.haupert@yaxi.tech>

-- GLS connection.

---@type YAXI.MoneyMoney.Connection.Config
return {
  id = "connection-c1437bf1-64a0-4fbf-bc1d-63d36bab5b58",
  service = "YAXI GLS",
  bic = "GENODEM1GLS",
  url = "https://gls.de",
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
      name = "SecureGo plus",
      hbciMethod = "946",
      poll = true,
      isPreferred = true,
    },
    {
      name = "Sm@rtTAN manuell",
      hbciMethod = "962",
    },
    {
      name = "Sm@rtTAN optisch",
      hbciMethod = "972",
    },
    {
      name = "Sm@rtTAN USB / Bluetooth",
      hbciMethod = "972alt",
    },
    {
      name = "Sm@rtTAN photo",
      hbciMethod = "982",
    },
  },
  mapChallenge = function(self, challenge, _obResponse)
    if challenge.tanMethods then
      ---@type table<string, MM.TanMethod>
      local byKey = {}
      for _, m in ipairs(self.tanMethods) do
        if m.hbciMethod then
          byKey[m.hbciMethod] = m
        end
      end
      for _, tanMethod in ipairs(challenge.tanMethods) do
        local matched = byKey[tanMethod.webMethod]
        ---@diagnostic disable-next-line: unnecessary-if
        if matched then
          tanMethod.name = matched.name
          tanMethod.hbciMethod = matched.hbciMethod
          tanMethod.isPreferred = matched.isPreferred or tanMethod.isPreferred
        end
      end
    end

    -- Remove verbose Sm@rt-TAN photo description from title
    if challenge.title and challenge.title:find("Sm@rt%-TAN photo%-Leser") then
      challenge.title = nil
    end

    return challenge
  end,
}
