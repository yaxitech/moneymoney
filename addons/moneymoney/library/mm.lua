-- SPDX-License-Identifier: MIT
-- Author: Vincent Haupert <vincent.haupert@yaxi.tech>

-- MoneyMoney Extension API — LuaCATS Type Definitions
--
-- Drop this file (or directory) into your workspace and configure your language server
-- to include it as a library. It provides full type information for the MoneyMoney
-- extension API without requiring any annotations in your extension scripts.
--
-- The extension script itself must be UTF-8 encoded, and all strings are exchanged
-- as UTF-8 between the script and MoneyMoney, except where a parameter or return
-- value is described as binary data.
--
---@meta

--#region MM Table — Global Utility Functions and Properties

---Global `MM` table providing crypto, encoding, formatting, and system utilities.
---@class MM
MM = {}

---Encode binary data as Base64 string.
---@param data string Binary input
---@param linebreaks? boolean Wrap output every 64 characters (PEM-style). Default: no line breaks.
---@return string encoded Base64-encoded string
function MM.base64(data, linebreaks) end

---Decode Base64 string to binary data.
---Also accepts Base64URL input (`-`/`_`, missing padding) and line breaks.
---@param encoded string Base64- or Base64URL-encoded input
---@return string data Binary output
function MM.base64decode(encoded) end

---Compute HMAC-SHA1. Both key and data are binary; returns binary.
---@param key string Binary key
---@param data string Binary data
---@return string hmac Binary HMAC
function MM.hmac1(key, data) end

---Compute HMAC-SHA256. Both key and data are binary; returns binary.
---@param key string Binary key
---@param data string Binary data
---@return string hmac Binary HMAC
function MM.hmac256(key, data) end

---Compute HMAC-SHA384. Both key and data are binary; returns binary.
---@param key string Binary key
---@param data string Binary data
---@return string hmac Binary HMAC
function MM.hmac384(key, data) end

---Compute HMAC-SHA512. Both key and data are binary; returns binary.
---@param key string Binary key
---@param data string Binary data
---@return string hmac Binary HMAC
function MM.hmac512(key, data) end

---Format a currency amount using NSNumberFormatter (Unicode TR35 patterns).
---@overload fun(amount: number|string, currency?: string): string
---@param format string Format pattern (Unicode TR35)
---@param amount number|string Amount
---@param currency? string ISO 4217 currency code. Without it, only the amount is returned.
---@return string formatted Localized amount string
function MM.localizeAmount(format, amount, currency) end

---Format a date using NSDateFormatter (Unicode TR35 patterns, e.g. `"yyyy-MM-dd"`).
---@overload fun(timestamp: MM.Timestamp): string
---@param format string Format pattern (Unicode TR35)
---@param date MM.Timestamp POSIX timestamp
---@return string formatted Localized date string
function MM.localizeDate(format, date) end

---Format a number using NSNumberFormatter (Unicode TR35 patterns, e.g. `"#,##0.00"`).
---@overload fun(num: number): string
---@param format string Format pattern (Unicode TR35)
---@param num number Number to format
---@return string formatted Localized number string
function MM.localizeNumber(format, num) end

---Translate a text string. Wrapper for NSLocalizedString, primarily intended
---for the extensions shipped with MoneyMoney.
---Only returns a translation if the text is in MoneyMoney's string tables.
---@param text string English text to translate
---@return string translated Translated text (or original if no translation)
function MM.localizeText(text) end

---Compute MD5 hash. Returns uppercase hexadecimal string.
---@param data string Input data
---@return string hex Uppercase hex digest
function MM.md5(data) end

---Compute SHA-1 hash. Returns uppercase hexadecimal string.
---@param data string Input data
---@return string hex Uppercase hex digest
function MM.sha1(data) end

---Compute SHA-256 hash. Returns uppercase hexadecimal string.
---@param data string Input data
---@return string hex Uppercase hex digest
function MM.sha256(data) end

---Compute SHA-512 hash. Returns uppercase hexadecimal string.
---@param data string Input data
---@return string hex Uppercase hex digest
function MM.sha512(data) end

---Print to the log window and show as GUI status bar message.
---Works like Lua's `print()`.
---Call with no args to clear the status message.
---@param ... any Values to print
function MM.printStatus(...) end

---Generate a binary string of cryptographically random bytes.
---@param length integer Number of random bytes
---@return string data Binary random data
function MM.random(length) end

---Return the current time as POSIX timestamp with millisecond precision (decimal places).
---Unlike `os.time()`, includes sub-second resolution.
---@return number timestamp POSIX timestamp with fractional seconds
function MM.time() end

---Convert a UTF-8 string to a different character encoding.
---Uses IANA charset names (e.g. `"ISO-8859-1"`, `"Windows-1252"`).
---When `bom` is true, a byte-order mark is prepended if one exists for the
---target charset.
---@param charset string Target encoding (IANA name)
---@param text string UTF-8 input
---@param bom? boolean Prepend BOM
---@return string data Encoded output
function MM.toEncoding(charset, text, bom) end

---Convert a string from a different character encoding to UTF-8.
---Uses IANA charset names (e.g. `"Windows-1252"`, `"ISO-8859-1"`).
---@param charset string Source encoding (IANA name)
---@param data string Encoded input
---@return string text UTF-8 output
function MM.fromEncoding(charset, data) end

---URL-encode a string. Default charset is ISO-8859-1; pass `"UTF-8"` for unicode.
---@param s string String to encode
---@param charset? string Character encoding (default: `"ISO-8859-1"`)
---@return string encoded URL-encoded string
function MM.urlencode(s, charset) end

---Decode a URL-encoded string.
---@param s string URL-encoded string
---@return string decoded Decoded string
function MM.urldecode(s) end

---Pause script execution for the given number of seconds.
---@param seconds number Duration to sleep
function MM.sleep(seconds) end

---Application name, i.e., `"MoneyMoney"`.
---@type string
MM.productName = ""

---Application version string, e.g., `"2.4.66"`.
---@type string
MM.productVersion = ""

---Encode binary data as URL-safe Base64 (RFC 4648 §5: `+/` → `-_`, no padding).
---@param data string Binary input
---@return string encoded URL-safe Base64 string
function MM.base64urlencode(data) end

---Decode Base32-encoded string to binary data.
---@param encoded string Base32-encoded input
---@return string data Binary output
function MM.base32decode(encoded) end

---Compute SHA3-256 hash. Returns uppercase hexadecimal string.
---@param data string Input data
---@return string hex Uppercase hex digest
function MM.sha3_256(data) end

---Print debug message to the log window. Unlike `printStatus`, does NOT show in the GUI status bar.
---@param ... any Values to print
function MM.printDebug(...) end

---AES-256 encryption. Supports CBC (default) and GCM.
---In GCM mode, returns `(encrypted, tag)`. In CBC mode, output is PKCS#7-padded.
---@param key string Binary AES key (32 bytes)
---@param iv string Binary IV (16 bytes for CBC, 12 bytes for GCM)
---@param data string Data to encrypt
---@param algorithm? string `"aes256 cbc"` (default) or `"aes256 gcm"`
---@param aad? string Additional authenticated data (required for GCM, may be empty)
---@return string? encrypted Encrypted data, or nil on unknown algorithm or wrong key/IV length
---@return string? tag Authentication tag (GCM only, 16 bytes)
function MM.aes256encrypt(key, iv, data, algorithm, aad) end

---AES-256 decryption. Supports CBC (default) and GCM.
---@param key string Binary AES key (32 bytes)
---@param iv string Binary IV (16 bytes for CBC, 12 bytes for GCM)
---@param encrypted string Data to decrypt
---@param algorithm? string `"aes256 cbc"` (default) or `"aes256 gcm"`
---@param aad? string Additional authenticated data as passed to encryption (GCM)
---@param tag? string 16-byte authentication tag from encryption (GCM)
---@return string? data Decrypted data (CBC: padding removed), or nil on bad parameters, invalid padding, or failed authentication
function MM.aes256decrypt(key, iv, encrypted, algorithm, aad, tag) end

---AES-128 encryption. Same interface as `MM.aes256encrypt` but with a 16-byte key.
---@param key string Binary AES key (16 bytes)
---@param iv string Binary IV
---@param data string Data to encrypt
---@param algorithm? string Cipher algorithm
---@param aad? string Additional authenticated data (GCM only)
---@return string? encrypted
---@return string? tag Authentication tag (GCM only)
function MM.aes128encrypt(key, iv, data, algorithm, aad) end

---AES-128 decryption. Same interface as `MM.aes256decrypt` but with a 16-byte key.
---@param key string Binary AES key (16 bytes)
---@param iv string Binary IV
---@param encrypted string Data to decrypt
---@param algorithm? string Cipher algorithm
---@param aad? string Additional authenticated data (GCM only)
---@param tag? string Authentication tag from encryption (GCM only)
---@return string? data Decrypted data, or nil on failure
function MM.aes128decrypt(key, iv, encrypted, algorithm, aad, tag) end

