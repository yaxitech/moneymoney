# Changelog

## [0.2] - 2026-05-15

### Added

- Support for Postbank

### Fixed

- Each account's supported `paymentTypes` (e.g. SEPA transfer, instant transfer) are now populated correctly.
  Previously they were silently dropped, so MoneyMoney did not know which payment options to offer per account.
  Existing accounts pick up the fix on the next refresh.
- For banks without native Verification of Payee, the warning prompting the user to verify the recipient now appears before the transfer is sent to the bank.
  Previously it was shown after the transfer had already been registered, leaving no clean way to abort.
- TAN method lookup now also matches accounts by their bank code, not just BIC.
  Previously, accounts MoneyMoney delivers without an explicit BIC could fail with "No connection found".

## [0.1] - 2026-04-24

- Initial release.
