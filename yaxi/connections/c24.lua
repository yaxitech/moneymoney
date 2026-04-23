-- SPDX-License-Identifier: MIT
-- Author: Vincent Haupert <vincent.haupert@yaxi.tech>

-- C24 connection.

local enum = require("yaxi.enum")
local VopMode = enum.VopMode

---@type YAXI.MoneyMoney.Connection.Config
return {
  id = "connection-72724840-0312-4953-980c-2bc0a8efce97",
  service = "YAXI C24",
  bic = "DEFFDEFF",
  url = "https://c24.de",
  vop = VopMode.Decoupled,
  since = os.time({
    year = 2020,
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
      name = MM.localizeText("C24 App"),
      hbciMethod = "700",
    },
  },
}