---RSA encryption (RSAES-OAEP) with the given public key.
---@param key MM.RSAKey Key table; only `n` and `e` are required
---@param data string Data to encrypt
---@param algorithm string `"pkcs1-oaep sha256"` or `"pkcs1-oaep sha512"` (same hash for label and MGF1), or `"pkcs1-oaep sha256 sha1"` (SHA-256 label hash, SHA-1 for MGF1)
---@return string? encrypted Encrypted data (length = key size), or nil on unknown algorithm or bad key fields
function MM.rsaEncrypt(key, data, algorithm) end

---RSA decryption (RSAES-OAEP) with the given private key.
---@param key MM.RSAKey Key table; requires `n`, `e`, `d`, `p`, `q`; CRT fields optional
---@param encrypted string Data to decrypt
---@param algorithm string `"pkcs1-oaep sha256"` or `"pkcs1-oaep sha512"` (same hash for label and MGF1)
---@return string? data Decrypted data, or nil on unknown algorithm, bad key fields, or failed decryption
function MM.rsaDecrypt(key, encrypted, algorithm) end

---Generate an RSA key pair with public exponent 65537.
---@param bits integer Key size in bits (512 to 4096)
---@return MM.RSAKey? key Key table, or nil on invalid key size
function MM.rsaGenerateKeys(bits) end

---Compute an RSA signature (RSASSA-PKCS1-v1_5). Data is hashed with SHA-256.
---@param key MM.RSAKey Key table; requires `n`, `e`, `d`, `p`, `q`; CRT fields optional
---@param data string Data to sign
---@param algorithm string `"pkcs1-v1_5 sha256"`
---@return string? signature Binary signature (length = key size), or nil on unknown algorithm or bad key fields
function MM.rsaSign(key, data, algorithm) end

---Verify an RSA signature. Counterpart of `MM.rsaSign`.
---@param key MM.RSAKey Key table; only `n` and `e` are required
---@param data string Signed data
---@param signature string Binary signature to verify
---@param algorithm string `"pkcs1-v1_5 sha256"`
---@return boolean valid True if the signature is valid; false also on bad parameters
function MM.rsaVerify(key, data, signature, algorithm) end

---Export the public part of an RSA key as PEM block
---(SubjectPublicKeyInfo, `-----BEGIN PUBLIC KEY-----`).
---@param key MM.RSAKey Key table; only `n` and `e` are required
---@return string? pem PEM-encoded public key, or nil on bad key fields
function MM.rsaPkcs8(key) end

---Import an RSA public key from a PEM block (`-----BEGIN PUBLIC KEY-----`).
---Yields only `n` and `e`. Prefer `MM.pkcs8decode` for new extensions.
---@param pem string PEM-encoded public key
---@return MM.RSAKey? key Key table with `n` and `e`, or nil on failure
function MM.rsaPkcs8decode(pem) end

---Import a key from PKCS#8/SubjectPublicKeyInfo format. Accepts PEM
---(`-----BEGIN PRIVATE KEY-----`/`-----BEGIN PUBLIC KEY-----`, also
---traditional PEM formats) and binary DER, private or public. The key type
---(RSA, EC, Ed25519) is detected automatically, so a user-supplied key block
---can be passed through unchanged. If an EC key lacks the public point, it is
---derived from the private scalar.
---@param data string Key in PEM or binary DER format
---@return (MM.RSAKey|MM.ECKey)? key Key table with `type` field, or nil if the key could not be read
function MM.pkcs8decode(data) end

---RSA encryption (RSAES-PKCS1-v1_5, legacy) with a raw public key.
---Unlike the other RSA functions, takes modulus and exponent directly
---instead of a key table.
---@param modulus string Public key modulus `n` (binary, big-endian)
---@param exponent string Public exponent `e` (binary, big-endian)
---@param data string Data to encrypt
---@return string? encrypted Encrypted data (length = key size), or nil on invalid parameters or too-long data
function MM.rsaPkcs1(modulus, exponent, data) end

---Apply RSA padding to data.
---@param data string Data to pad
---@param padding string Padding mode
---@param keySize integer Key size in bits
---@return string padded Padded data
function MM.rsaPad(data, padding, keySize) end

---Generate an elliptic curve key pair. Typical use: create a device key once
---during account setup, store it in `LocalStorage`, and sign later logins.
---@param curve string Curve name, e.g. `"prime256v1"`. `"ed25519"` (case-insensitive) generates an Ed25519 key pair.
---@return MM.ECKey? key Key table, or nil on unknown curve
function MM.ecGenerateKeys(curve) end

---Compute an EC signature, e.g. for signing API requests or JWTs.
---With `"ecdsa …"` the data is hashed and the hash is signed (requires
---`curve`, `x`, `y`, `d`). With `"eddsa"` (PureEdDSA per RFC 8032) the data
---is signed directly, without hashing (requires `curve` = `"ed25519"` and `d`).
---@param key MM.ECKey EC key table
---@param data string Data to sign
---@param algorithm string `"ecdsa sha256"`, `"ecdsa sha512"`, or `"eddsa"`
---@return string? signature DER-encoded (ECDSA) or raw 64-byte (EdDSA) signature, or nil on unknown algorithm/curve or bad key fields
function MM.ecSign(key, data, algorithm) end

---Verify an EC signature. Counterpart of `MM.ecSign`.
---Only the public key fields are required (ECDSA: `curve`, `x`, `y`;
---EdDSA: `curve`, `x`); a present private scalar `d` is ignored.
---@param key MM.ECKey EC key table
---@param data string Signed data
---@param signature string Signature to verify (DER for ECDSA, raw 64 bytes for EdDSA)
---@param algorithm string `"ecdsa sha256"`, `"ecdsa sha512"`, or `"eddsa"`
---@return boolean valid True if the signature is valid; false also on bad parameters
function MM.ecVerify(key, data, signature, algorithm) end

---Convert binary data to uppercase hexadecimal string (no separators).
---@param data string Binary input
---@return string hex Hex string, e.g. `"746573747573"`
function MM.binToHex(data) end

---Convert hexadecimal string to binary data.
---@param hex string Hex string (case-insensitive; `:` separators are ignored)
---@return string? data Binary output, or nil on invalid input
function MM.hexToBin(hex) end

---Convert a hex string to an opaque big number object.
---@param hex string Hexadecimal string
---@return MM.BigNum bignum Big number object
function MM.hexToBigNum(hex) end

---Convert a big number to hexadecimal string.
---@param num MM.BigNum Big number object
---@return string hex Hexadecimal string
function MM.bigNumToHex(num) end

---Big number addition: `a + b`.
---@param a MM.BigNum
---@param b MM.BigNum
---@return MM.BigNum result
function MM.bigNumAdd(a, b) end

---Big number subtraction: `a - b`.
---@param a MM.BigNum
---@param b MM.BigNum
---@return MM.BigNum result
function MM.bigNumSub(a, b) end

---Big number multiplication: `a * b`.
---@param a MM.BigNum
---@param b MM.BigNum
---@return MM.BigNum result
function MM.bigNumMul(a, b) end

---Big number modulo: `a mod m`.
---@param a MM.BigNum
---@param m MM.BigNum Modulus
---@return MM.BigNum result
function MM.bigNumMod(a, m) end

---Big number modular exponentiation: `base^exp mod m`.
---@param base MM.BigNum
---@param exp MM.BigNum Exponent
---@param m MM.BigNum Modulus
---@return MM.BigNum result
function MM.bigNumModExp(base, exp, m) end

---Big number exponentiation: `base^exp`.
---@param base MM.BigNum
---@param exp MM.BigNum
---@return MM.BigNum result
function MM.bigNumExp(base, exp) end

---Big number XOR: `a XOR b`.
---@param a MM.BigNum
---@param b MM.BigNum
---@return MM.BigNum result
function MM.bigNumXor(a, b) end

---Get the bit size of a big number.
---@param num MM.BigNum Big number object
---@return integer bits
function MM.bigNumSize(num) end

---Decode DER-encoded ASN.1 data into a nested table structure.
---@param data string DER-encoded binary data
---@return table tree Nested table representing the ASN.1 structure
function MM.derdecode(data) end

---Encode a table structure as DER-encoded ASN.1 data.
---@param data table ASN.1 structure
---@return string der DER-encoded binary data
function MM.derencode(data) end

---Key derivation using PBKDF1/PBKDF2.
---Returns derived key and optionally an IV depending on the algorithm.
---@param password string Password input
---@param salt string Salt value
---@param iterations integer Number of iterations
---@param algorithm string Algorithm specifier, e.g. `"pbkdf1 md5 aes256"`
---@return string key Derived key
---@return string? iv Derived IV (algorithm-dependent)
function MM.pbkdf(password, salt, iterations, algorithm) end

---Parse a SWIFT MT940/MT942 bank statement message into transactions.
---@param messageType 940|942 MT message type
---@param content string Raw MT message content
---@param bankCode string Bank code for context
---@param currency string Account currency
---@return MM.Transaction[]? transactions Parsed transactions
---@return number? balance Closing balance
---@return string? currency Balance currency
---@return string? errorMessage Error message if parsing failed
function MM.parseSwiftMt(messageType, content, bankCode, currency) end

