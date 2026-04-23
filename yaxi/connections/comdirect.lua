-- SPDX-License-Identifier: MIT
-- Author: Vincent Haupert <vincent.haupert@yaxi.tech>

-- Comdirect connection.

---@type YAXI.MoneyMoney.Connection.Config
return {
  id = "connection-493e3be1-ac57-453f-97a1-249118c7e8ce",
  service = "YAXI Comdirect",
  bic = "COBADEHDXXX",
  url = "https://comdirect.de",
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
      name = "photoTAN",
      hbciMethod = "902",
      isPreferred = true,
    },
    {
      name = "mobileTAN",
      hbciMethod = "901",
    },
  },
}
