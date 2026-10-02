# Changelog

## Unreleased

### Changed

- The MoneyMoney API type definitions (`addons/moneymoney/library/mm.lua`) now follow the official web banking API documentation.

### Fixed

- Optical chipTAN (flicker code) challenges now work: the flicker data is passed to MoneyMoney instead of being dropped, e.g., for DKB "chipTAN optisch" and GLS "Sm@rtTAN optisch".
- Text input in TAN dialogs is no longer forced to uppercase and no longer restricted to exactly 6 characters when the bank does not specify a length.
- The chipTAN start code is now extracted right after the "Start-Code" keyword, so a reference number elsewhere in the message can no longer be shown as the start code.
- Errors from the YAXI API now reach the extension's error handling on all requests.
  Previously, an HTTP error on some requests (e.g., an invalid API key) made MoneyMoney abort the session with a raw HTTP error dialog instead of showing the proper message.

## [0.3] - 2026-07-21

### Changed

- Background (automatic) refreshes of balances and transactions now use YAXI's non-interactive refresh services when connection data from a prior session is available, avoiding an interactive login.
  If the bank requires authorization (SCA) for a background refresh, the extension asks for a manual refresh instead of prompting, which would otherwise trigger an unexpected SCA.
  Background refreshes signal the user's own connection as in-session, so the bank applies its regular access limits rather than the stricter cap on requests without a user in session.

### Fixed

- Error trace files now contain the trace of the failed service call instead of an unrelated one from earlier in the session.
- The displayed balance is now the most recent `Booked` or `Available` figure without a credit line that is already valid (its timestamp is not in the future), preferring `Booked` when both share the same timestamp.
  This avoids surfacing a stale day (e.g. a prior bookkeeping day's closing balance next to the current interim one) or a not-yet-valid balance.

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