---Parse a SEPA CAMT.05x XML document into transactions.
---@param content string XML document content
---@param bankCode string Bank code for context
---@param currency string Account currency
---@return MM.Transaction[]? transactions Parsed transactions
---@return number? balance Closing balance
---@return string? currency Balance currency
---@return string? errorMessage Error message if parsing failed
function MM.parseSepaCamt(content, bankCode, currency) end

---Date parts returned by `MM.date(timestamp, "*t")`.
---@class MM.DateParts
---@field timestamp MM.Timestamp POSIX timestamp
---@field year integer
---@field month integer
---@field day integer
---@field isBusinessDay boolean Considers the bank holidays of the bank connection's country

---Date calculations in four forms:
--- 1. `MM.date()`: the current time as integer POSIX timestamp.
--- 2. `MM.date(timestamp, offset)`: shift the timestamp by days (`"D"`),
---    weeks (`"W"`), months (`"M"`), quarters (`"Q"`) or years (`"Y"`),
---    e.g. `"-30D"` or `"1M"`. Pass nil as `timestamp` for the current time.
--- 3. `MM.date(timestamp, "*t")`: split the timestamp into an `MM.DateParts` table.
--- 4. `MM.date{year=2026, month=9, day=3, from="Europe/Berlin"}`: compose a
---    timestamp from fields. Defaults: today's date, `hour` 12, `min`/`sec` 0.
---    `from`/`to` are timezone names for conversion.
---@overload fun(): MM.Timestamp
---@overload fun(timestamp: MM.Timestamp, format: "*t"): MM.DateParts
---@overload fun(spec: {year?: integer, month?: integer, day?: integer, hour?: integer, min?: integer, sec?: integer, from?: string, to?: string}): MM.Timestamp
---@param timestamp MM.Timestamp? Base timestamp (nil for the current time)
---@param offset string Relative offset string, e.g. `"-30D"`, `"1M"`, `"-3Y"`
---@return MM.Timestamp timestamp POSIX timestamp
function MM.date(timestamp, offset) end

---Generate a UUID v4 string (lowercase with hyphens).
---@return string uuid e.g. `"81e37074-623e-42d0-b24f-6da495d57ec4"`
function MM.uuid() end

---Get the GMT offset in seconds for a timezone at a given time.
---When called with no arguments, returns the system's current GMT offset.
---@param timezone? string IANA timezone name, e.g. `"Europe/Berlin"`
---@param timestamp? MM.Timestamp POSIX timestamp (for DST-aware offset). Default: now.
---@return integer offset Offset in seconds (e.g. 3600 for CET)
function MM.gmtOffset(timezone, timestamp) end

---Get the user's local IANA timezone name.
---@return string timezone e.g. `"Europe/Berlin"`; `"GMT"` if the timezone cannot be determined
function MM.timezone() end

---Get the length of a UTF-8 string in characters (not bytes).
---Counts UTF-16 units: characters outside the Basic Multilingual Plane
---(e.g. emoji) count twice.
---@param s string UTF-8 string
---@return integer length Character count
function MM.utf8len(s) end

---Extract a UTF-8-aware substring by character positions.
---Behaves like `string.sub`: indexing starts at 1, negative positions
---count from the end of the string.
---@param s string UTF-8 string
---@param i integer Start character position
---@param j? integer End character position (inclusive). Default: -1 (end of string).
---@return string substring
function MM.utf8sub(s, i, j) end

---Convert a UTF-8 string to lowercase, handling unicode properly.
---@param s string UTF-8 string
---@return string lower Lowercased string
function MM.utf8lower(s) end

---Read a macOS user defaults value (NSUserDefaults).
---@param key string Defaults key name
---@return any? value The value, or nil if not set
function MM.readDefaults(key) end

---Resize an image (PNG/JPEG binary data).
---@param imageData string Binary image data
---@param width integer Target width
---@param height integer Target height
---@return string resized Resized image data
function MM.imageResize(imageData, width, height) end

---Compute a bcrypt hash.
---@param password string Password to hash
---@param salt string Bcrypt salt
---@return string hash Bcrypt hash
function MM.bcrypt(password, salt) end

---Generate an HMAC-based One-Time Password (RFC 4226).
---@param key string HOTP secret key
---@param counter integer Counter value
---@param digits? integer Number of digits (default: 6)
---@return string otp One-time password string
function MM.hotp(key, counter, digits) end

---PKCS#1 Mask Generation Function 1 (MGF1).
---@param seed string Seed value
---@param hashAlgorithm string Hash algorithm name
---@param length integer Desired mask length
---@return string mask Generated mask
function MM.mgf1(seed, hashAlgorithm, length) end

---Check if a date is a business day.
---@param timestamp MM.Timestamp POSIX timestamp
---@return boolean isBusinessDay
function MM.isBusinessDay(timestamp) end

---Application build number, e.g. `503`.
---As a number, suited for version comparisons.
---@type number
MM.productBuild = 0

---Unique device identifier (short hex), e.g. `"81E37074"`.
---@type string
MM.deviceId = ""

---Human-readable device name, e.g. `"John's MacBook Pro"`.
---@type string
MM.deviceName = ""

---Randomly generated, persistently stored device identifier (UUID),
---e.g. `"81e37074-623e-42d0-b24f-6da495d57ec4"`. Identifies the same device
---consistently across sessions, e.g. for a device registration with a bank
---server. `nil` if no identifier has been generated yet.
---@type string?
MM.deviceUuid = nil

---Database identifier string for the current MoneyMoney installation.
---@type string
MM.databaseId = ""

---Screen dimensions string: `"WIDTHxHEIGHT WIDTHxHEIGHT DEPTH"`.
---@type string
MM.screenSize = ""

---OS name with version, e.g. `"macOS 15.5"`.
---@type string
MM.osName = ""

---OS version string, e.g. `"15.5.0"`.
---@type string
MM.osVersion = ""

---Language code of the MoneyMoney user interface, e.g. `"de"` or `"en"`.
---Useful to emit extension error messages in the user's language.
---@type string
MM.language = ""

---WebKit locale string for web views, e.g. `"de-DE"`.
---@type string
MM.webkitLocale = ""

---Build variant marker: exactly one of `MM.DEBUG`, `MM.BETA`, `MM.RETAIL`,
---and `MM.APPSTORE` is set (as an empty string); the others are nil.
---Set for debug/development builds.
---@type string?
MM.DEBUG = nil

---Set (as empty string) for the Mac App Store build, nil otherwise.
---@type string?
MM.APPSTORE = nil

---Set (as empty string) for beta channel builds, nil otherwise.
---@type string?
MM.BETA = nil

---Set (as empty string) for the retail (direct download) build, nil otherwise.
---@type string?
MM.RETAIL = nil

-- ── Key and Opaque Types ─────────────────────────────────────────────────────

---RSA key table used by the RSA functions. All key fields are binary strings
---(big-endian). Returned by `MM.rsaGenerateKeys` and `MM.pkcs8decode`.
---@class MM.RSAKey
---@field type? "rsa" Key type; set by `MM.pkcs8decode`
---@field n string Modulus
---@field e string Public exponent
---@field d? string Private exponent (private keys only)
---@field p? string First prime factor (private keys only)
---@field q? string Second prime factor (private keys only)
---@field dmp1? string CRT exponent `d mod (p-1)` (optional)
---@field dmq1? string CRT exponent `d mod (q-1)` (optional)
---@field iqmp? string CRT coefficient `q^-1 mod p` (optional)

---Elliptic curve key table used by `MM.ecSign`/`MM.ecVerify`.
---Returned by `MM.ecGenerateKeys` and `MM.pkcs8decode`.
---For Ed25519, `x` and `d` are the raw 32-byte public/private keys and `y` is absent.
---@class MM.ECKey
---@field type? "ec"|"ed25519" Key type; set by `MM.pkcs8decode`
---@field curve string Curve name, e.g. `"prime256v1"` or `"ed25519"`
---@field x string Binary public key X coordinate (Ed25519: public key)
---@field y? string Binary public key Y coordinate (ECDSA only)
---@field d? string Binary private key scalar (private keys only)

---Opaque big number object for arbitrary-precision arithmetic.
---Created by `MM.hexToBigNum()`, consumed by `MM.bigNumToHex()` and arithmetic functions.
---@class MM.BigNum

--#endregion MM Table — Global Utility Functions and Properties

--#region Connection Object

---HTTPS connection object with cookie jar, persistent state, and HTTP/WebSocket support.
---
---For HTTP: `Connection()` creates a standard HTTPS connection.
---For WebSocket: `Connection(wsUrl)` or `Connection(wsUrl, protocols, useragent, language)`.
---
---All connections within one script run share a cookie store. Cookies are
---extracted automatically from HTTP headers and `<meta>` tags and deleted
---after the script ends. Requests use HTTP pipelining and reuse the same
---HTTPS connection as long as the server is not changed via the URL.
---@class MM.Connection
---@field useragent string User-Agent header value. Readable and writable. Set it to simulate a specific browser or mobile device.
---@field language string Accept-Language header value. Readable and writable. Default: the operating system language.
---@field redirects boolean Whether to follow HTTP redirects automatically. Default: `true`.
local Connection = {}

