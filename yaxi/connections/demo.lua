-- SPDX-License-Identifier: MIT
-- Author: Vincent Haupert <vincent.haupert@yaxi.tech>

-- YAXI Demo connection.

---@type YAXI.MoneyMoney.Connection.Config
return {
  id = "connection-96386142-60e5-4ca9-abcf-944efce5bc1e",
  service = "YAXI Demo",
  bic = "YAXIDEM0",
  url = "https://yaxi.tech",
  paymentTypes = {
    PaymentTypeTransfer,
    PaymentTypeInstantTransfer,
    PaymentTypeScheduledTransfer,
  },
  ---@type MM.TanMethod[]
  tanMethods = {
    {
      name = "appTAN",
      hbciMethod = "900",
      isPreferred = true,
    },
    {
      name = "smsTAN",
      hbciMethod = "901",
    },
    {
      name = "photoTAN",
      hbciMethod = "902",
    },
  },

  ---Remap demo TAN method names from IBANs to TAN methods.
  mapChallenge = function(_self, challenge, _obResponse)
    if challenge.tanMethods then
      for _, tanMethod in ipairs(challenge.tanMethods) do
        local originalName = tanMethod.name
        if originalName == "NL58YAXI1234567890" then
          tanMethod.name = "appTAN"
          tanMethod.hbciMethod = "900"
          tanMethod.mediumName = originalName
          tanMethod.isPreferred = true
        elseif originalName == "NL31YAXI1234567891" then
          tanMethod.name = "smsTAN"
          tanMethod.hbciMethod = "901"
          tanMethod.mediumName = originalName
        end
      end
    end
    return challenge
  end,
}
