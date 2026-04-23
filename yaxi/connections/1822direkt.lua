-- SPDX-License-Identifier: MIT
-- Author: Vincent Haupert <vincent.haupert@yaxi.tech>

-- 1822direkt connection.

local enum = require("yaxi.enum")
local VopMode = enum.VopMode

---@type YAXI.MoneyMoney.Connection.Config
return {
  id = "connection-1ed54ef5-5ad6-4231-bcbe-7145f7117b44",
  service = "YAXI 1822direkt",
  bic = "HELADEF1822",
  url = "https://www.1822direkt.de",
  vop = VopMode.None,
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
      name = "1822TAN+ App",
      hbciMethod = "700",
      poll = true,
    },
  },
}
