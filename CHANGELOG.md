# Changelog

## [Unreleased]

### Fixed

- Adding an ING account no longer gets stuck after approving the login in the ING app.
  MoneyMoney opens ING's login page again, which offers its own QR code login.

## [0.5] - 2026-11-08

### Added

- Standing orders
- Foreign currency transactions show the original amount, exchange rates, and fees in the purpose.
- Plain-text transaction codes from the bank serve as the transaction type when nothing else is available.
- The startup log message shows the version and where updates are released.

### Changed

- DKB card payments show merchant names with spaces instead of dots, e.g., `Lekkerland REWE To Go/Nuernberg`.

### Fixed

- An invalid `logLevel` in `yaxi-config.json` falls back to `INFO` instead of breaking the extension.
- The transaction type prefers the German business transaction code (Geschäftsvorfallcode) over the ISO and SWIFT codes banks derive from it, which can be wrong.
  Transaction types from SWIFT and German business transaction codes now show at all; previously, only ISO codes did.
- Transaction and standing order dates no longer show one day early in time zones behind UTC, e.g., in the Americas.
- Returned direct debits and other reversals show the counterparty instead of the account holder.
- Placeholder end-to-end references such as `NOTPROVIDED` are no longer shown.
- The purpose no longer repeats the description of the purpose code.

### Security

- Reject attestation reports whose guest policy allows migration to another host.
- Key settlement uses hybrid X25519 + ML-KEM-768 (FIPS 203) post-quantum key exchange.

## [0.4] - 2026-10-02

### Added

- Transactions now carry the German business transaction code (Geschäftsvorfallcode) and the SWIFT booking key when the bank provides them.

### Changed

- The MoneyMoney API type definitions (`addons/moneymoney/library/mm.lua`) now follow the official web banking API documentation.

### Fixed

- An expired YAXI API key now shows a clear message with instructions instead of a technical error.
- Optical chipTAN (flicker code) challenges now work: the flicker data is passed to MoneyMoney instead of being dropped, e.g., for DKB "chipTAN optisch" and GLS "Sm@rtTAN optisch".
- Text input in TAN dialogs is no longer forced to uppercase and no longer restricted to exactly 6 characters when the bank does not specify a length.
- The chipTAN start code is now extracted right after the "Start-Code" keyword, so a reference number elsewhere in the message can no longer be shown as the start code.
- When a decoupled approval is cancelled or not granted in time, the extension now shows MoneyMoney's message for it instead of polling once more.
- Pending Verification of Payee checks are now polled with the server-requested delay instead of back-to-back requests.
- The displayed balance no longer falls back to an outdated entry when the computer's clock runs slightly behind.
- Settled card and commerce transactions (status `Invoiced` or `Paid`) now show as booked instead of pending, and canceled transactions are no longer shown.
- Transactions without a booking or transaction date now use the value date instead of the time of the refresh, so pending transactions no longer shift on every refresh.
- Transaction deduplication no longer falls back to the SEPA end-to-end reference, which is not unique and could hide distinct transactions as duplicates.
- An account whose balance is missing from the bank's response now shows an error instead of a balance of 0.00, and no longer triggers repeated balance requests.
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