---@alias MM.Conection.RequestMethod
---| "GET"
---| "POST"
---| "PUT"
---| "PATCH"
---| "DELETE"

---Send an HTTP request.
---
---Returns five values. The HTTP status code is **not** returned directly.
---For JSON-based REST APIs, set the `Accept` header to `"application/json"`:
---the server response is then returned to the script even on HTTP errors.
---Otherwise, an HTTP error aborts the script and shows a GUI error message.
---
---The return values are ordered so they feed directly into `HTML(...)`.
---@param method MM.Conection.RequestMethod HTTP method
---@param url string Absolute or relative URL. The first request needs an absolute URL; relative URLs resolve against the last requested URL.
---@param postContent? string Request body (for POST/PUT/PATCH)
---@param postContentType? string Content-Type header, e.g. `"application/json"`
---@param headers? table<string, string> Additional HTTP headers
---@return string content Response body (binary)
---@return string charset Response character encoding, derived from the HTTP headers and HTML `<meta>` tags
---@return string mimeType Response MIME type, derived from the HTTP headers and HTML `<meta>` tags
---@return string filename Content-Disposition filename
---@return table<string, string> headers Response headers dictionary
function Connection:request(method, url, postContent, postContentType, headers) end

---Shorthand for a GET request. Returns `(content, charset, mimeType)`.
---@param url string Absolute or relative URL
---@return string content
---@return string charset
---@return string mimeType
function Connection:get(url) end

---Shorthand for a POST request. Returns `(content, charset, mimeType)`.
---The documented shorthand stops at `postContentType`; `headers` also works.
---@param url string Absolute or relative URL
---@param postContent string Request body
---@param postContentType? string Content-Type header
---@param headers? table<string, string> Additional headers
---@return string content
---@return string charset
---@return string mimeType
function Connection:post(url, postContent, postContentType, headers) end

---Close the connection. Connections are auto-closed when the script ends.
function Connection:close() end

---Return the URL of the last request (after redirects).
---@return string url
function Connection:getBaseURL() end

---Manually set the base URL for subsequent relative URL resolution.
---@param url string New base URL
function Connection:setBaseURL(url) end

---Set a cookie using Set-Cookie header syntax.
---@param cookie string Cookie string, e.g. `"name=value; path=/"`
function Connection:setCookie(cookie) end

---Return all cookies valid for the current URL as a semicolon-separated string.
---@return string cookies e.g. `"name1=value1; name2=value2"`
function Connection:getCookies() end

---Receive a WebSocket message or async HTTP response. Blocks until data arrives.
---For WebSocket: returns the message string (or nil on close/error).
---For async HTTP: returns the same 5-tuple as `Connection:request()`.
---@return string? content Message or response body
---@return string? charset Response charset (async HTTP only)
---@return string? mimeType Response MIME type (async HTTP only)
---@return string? filename Content-Disposition filename (async HTTP only)
---@return table<string, string>? headers Response headers (async HTTP only)
function Connection:receive() end

---Send a WebSocket message.
---@param message string Message to send (text frame)
---@return boolean success True if sent successfully
function Connection:send(message) end

--#endregion Connection object

--#region HTML Object

---HTML/XML parser and DOM manipulation object.
---Supports XPath 1.0 queries with lowercase tag and attribute names.
---@class MM.HTML
local HTML_class = {}

---Select elements using an XPath 1.0 expression.
---Tag and attribute names must be lowercase in the query.
---@param query string XPath expression, e.g. `"//form[@id='loginForm']"`
---@return MM.HTMLElements elements
function HTML_class:xpath(query) end

---Generate a formatted HTML string (UTF-8 encoded) of this document/element.
---The output is not necessarily identical to the original HTML code.
---@return string html
function HTML_class:html() end

---Replace an element matched by XPath with new HTML content.
---@param xpath string XPath expression identifying the element to replace
---@param content string New HTML content to insert
---@return MM.HTML html Modified document
function HTML_class:replace(xpath, content) end

---Selected HTML elements collection. Returned by `html:xpath()` and chainable methods.
---@class MM.HTMLElements
local HTMLElements = {}

---Return the number of elements in the selection.
---@return integer count
function HTMLElements:length() end

---Select the nth element (1-indexed).
---@param n integer Element index, starting at 1
---@return MM.HTMLElements element Single-element selection, empty if `n` is out of range
function HTMLElements:get(n) end

---Iterate over all elements. The callback receives `(index, element)`.
---Return `false` from the callback to break the iteration.
---@param callback fun(index: integer, element: MM.HTMLElements): boolean?
function HTMLElements:each(callback) end

---Reverse the order of elements in the selection.
---@return MM.HTMLElements reversed
function HTMLElements:reverse() end

---Select direct child elements.
---@return MM.HTMLElements children
function HTMLElements:children() end

---Execute an XPath query relative to the **first** selected element.
---The query must be relative too, i.e. start with a `.`.
---@param query string Relative XPath, e.g. `".//td"`, `"./input[@type='hidden']"`
---@return MM.HTMLElements elements
function HTMLElements:xpath(query) end

---Get the combined text between the tags of all selected elements and their children.
---@return string text
function HTMLElements:text() end

---Get an attribute value from the first selected element.
---@param attribute string Attribute name (lowercase)
---@return string? value Attribute value, or nil if not present
---@overload fun(self: MM.HTMLElements, attribute: string, value: string) Set attribute on all elements
function HTMLElements:attr(attribute) end

---Get the value of a form field. The first selected element must be a form field.
---Unlike `attr("value")`, this respects the `disabled` attribute and evaluates
---the selected option of a `<select>`.
---@return string? value
function HTMLElements:val() end

---Select an `<option>` within a `<select>` element by value. The first selected
---element must be the `<select>`. Unlike `attr("selected", "selected")`, this
---respects the `disabled` attribute and deselects the remaining options.
---@param value string Option value to select
function HTMLElements:select(value) end

---Simulate clicking a link (`<a href>`), submit button (`<input type="submit">`,
---`<button>`), or image button (`<input type="image">`).
---For a link, the linked URL is returned; for a form, the `<input>` values are
---URL-encoded and either appended to the URL as GET parameters or returned as
---the POST body. Returns an HTTP request tuple for `connection:request()`.
---@return "GET"|"POST" method HTTP method
---@return string url Target URL
---@return string? postContent POST body (for form submissions)
---@return string? postContentType Content-Type
function HTMLElements:click() end

---Submit a form (`<form>`) without a submit button; the values of submit
---buttons are ignored. Returns an HTTP request tuple for `connection:request()`.
---@return "GET"|"POST" method HTTP method
---@return string url Form action URL
---@return string? postContent POST body (URL-encoded form data)
---@return string? postContentType Content-Type
function HTMLElements:submit() end

---Generate HTML string of the selected elements.
---@return string html
function HTMLElements:html() end

--#endregion HTML object

--#region JSON Object

---JSON parser and serializer.
---@class MM.JSON
local JSON_class = {}

---Parse JSON string into a Lua table (dictionary/array).
---@return table fields Parsed Lua table
function JSON_class:dictionary() end

---Set the Lua table to be serialized as JSON.
---Returns self for chaining: `JSON():set(t):json()`.
---@param fields table Lua table to serialize
---@return MM.JSON self
function JSON_class:set(fields) end

---Serialize the previously set table to a JSON string.
---@return string json JSON string
function JSON_class:json() end

--#endregion JSON object

--#region PDF Object

---PDF text extractor.
---@class MM.PDF
local PDF_class = {}

---Extract unformatted text content from the PDF.
---@return string text
function PDF_class:text() end

--#endregion PDF Object

--#region Extension Registration Tables

---Registration table for WebBanking extensions. Passed to the global `WebBanking{}` call.
---
---Labels, count, order, and input rules of the login dialog's credential
---fields are bank parameters maintained centrally by MoneyMoney per service
---name; they cannot be set by the extension.
---@class MM.WebBankingParams
---@field version number Version number of the extension (e.g. `1.15`)
---@field description? string Human-readable description
---@field country? string|string[] ISO country code(s), e.g. `"de"` or `{"de","at","lu"}`
---@field url? string URL of the online banking entry page
---@field services? string[] Service names shown in the account setup wizard
---@field paymentTypes? MM.PaymentTypeConst[] Supported payment types
---@field singleBooking? MM.PaymentTypeConst[] Payment types requiring single booking
---@field batchBooking? MM.PaymentTypeConst[] Payment types supporting batch booking
---@field maxBatchSize? integer Maximum number of payments in a batch
---@field standingOrderDaySelection? boolean Whether user can select execution day

---Registration table for Exporter extensions. Passed to the global `Exporter{}` call.
---@class MM.ExporterParams
---@field version number Version number
---@field format string Display name for the export format
---@field fileExtension string File extension without dot, e.g. `"csv"`, `"xml"`, `"qif"`
---@field reverseOrder? boolean Reverse chronological order
---@field description? string Human-readable description
---@field options? MM.ExporterOption[] User-selectable options in the export dialog
---@field bundleIdentifier? string macOS bundle ID of target app
---@field hidden? boolean Hide from the export format list

