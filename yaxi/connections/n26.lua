-- SPDX-License-Identifier: MIT
-- Author: Vincent Haupert <vincent.haupert@yaxi.tech>

-- N26 connection.

local enum = require("yaxi.enum")
local VopMode = enum.VopMode

---@type YAXI.MoneyMoney.Connection.Config
return {
  id = "connection-132565f6-16fc-4586-8087-af886d34d4f8",
  service = "YAXI N26",
  bic = "NTSBDEB1",
  url = "https://app.n26.com",
  vop = VopMode.Decoupled,
  since = os.time({
    year = 2000,
    month = 1,
    day = 1,
  }),
  paymentTypes = {
    PaymentTypeTransfer,
    PaymentTypeInstantTransfer,
  },
  ---@type MM.TanMethod[]
  tanMethods = {
    {
      name = MM.localizeText("N26 App"),
      hbciMethod = "700",
      poll = true,
    },
  },
  mapAccount = function(self, yaxiAccount)
    -- N26 Spaces are savings sub-accounts (`AccountTypeSavings`).

    local accountMapping = require("yaxi.mapping.account")
    local account = accountMapping.mapAccount(yaxiAccount, self)

    if yaxiAccount.productName and yaxiAccount.productName:lower():find("space") then
      account.type = AccountTypeSavings
      account.subAccount = account.name
    end

    return account
  end,
}
