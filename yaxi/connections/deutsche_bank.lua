-- SPDX-License-Identifier: MIT
-- Author: Vincent Haupert <vincent.haupert@yaxi.tech>

-- Deutsche Bank connection.

---@type YAXI.MoneyMoney.Connection.Config
return {
  id = "connection-089c6f06-9761-48c4-adc1-c3bde4c6e1e6",
  service = "YAXI Deutsche Bank",
  bic = "DEUTDEFFXXX",
  url = "https://meine.deutsche-bank.de",
  paymentTypes = {
    PaymentTypeTransfer,
    PaymentTypeInstantTransfer,
    PaymentTypeScheduledTransfer,
  },
  ---@type MM.TanMethod[]
  tanMethods = {
    {
      name = "BestSign",
      hbciMethod = "921",
      poll = true,
      isPreferred = true,
    },
    {
      name = "photoTAN push",
      hbciMethod = "903",
      poll = true,
    },
    {
      name = "photoTAN",
      hbciMethod = "902",
    },
    {
      name = "mobileTAN",
      hbciMethod = "901",
    },
  },
}