---An option in the exporter dialog.
---@class MM.ExporterOption
---@field label string Display label
---@field name string Option identifier key
---@field type? "radio" Widget type (`"radio"` for radio buttons). Default: checkbox.
---@field default? boolean Default state (true = checked/selected)

--#endregion Extension Registration Tables

--#region Global Constants

---@alias MM.Timestamp integer POSIX timestamp (seconds since epoch)

---Banking protocol identifier. Passed to `SupportsBank`, `InitializeSession`, `InitializeSession2`.
---@alias MM.ProtocolConst
---| `ProtocolFinTS`       # FinTS/HBCI — extension supplements native FinTS
---| `ProtocolWebBanking`  # Web scraping — extension handles all communication
---| `ProtocolAPI0`
---| `ProtocolAPI1`
---| `ProtocolAPI2`
---| `ProtocolAPI3`
---| `ProtocolAPI4`
---| `ProtocolAPI5`
---| `ProtocolAPI6`
---| `ProtocolAPI7`
---| `ProtocolPSD0`
---| `ProtocolPSD1`
---| `ProtocolPSD2`
---| `ProtocolPSD3`
---| `ProtocolPSD4`
---| `ProtocolPSD5`
---| `ProtocolPSD6`
---| `ProtocolPSD7`

---FinTS/HBCI protocol — extension supplements the native FinTS implementation.
---@type MM.ProtocolConst
ProtocolFinTS = ""

---Standard web scraping protocol — extension handles all banking communication.
---@type MM.ProtocolConst
ProtocolWebBanking = ""

---@type MM.ProtocolConst
ProtocolAPI0 = ""
---@type MM.ProtocolConst
ProtocolAPI1 = ""
---@type MM.ProtocolConst
ProtocolAPI2 = ""
---@type MM.ProtocolConst
ProtocolAPI3 = ""
---@type MM.ProtocolConst
ProtocolAPI4 = ""
---@type MM.ProtocolConst
ProtocolAPI5 = ""
---@type MM.ProtocolConst
ProtocolAPI6 = ""
---@type MM.ProtocolConst
ProtocolAPI7 = ""

---@type MM.ProtocolConst
ProtocolPSD0 = ""
---@type MM.ProtocolConst
ProtocolPSD1 = ""
---@type MM.ProtocolConst
ProtocolPSD2 = ""
---@type MM.ProtocolConst
ProtocolPSD3 = ""
---@type MM.ProtocolConst
ProtocolPSD4 = ""
---@type MM.ProtocolConst
ProtocolPSD5 = ""
---@type MM.ProtocolConst
ProtocolPSD6 = ""
---@type MM.ProtocolConst
ProtocolPSD7 = ""

---Account type constant for `MM.Account.type`.
---`AccountTypeGiro` through `AccountTypeOther` are the officially documented
---types; the remaining constants also exist but are not part of the public
---API description.
---@alias MM.AccountTypeConst string

---Current account / checking account (Girokonto).
---@type MM.AccountTypeConst
AccountTypeGiro = ""

---Savings account (Sparkonto).
---@type MM.AccountTypeConst
AccountTypeSavings = ""

---Fixed-term deposit (Festgeldkonto).
---@type MM.AccountTypeConst
AccountTypeFixedTermDeposit = ""

---Loan account (Darlehenskonto).
---@type MM.AccountTypeConst
AccountTypeLoan = ""

---Credit card account.
---@type MM.AccountTypeConst
AccountTypeCreditCard = ""

---Securities portfolio / depot.
---@type MM.AccountTypeConst
AccountTypePortfolio = ""

---Other account type.
---@type MM.AccountTypeConst
AccountTypeOther = ""

---Cash account.
---@type MM.AccountTypeConst
AccountTypeCash = ""

---PayPal account.
---@type MM.AccountTypeConst
AccountTypePayPal = ""

---Insurance contracts account.
---@type MM.AccountTypeConst
AccountTypeInsuranceContracts = ""

---@alias MM.PaymentTypeConst string

---Standard SEPA credit transfer.
---@type MM.PaymentTypeConst
PaymentTypeTransfer = ""
---@type MM.PaymentTypeConst
PaymentTypeScheduledTransfer = ""
---@type MM.PaymentTypeConst
PaymentTypeInstantTransfer = ""
---@type MM.PaymentTypeConst
PaymentTypeBatchTransfer = ""
---@type MM.PaymentTypeConst
PaymentTypeInstantBatchTransfer = ""
---@type MM.PaymentTypeConst
PaymentTypeScheduledBatchTransfer = ""
---@type MM.PaymentTypeConst
PaymentTypeStandingOrder = ""
---@type MM.PaymentTypeConst
PaymentTypeDirectDebit = ""
---@type MM.PaymentTypeConst
PaymentTypeDirectDebitBatch = ""
---@type MM.PaymentTypeConst
PaymentTypeB2bDirectDebit = ""
---@type MM.PaymentTypeConst
PaymentTypeB2bDirectDebitBatch = ""
---@type MM.PaymentTypeConst
PaymentTypeForeignCurrencyTransfer = ""

---Sentinel constant returned from `InitializeSession`/`InitializeSession2` to indicate
---that the server rejected the login credentials. MoneyMoney then stops
---refreshing the affected accounts automatically until the user re-enters the
---credentials, preventing a server-side password lockout.
---@type string
LoginFailed = ""

---Sentinel constant indicating that no TAN/2FA is required.
---@type string
NoTanRequired = ""

--#endregion Global Constants

--#region Global Constructor Functions

---Create an HTTPS connection object with persistent cookies and session state.
---
---For WebSocket connections, pass the `wss://` URL as the first argument.
---@param wsUrl? string WebSocket URL (e.g. `"wss://api.example.com"`). Omit for HTTP.
---@param protocols? string[] WebSocket sub-protocols
---@param useragent? string User-Agent header
---@param language? string Accept-Language header
---@return MM.Connection connection
function Connection(wsUrl, protocols, useragent, language) end

---Create an HTML/XML parser from content.
---@param content string HTML/XML document content
---@param charset? string Character encoding. Extracted from the `<meta>` tags if omitted.
---@param mimeType? string MIME type hint, e.g. `"text/html"`
---@return MM.HTML html Parsed document
function HTML(content, charset, mimeType) end

---Create a JSON parser/serializer.
---When called with a JSON string, parse it (then call `:dictionary()`).
---When called with no arguments, create an empty object for serialization.
---@param json? string JSON string to parse
---@return MM.JSON json
function JSON(json) end

---Create a PDF text extractor.
---@param pdfData string Binary PDF data
---@return MM.PDF pdf
function PDF(pdfData) end

---Register a WebBanking extension with MoneyMoney.
---Must be called at module scope. After this call, MoneyMoney sets the global
---variables `version`, `url`, `services`, `description`, and `extensionName`.
---@param params MM.WebBankingParams Registration parameters
function WebBanking(params) end

---Register an Exporter extension.
---The module must also define `WriteHeader`, `WriteTransactions`, and `WriteTail` functions.
---@param params MM.ExporterParams Registration parameters
function Exporter(params) end

---Register an Importer extension.
---@param params table Registration parameters
function Importer(params) end

---Look up bank details by bank code (BLZ).
---@param bankCode string Bank code (BLZ) to look up
---@return MM.BankInfoResult? info Bank details, or nil if not found
function BankInfo(bankCode) end

---Convert an ISO 4217 numeric currency code to its alphabetic code.
---@param numericCode integer e.g. `978`
---@return MM.CurrencyCodeResult result e.g. `{code = "EUR"}`
function CurrencyCode(numericCode) end

---Look up an ISO 20022 purpose code description.
---@param code string e.g. `"SALA"`
---@return MM.PurposeCodeResult result e.g. `{name = "Salary payment"}`
function PurposeCode(code) end

---Look up an ISO 20022 transaction code description.
---@param code string e.g. `"CWDL"`
---@return MM.TransactionCodeResult result
function TransactionCode(code) end

---Look up an ISO 18245 merchant category code description.
---@param code string e.g. `"5411"`
---@return MM.MerchantCodeResult result
function MerchantCode(code) end

--#endregion Global Constructor Functions

--#region Lookup Result Types

---@class MM.BankInfoResult
---@field bic string BIC code
---@field branchBic string Branch-level BIC
---@field name string Bank name
---@field possessive string Possessive form, e.g. `"der HypoVereinsbank"`
---@field website string Bank website URL

---@class MM.CurrencyCodeResult
---@field code string ISO 4217 alphabetic code, e.g. `"EUR"`

---@class MM.PurposeCodeResult
---@field name string Human-readable purpose code name

---@class MM.TransactionCodeResult
---@field name string Human-readable transaction code name

---@class MM.MerchantCodeResult
---@field name string Human-readable merchant category name

--#endregion Lookup Result Types

--#region Persistent Storage

