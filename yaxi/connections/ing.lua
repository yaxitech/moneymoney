-- SPDX-License-Identifier: MIT
-- Author: Vincent Haupert <vincent.haupert@yaxi.tech>

-- ING connection.

---@type YAXI.MoneyMoney.Connection.Config
return {
  id = "connection-2c882aff-19dd-4e50-8630-c55abcbc4eb3",
  service = "YAXI ING",
  bic = "INGDDEFF",
  url = "https://myaccount.ing.com",
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
      name = MM.localizeText("ING App"),
      hbciMethod = "700",
    },
    {
      name = "photoTAN",
      hbciMethod = "701",
    },
    {
      name = "mobileTAN",
      hbciMethod = "702",
    },
  },
  appToApp = MM.localizeText("ING App"),
}
