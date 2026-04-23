-- SPDX-License-Identifier: MIT
-- Author: Vincent Haupert <vincent.haupert@yaxi.tech>

-- Kontist connection.

---@type YAXI.MoneyMoney.Connection.Config
return {
  id = "connection-91666b15-c7c2-4c43-8405-3bcba07c8e4b",
  service = "YAXI Kontist",
  bic = "SOBKDEBB",
  url = "https://kontist.com",
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
      name = MM.localizeText("Kontist App"),
      hbciMethod = "700",
      poll = true,
    },
  },
}