---Global persistent key-value store, kept per bank connection and restored on
---the next script run. Typical use: device keys, registration IDs, or session
---tokens that avoid repeated strong customer authentication.
---
---Supported value types: numbers, booleans, strings (may contain binary
---data), and tables (including nested ones). Connection objects are persisted
---as a special case (last URL, cookies, `useragent`, `language`), so server
---sessions can survive app restarts. HTML objects are persisted as UTF-8 HTML
---and re-parsed on load. Functions and other objects (e.g. JSON objects and
---HTML element lists) are not persisted and read back as nil.
---
---Always expect missing values when reading: the store is empty for newly set
---up bank connections, and single fields may be nil when written by an older
---script version. Clear all stored state with `LocalStorage = {}`.
---@type table<string, any>
LocalStorage = {}

--#endregion Persistent Storage

--#region Data Structures

---Account descriptor. Returned by `ListAccounts`, passed to `RefreshAccount` et al.
---
---If `type` is absent, MoneyMoney derives the account type from account number
---and name when the account is created; a 16-character or masked (`x`, `*`)
---account number counts as a credit card. An explicit value is taken as-is,
---including `AccountTypeOther`. The type is only set at creation and never
---changed on refresh.
---@class MM.Account
---@field name? string Account display name
---@field owner? string Account holder name
---@field accountNumber? string Account number or IBAN
---@field subAccount? string Sub-account identifier
---@field portfolio? boolean `true` for securities portfolios
---@field bankCode? string Bank code (BLZ) or BIC
---@field currency? string Account currency (ISO 4217)
---@field iban? string IBAN
---@field bic? string BIC
---@field type? MM.AccountTypeConst Account type constant
---@field comment? string Free-text comment. Only set by MoneyMoney on accounts passed to the extension; not read from accounts the extension returns.
---@field bank? {bankCode: string} Bank reference when passed back from MoneyMoney

---Transaction descriptor. Element of `RefreshAccountResponse.transactions`.
---@class MM.Transaction
---@field name? string Payer/payee name
---@field accountNumber? string Counterparty account number or IBAN
---@field bankCode? string Counterparty bank code or BIC
---@field amount number Transaction amount (positive = credit, negative = debit)
---@field currency? string Transaction currency (ISO 4217). Defaults to account currency.
---@field bookingDate MM.Timestamp Booking date
---@field valueDate? MM.Timestamp Value date
---@field purpose? string Payment reference / memo. Multiline via `"\n"`.
---@field transactionCode? integer Business transaction code (Geschäftsvorfallcode), the numeric German text key
---@field textKeyExtension? integer Text key extension (Textschlüsselergänzung, FinTS-specific)
---@field purposeCode? string SEPA purpose code (e.g. `"SALA"`)
---@field bookingKey? string SWIFT booking key
---@field bookingText? string Transaction type description (e.g. `"Lastschrift"`)
---@field primanotaNumber? string Primanota number
---@field batchReference? string Batch/collective reference
---@field endToEndReference? string SEPA end-to-end reference
---@field mandateReference? string SEPA direct debit mandate reference
---@field creditorId? string SEPA creditor identifier
---@field returnReason? string Return/reversal reason code
---@field booked? boolean `true` for booked, `false` for pending. Default: `true`.
---@field category? string Category assignment hint
---@field comment? string Free-text comment
---@field transactionId? string Transaction identifier for `MM.IsKnownTransactionId` lookups. Kept for booked transactions only; must be unique within the account for lookups to succeed.
---@field prettyPrint? boolean If `false`, skip automatic formatting
---@field timezone? string Timezone, e.g. `"GMT"`, `"Europe/Berlin"`
---@field ultimateName? string Ultimate debtor/creditor name (SEPA)

---Securities position descriptor. Element of `RefreshAccountResponse.securities`.
---@class MM.Security
---@field name? string Security name
---@field isin? string ISIN code
---@field securityNumber? string WKN (German securities identification number)
---@field quantity? number Number of shares or nominal amount
---@field currencyOfQuantity? string Currency if `quantity` is nominal; `nil` for share count
---@field purchasePrice? number Purchase price or purchase quote
---@field currencyOfPurchasePrice? string Purchase price currency, if it differs from the account currency
---@field exchangeRateOfPurchasePrice? number Exchange rate at purchase time
---@field price? number Current price or quote
---@field currencyOfPrice? string Current price currency, if it differs from the account currency
---@field exchangeRateOfPrice? number Current exchange rate
---@field amount? number Position value in account currency
---@field originalAmount? number Position value in original/foreign currency
---@field currencyOfOriginalAmount? string Original currency code
---@field market? string Exchange/market name
---@field tradeTimestamp? MM.Timestamp Price quote timestamp

---Response from `RefreshAccount`.
---
---Portfolios are expected to return only `securities`; all other accounts
---`balance` (or `balances`) and `transactions`. Missing or nil values produce
---a GUI error message.
---@class MM.RefreshAccountResponse
---@field balance? number Account balance
---@field balances? {[1]: number, [2]: string}[] Balances as `{amount, currency}` tuples. Should only be returned instead of `balance` when the account holds balances in multiple currencies.
---@field pendingBalance? number Sum of pending transactions
---@field pendingBalances? {[1]: number, [2]: string}[] Multi-currency pending balances as `{amount, currency}` tuples, analogous to `balances`
---@field transactions? MM.Transaction[] Transactions ordered by booking date, newest first. Each needs at least `amount` and `bookingDate`. Transactions already in the database are dropped as duplicates.
---@field securities? MM.Security[] Portfolio positions
---@field bonusPoints? number Number of points in a bonus program
---@field paymentTypes? MM.PaymentTypeConst[] Payment types supported by this account

---SEPA direct debit sequence type.
---@alias MM.DirectDebitSequence
---| "FRST" # First collection
---| "RCUR" # Recurring collection
---| "OOFF" # One-off collection
---| "FNAL" # Final collection

---SEPA charge bearer code (foreign currency transfers).
---@alias MM.ChargeBearer
---| "DEBT" # Debtor pays all charges
---| "SHAR" # Charges shared between debtor and creditor
---| "CRED" # Creditor pays all charges

---Payment descriptor passed to `SubmitPayment`.
---
---For single payments, all fields are on the table directly.
---For batch payments, per-entry fields are in the `batch` array; the outer table
---has only envelope fields (type, amount, currency, scheduledDate, batchReference,
---batchBooking, orderId).
---@class MM.Payment
--- Always present ─────────────────────────────────────────────────────────────
---@field type MM.PaymentTypeConst Payment type
---@field amount number Payment amount
---@field currency string ISO 4217 currency code (e.g. `"EUR"`)
--- Core fields (single payments or batch entries) ─────────────────────────────
---@field name? string Recipient/creditor name
---@field accountNumber? string Recipient IBAN or account number
---@field bankCode? string Recipient BIC or bank code
---@field purpose? string Payment reference / remittance info (newlines replaced with spaces)
---@field endToEndReference? string SEPA end-to-end reference (only if non-empty)
---@field purposeCode? string SEPA purpose code (only if non-empty)
--- Foreign currency transfer fields ───────────────────────────────────────────
---@field street? string Recipient street address
---@field place? string Recipient city
---@field country? string Recipient country (2-letter ISO code)
---@field bankName? string Recipient bank name
---@field bankStreet? string Recipient bank street address
---@field bankPlace? string Recipient bank city
---@field bankCountry? string Recipient bank country (2-letter ISO code)
---@field foreignCurrencyCharges? MM.ChargeBearer SEPA charge bearer code
---@field instructions? string Payment instructions
--- Direct debit fields ────────────────────────────────────────────────────────
---@field directDebitSequence? MM.DirectDebitSequence SEPA sequence type
---@field creditorId? string SEPA creditor ID (only if non-empty)
---@field mandateReference? string SEPA mandate reference (only if non-empty)
---@field mandateDate? MM.Timestamp SEPA mandate signature date
--- Standing order fields ──────────────────────────────────────────────────────
---@field standingOrderStart? MM.Timestamp First execution date
---@field standingOrderEnd? MM.Timestamp Last execution date (nil = indefinite)
---@field standingOrderUnit? MM.StandingOrderUnit Recurrence unit: month or week
---@field standingOrderPeriod? integer Units between executions (1 = every unit, 3 = every 3rd, etc.)
---@field standingOrderDay? integer Day of month (97, 98, 99: third to last, second to last, last) or ISO weekday (1 = Monday)
--- Scheduling ─────────────────────────────────────────────────────────────────
---@field scheduledDate? MM.Timestamp Execution date (non-standing-order scheduled transfers)
--- Batch envelope fields ──────────────────────────────────────────────────────
---@field batch? MM.Payment[] Sub-payments for batch transfers. Each entry has its own core/DD/foreign fields.
---@field batchBooking? boolean `true` if batch should be booked as a single entry (only when >= 2 entries)
---@field batchReference? string Collective batch reference (only if non-empty)
--- Set by MoneyMoney between steps ────────────────────────────────────────────
---@field orderId? string Order ID from previous step's return (set by MoneyMoney, not the UI)

