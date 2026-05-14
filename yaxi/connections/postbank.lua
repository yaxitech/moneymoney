-- SPDX-License-Identifier: MIT
-- Author: Vincent Haupert <vincent.haupert@yaxi.tech>

-- Postbank connection.

---@type YAXI.MoneyMoney.Connection.Config
return {
  id = "connection-d56c5d3d-710b-45cb-8ab3-2155d21c7ca5",
  service = "YAXI Postbank",
  bic = "DEUTDEDB",
  url = "https://postbank.de",
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
      name = "BestSign",
      hbciMethod = "700",
      poll = true,
      isPreferred = true,
    },
  },
}
