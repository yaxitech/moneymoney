-- SPDX-License-Identifier: MIT
-- Shared test transaction data from the YAXI demo connection (DE02120300000000202051).

local M = {}

M.DEMO_IBAN = "DE02120300000000202051"

---VISA card payment (debit, DCRD purpose code, no mandate)
M.TX_VISA_CARD = {
  bookingDate = "2025-07-29",
  valueDate = "2025-07-29",
  status = "Booked",
  endToEndId = "485209459755938",
  amount = { currency = "EUR", amount = "-0.95" },
  creditor = { name = "DHL.K53VEV55WWVE/BONN", iban = "DE96120300009005290904" },
  debtor = { name = "ISSUER", iban = M.DEMO_IBAN },
  remittanceInformation = { "VISA Debitkartenumsatz" },
  purposeCode = "DCRD",
  bankTransactionCodes = {
    { iso = { domain = "PMNT", family = "ICDT", subFamily = "STDO" } },
    { swift = "DDT" },
    { national = { code = "106", country = "DE" } },
  },
}

---Salary payment (credit, SALA purpose code, single remittance line)
M.TX_SALARY = {
  bookingDate = "2025-07-28",
  valueDate = "2025-07-28",
  status = "Booked",
  endToEndId = "6919804657-000001",
  amount = { currency = "EUR", amount = "3656.58" },
  creditor = { name = "Steiger Dr. med. dent Peter", iban = M.DEMO_IBAN },
  debtor = { name = "DATEV eG", iban = "DE30760501010001519387" },
  remittanceInformation = { "Lohn - Gehalt Abrechnung 07/2025" },
  purposeCode = "SALA",
  bankTransactionCodes = {
    { iso = { domain = "PMNT", family = "ICDT", subFamily = "STDO" } },
    { swift = "TRF" },
    { national = { code = "153", country = "DE" } },
  },
}

---PayPal direct debit (debit, with mandateId + creditorId)
M.TX_DIRECT_DEBIT = {
  bookingDate = "2025-07-18",
  valueDate = "2025-07-18",
  status = "Booked",
  endToEndId = "0057780300544",
  mandateId = "P6PYPY6Y5N2YU",
  creditorId = "LU96ZZZ0000000000000000058",
  amount = { currency = "EUR", amount = "-5.99" },
  creditor = { name = "PayPal Europe S.a.r.l. et Cie S.C.A", iban = "LU89751000135104200E" },
  debtor = { name = "Peter Steiger", iban = M.DEMO_IBAN },
  remittanceInformation = { "0057780300544/PP.1196.PP/. Spotify AB, Ihr Einkauf bei Spotify AB" },
  bankTransactionCodes = {
    { iso = { domain = "PMNT", family = "ICDT", subFamily = "STDO" } },
    { swift = "DDT" },
    { national = { code = "105", country = "DE" } },
  },
}

---Standing order / rent (debit, RINP purpose code, Unicode in remittance)
M.TX_STANDING_ORDER = {
  bookingDate = "2025-07-01",
  valueDate = "2025-07-01",
  status = "Booked",
  amount = { currency = "EUR", amount = "-1000" },
  creditor = { name = "Stefanie Müller-Schmitt", iban = "DE89370400440532013000" },
  debtor = { name = "Dr. Peter Steiger", iban = M.DEMO_IBAN },
  remittanceInformation = { "Miete inkl. Betriebskosten, Flurstr. 4, Wohnungsnr. 5, Nürnberg" },
  purposeCode = "RINP",
  bankTransactionCodes = {
    { iso = { domain = "PMNT", family = "ICDT", subFamily = "STDO" } },
    { swift = "STO" },
    { national = { code = "117", country = "DE" } },
  },
}

return M
