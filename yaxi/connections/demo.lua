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
        if tanMethod.name == "NL58YAXI1234567890" then
          tanMethod.name = "appTAN" ---@diagnostic disable-line: assign-type-mismatch
          tanMethod.hbciMethod = "900"
          tanMethod.mediumName = tanMethod.name
          tanMethod.isPreferred = true
        elseif tanMethod.name == "NL31YAXI1234567891" then
          tanMethod.name = "smsTAN" ---@diagnostic disable-line: assign-type-mismatch
          tanMethod.hbciMethod = "901"
          tanMethod.mediumName = tanMethod.name
        end
      end
    end
    return challenge
  end,
}