---Payment status returned by `SubmitPayment`.
---@alias MM.PaymentStatus
---| "info"     # Informational — continue with next step
---| "accepted" # Payment finalized successfully
---| "pending"  # Payment pending — typically used with `poll=true` for decoupled SCA
---| "rejected" # Payment was rejected
---| "denied"   # Payment was denied

---Error string returned instead of a table to abort with an error message.
---@alias MM.ErrorMessage string

---Session type passed to `InitializeSession2` as the 7th argument.
---@alias MM.SessionType
---| "refresh"    # Normal account refresh
---| "payment"    # Payment submission
---| "new account" # Account setup wizard
---| "statement"  # PDF statement fetching
---| "tan media"  # TAN media management

---Login credentials passed on step 1: the values of the login dialog's input
---fields in display order: username, optional second and third field (e.g.
---customer number or API secret), password last. Fields the bank connection
---does not have are omitted from the array.
---@class MM.LoginCredentials
---@field [1] string Username (first input field)
---@field [2] string Second field, or password when there are only two fields
---@field [3]? string Third field, or password (when three fields)
---@field [4]? string Password (when four fields)

---Response passed on follow-up calls after a 2FA challenge.
---@class MM.TanCredentials
---@field [1] string User's answer to the previous challenge: the entered text, a captcha solution token, the `code` parameter of a browser approval redirect, or `""` for decoupled methods
---@field [2] string Localized cancel message the extension should return when polling has to end unsuccessfully
---@field [3] boolean `true` while another polling attempt is allowed. MoneyMoney controls the number of attempts; the extension should not implement its own time limit.

---Credentials argument for `InitializeSession2`. Contents depend on context:
---  - **Step 1** (login): `MM.LoginCredentials` — login fields
---  - **After TAN method selection**: `{[1]: MM.TanMethod}` — single-element array with selected method table
---  - **After TAN challenge**: `MM.TanCredentials` — TAN value + cancel message + poll flag
---@alias MM.Credentials MM.LoginCredentials|MM.TanCredentials|MM.TanMethod[]

---Response from `SubmitPayment`. Must be a table or error string — nil is not valid.
---For TAN challenges during payment, only `challenge` and `poll` are used.
---@class MM.PaymentResponse
---@field status? MM.PaymentStatus Payment status (required on step 3 for accepted/pending)
---@field errorMessage? string Error description — mutually exclusive with orderId (if set, session aborts)
---@field orderId? string Server-assigned payment order ID (only read when errorMessage is absent; saved to payment.orderId)
---@field vop? string Verification of Payee (VoP) description shown to the user
---@field challenge? MM.ChallengeData TAN challenge, auto-classified by content.
---@field poll? boolean Enable decoupled polling. On step 3 with status="pending", triggers polling loop.

---Return type of `SubmitPayment`. Table with payment result, or error string. Nil is invalid.
---@alias MM.SubmitPaymentResult MM.PaymentResponse|MM.ErrorMessage

--#endregion Data Structures

--#region Extension Interfaces

-- ── Supporting data types ─────────────────────────────────────────────────────

---Extended response from `SupportsBank`.
---@class MM.SupportsBankResponse
---@field url? string Base URL — pushed as Lua global `url` for `Connection()` to use
---@field api? string API identifier — pushed as Lua global `api`
---@field since? MM.Timestamp Unix timestamp; sets the lower bound for the "fetch transactions since" date picker in account setup

---Callback passed by MoneyMoney as the 3rd argument to `RefreshAccount`.
---Looks up a previously stored transaction by its `transactionId`.
---Returns the stored transaction only when exactly one booked transaction of
---the account carries the identifier; nil otherwise, i.e., also for unknown,
---duplicated, or pending identifiers. The returned table holds the stored
---transaction fields, but not the `transactionId` itself.
---@alias MM.IsKnownTransactionId fun(transactionId: string): MM.Transaction?

---TAN challenge data. MoneyMoney auto-detects the content type and displays
---it accordingly: plain text, PNG/JPEG image data, a URL (browser approval,
---or QR code with `tanMethod.name = MM.localizeText("QR Code")`), chipTAN
---data (QR code, flicker code), or the script URL of a supported captcha
---provider (Google reCAPTCHA, hCaptcha, FriendlyCaptcha, Amazon WAF) with
---`sitekey`, optional `type=checkbox`, and `referer` query parameters.
---@alias MM.ChallengeData string

---2FA challenge returned by `InitializeSession2`, `RefreshAccount`, and `FetchStatements`.
---
---At least one of `challenge`, `label`, `tanMethod`, or `tanMethods` must be
---set, otherwise the table is not recognized as a challenge. When `tanMethods`
---is present, a selection dialog is shown and `challenge`, `label`, and
---`tanMethod` are ignored.
---@class MM.SessionChallenge
---@field challenge? MM.ChallengeData The challenge itself: a text, PNG/JPEG image data, a URL (`https://…`), or chipTAN data (QR code, flicker code). Display is auto-detected from the content; HTML tags in a text are stripped.
---@field label? string Input field label, e.g. `"TAN"` or `"Code"`. Without `label`, the dialog shows no input field.
---@field tanMethods? MM.TanMethod[] TAN methods for the user to choose from first. The chosen method's table is passed in `credentials[1]` on the next call.
---@field tanMethod? MM.TanMethod TAN method used for this challenge. Determines input length and charset as well as the texts generated by MoneyMoney.
---@field title? string Instruction text above the challenge. Default: generated by MoneyMoney to match TAN method and session context.
---@field poll? boolean `true` for decoupled methods (approval in a banking app): the extension polls the status instead of waiting for input. Only effective when no `label` is given. Combined with `tanMethods`, the selection dialog also waits for approval via the first app method of the list.
---@field startCode? string Start code of a chipTAN method. Inserted into the instruction text generated by MoneyMoney.
---@field button? string `"next"` shows a "Next" button instead of "OK" when another challenge follows
---@field appToApp? string Name of a banking app. A URL in `challenge` is then shown as a QR code (which the user scans to launch the app) instead of being opened in the browser.
---@field state? string The `state` parameter of an OAuth URL in `challenge`. If absent, MoneyMoney reads it from the URL or appends a random value itself.

---TAN method name. Controls which UI MoneyMoney shows for the TAN challenge.
---
---Using `poll=true` on the SessionChallenge triggers the decoupled polling UI
---(spinner, no TAN input) regardless of name.
---Canonical entries control UI behavior; any other string is accepted and rendered
---verbatim. Banks routinely send unrecognized labels (e.g. raw `Selection` options
---before normalization), so the alias falls back to `string`.
---@alias MM.TanMethodName string
---| "iTAN"               # Indexed TAN list entry
---| "mobileTAN"          # SMS code entry (also: `smsTAN`, `mTAN`)
---| "chipTAN manuell"    # Manual chipTAN (type start code on TAN generator)
---| "chipTAN Bluetooth"  # chipTAN via Bluetooth reader
---| "chipTAN optisch"    # Optical chipTAN (flicker code animation)
---| "chipTAN QR"         # QR-based chipTAN
---| "chipTAN photo"      # Photo-based chipTAN
---| "photoTAN"           # photoTAN image (user reads code from image)
---| "photoTAN push"      # Decoupled photoTAN app approval
---| "pushTAN"            # Decoupled app approval (also: `appTAN`, `BestSign`, `SecureGo plus`, `easyTAN`, `SealOne`)

---TAN method descriptor. Passed to MoneyMoney in the `tanMethod`/`tanMethods`
---fields of a challenge (or returned by `GetTanMethods`), and passed back to
---the extension in `credentials[1]` after the user's selection. The TAN
---methods of a FinTS/HBCI connection (`hbciTanMethods`) share this structure.
---@class MM.TanMethod
---@field name MM.TanMethodName Display name, **required**: the entry is skipped if nil. For app methods known to MoneyMoney (e.g. `"pushTAN"`, `"appTAN"`, `"photoTAN push"`) and for `MM.localizeText("QR Code")`, MoneyMoney generates matching dialog texts.
---@field hbciMethod? string Method identifier, usually three digits as in FinTS (e.g. `"700"`). MoneyMoney remembers the user's selection by this identifier and preselects it next time.
---@field webMethod? string Extension-specific identifier
---@field mediumName? string TAN medium description, e.g. a masked phone number or a device name. Displayed next to the `name` in the selection dialog.
---@field errorMessage? string If set, the method is shown in the selection dialog but not selectable; the message explains the reason.
---@field isPreferred? boolean Preselect this method in the selection dialog
---@field isNumeric? boolean Numeric-only input (default: true). If false, letters are allowed and input is uppercased unless `isUppercase` is false.
---@field isUppercase? boolean Convert input to uppercase
---@field tanLength? integer Fixed input length (default: 6)
---@field minLength? integer Minimum input length, alternative to `tanLength`
---@field maxLength? integer Maximum input length, alternative to `tanLength`
---@field label? string Only in tables passed by MoneyMoney: input field label derived from the name, e.g. `"TAN"`. May be reused as the challenge's `label`.

---@class MM.FetchStatementsResponse
---@field statements MM.Statement[] Documents, ordered with the newest first

---A single document fetched by `FetchStatements`.
---@class MM.Statement
---@field pdf string Binary PDF data, the only required field. May also be a ZIP archive; contained PDF files are unpacked automatically.
---@field identifier? string|table Unique identifier, e.g. a server-side document ID. Lets MoneyMoney recognize already fetched documents (see `knownIdentifiers`). Documented as string; tables also work.
---@field name? string Display name of the document
---@field filename? string Suggested filename for the document
---@field creationDate? MM.Timestamp Creation date
---@field timezone? string Timezone in which `creationDate` is to be interpreted, e.g. `"Europe/Berlin"`
---@field account? MM.Account Account to assign the document to (from the `accounts` parameter of `FetchStatements`). Default: the current account.

---@class MM.FetchScheduledPaymentsResponse
---@field payments MM.ScheduledPayment[]

---@alias MM.StandingOrderUnit
---| "M" # Month
---| "W" # Week

---A scheduled or standing payment.
---@class MM.ScheduledPayment
---@field type MM.PaymentTypeConst Payment type (`PaymentTypeScheduledTransfer` or `PaymentTypeStandingOrder`)
---@field orderId string Unique payment identifier
---@field accountNumber? string Recipient IBAN
---@field bankCode? string Recipient BIC
---@field name? string Recipient name
---@field purpose? string Payment purpose/memo
---@field purposeCode? string SEPA purpose code
---@field amount number Payment amount
---@field currency? string Currency code
---@field timezone? string Timezone for dates, e.g. `"GMT"`
---@field scheduledDate? MM.Timestamp Execution date or next execution
---@field endToEndReference? string SEPA end-to-end reference
---@field standingOrderStart? MM.Timestamp First execution date
---@field standingOrderEnd? MM.Timestamp Last execution date (nil = indefinite)
---@field standingOrderUnit? MM.StandingOrderUnit Recurrence unit: month or week
---@field standingOrderPeriod? integer Units between executions (1 = monthly, 3 = quarterly)
---@field standingOrderDay? integer Day of month (97, 98, 99: third to last, second to last, last) or ISO weekday (1 = Monday)

-- ── MM.WebBankingExtension ────────────────────────────────────────────────────

---Interface for a Web Banking extension module.
---
---Declare your module table with `---@class MyBank : MM.WebBankingExtension`,
---implement the required fields, then re-export as globals at the bottom of
---your script so MoneyMoney can call them by name:
---
---```lua
-----@class MyBank : MM.WebBankingExtension
---local M = {}
---
---function M.SupportsBank(protocol, bankCode) ... end
---function M.InitializeSession(protocol, bankCode, username, customer, password) ... end
---function M.ListAccounts(knownAccounts) ... end
---function M.RefreshAccount(account, since) ... end
---function M.EndSession() ... end
---
---SupportsBank = M.SupportsBank
---InitializeSession = M.InitializeSession
---ListAccounts = M.ListAccounts
---RefreshAccount = M.RefreshAccount
---EndSession = M.EndSession
---```
---
---Required: `SupportsBank`, one of `InitializeSession`/`InitializeSession2`,
---`ListAccounts`, `RefreshAccount`, `EndSession`.
---All other fields are optional.
---@class MM.WebBankingExtension
--- Required ────────────────────────────────────────────────────────────────────
---@field SupportsBank fun(protocol: MM.ProtocolConst, bankCode: string, fetchStatements?: boolean, fetchScheduledPayments?: boolean, isPaymentSession?: boolean): boolean|string|MM.SupportsBankResponse Determine whether this extension handles a given bank connection. `bankCode` is the bank code or service name. Instead of `true`, the URL of the online banking entry page may be returned.
---@field ListAccounts fun(knownAccounts: MM.Account[]): MM.Account[]|MM.ErrorMessage List all accounts available for scraping. Accounts without an `accountNumber` are ignored. `knownAccounts` is only populated when the extension supplements a FinTS/HBCI bank connection; it lists the accounts that need not be scraped anymore.
---@field RefreshAccount fun(account: MM.Account, since?: MM.Timestamp, isKnownTransactionId?: MM.IsKnownTransactionId, step?: integer, credentials?: MM.TanCredentials|MM.TanMethod[]): MM.RefreshAccountResponse|MM.ErrorMessage|MM.SessionChallenge Fetch balance and transactions, or securities for one account. `since` is the booking day to deliver transactions from (older ones may be omitted); it is nil for portfolios.
---@field EndSession fun(): nil|MM.ErrorMessage Perform logout / cleanup.
--- Login — implement exactly one ───────────────────────────────────────────────
---@field InitializeSession? fun(protocol: MM.ProtocolConst, bankCode: string, username: string, customer: string, password: string, credential?: string): nil|MM.ErrorMessage Simple single-step login. `bankCode` is the bank code or service name; `customer` and `credential` hold the second and third login dialog field (empty if the bank connection has none). Prefer `InitializeSession2`.
---@field InitializeSession2? fun(protocol: MM.ProtocolConst, bankCode: string, step: integer, credentials: MM.Credentials, interactive: boolean, hbciTanMethods?: MM.TanMethod[], session?: MM.SessionType): nil|MM.ErrorMessage|MM.SessionChallenge Login with two-factor authentication: called repeatedly with increasing `step` after each challenge until it returns nil, `LoginFailed`, or an error message. `step` increases by 2 when a challenge sets `tanMethod` directly, and stays unchanged while polling, so do not rely on exact values. `interactive` is false for background refreshes, where MoneyMoney cannot show dialogs. `hbciTanMethods` is only populated for `ProtocolFinTS`, otherwise an empty array.
--- Optional ────────────────────────────────────────────────────────────────────
---@field GetTanMethods? fun(account: MM.Account): MM.TanMethod[] Return available TAN/SCA methods. Called before `InitializeSession2`.
---@field MapAccount? fun(account: MM.Account): MM.Account Map/transform an account returned by `ListAccounts`.
---@field FetchStatements? fun(accounts: MM.Account[], knownIdentifiers: table<string, boolean>, step?: integer, credentials?: MM.TanCredentials, interactive?: boolean): MM.FetchStatementsResponse|MM.SessionChallenge|MM.ErrorMessage Fetch PDF statements and other mailbox documents. Called once with all affected accounts (not per account). Documents whose `identifier` is a key of `knownIdentifiers` were fetched before and can be skipped. May return a 2FA challenge like `InitializeSession2`; it is then called again with increased `step`.
---@field FetchScheduledPayments? fun(account: MM.Account): MM.FetchScheduledPaymentsResponse|MM.ErrorMessage|nil Fetch scheduled/standing payments for an account other than a portfolio. Manual and automatic refreshes call it after `RefreshAccount`, but only if the account is new, the last fetch is at least 7 days old, or a `scheduledDate` has passed. Explicitly refreshing scheduled payments always calls it, after `InitializeSession2` (session type `"refresh"`) but without `RefreshAccount`. Cannot return a 2FA challenge. `nil` keeps the stored payments; without this callback, MoneyMoney clears them on every refresh.
---@field SubmitPayment? fun(step: integer, account: MM.Account, payment: MM.Payment, tanMethod?: MM.TanMethod, credentials?: MM.Credentials): MM.SubmitPaymentResult Submit a payment; supports multi-step 2FA flows. Must return table or error string.

-- ── MM.ExporterExtension ──────────────────────────────────────────────────────

---Interface for an Exporter extension module.
---
---```lua
-----@class MyExporter : MM.ExporterExtension
---local M = {}
---
---function M.WriteHeader(account, startDate, endDate, transactionCount, options) ... end
---function M.WriteTransactions(account, transactions, options, openingBalance, closingBalance) ... end
---function M.WriteTail(account, options) ... end
---
---WriteHeader = M.WriteHeader
---WriteTransactions = M.WriteTransactions
---WriteTail = M.WriteTail
---```
---@class MM.ExporterExtension
---@field WriteHeader fun(account: MM.Account, startDate: MM.Timestamp, endDate: MM.Timestamp, transactionCount: integer, options: table<string, boolean>) Called once before the first batch of transactions. Use `assert(io.write(...))` to write output.
---@field WriteTransactions fun(account: MM.Account, transactions: MM.Transaction[], options: table<string, boolean>, openingBalance?: number, closingBalance?: number) Called with each batch of transactions. Use `assert(io.write(...))` to write output.
---@field WriteTail fun(account: MM.Account, options: table<string, boolean>) Called once after the last batch of transactions. Use `assert(io.write(...))` to write output.

--#endregion Extension Interfaces

--#region Runtime Variables

--
-- These globals are automatically set by MoneyMoney after the `WebBanking{}`/`Exporter{}` call.
--

---Extension version number (from the registration table).
---@type number
version = 0

---Entry page URL (from the registration table).
---@type string
url = ""

---Service names array (from the registration table).
---@type string[]?
services = nil

---Extension description (from the registration table).
---@type string?
description = nil

---Extension filename without path (set by MoneyMoney at load time).
---@type string
extensionName = ""

--#endregion Runtime Variables
