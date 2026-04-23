-- SPDX-License-Identifier: MIT
-- Author: Vincent Haupert <vincent.haupert@yaxi.tech>

-- MoneyMoney Extension API — LuaCATS Type Definitions
--
-- Drop this file (or directory) into your workspace and configure your language server
-- to include it as a library. It provides full type information for the MoneyMoney
-- extension API without requiring any annotations in your extension scripts.
--
---@meta

--#region MM Table — Global Utility Functions and Properties

---Global `MM` table providing crypto, encoding, formatting, and system utilities.
---@class MM
MM = {}

---Encode binary data as Base64 string.
---@param data string Binary input
---@return string encoded Base64-encoded string
function MM.base64(data) end

---Decode Base64 string to binary data.
---@param encoded string Base64-encoded input
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
---@overload fun(amount: number, currency: string): string
---@param format string Format pattern (Unicode TR35)
---@param amount number|string Amount
---@param currency string ISO 4217 currency code
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

---Translate a text string. Wrapper for NSLocalizedString.
---Only returns a translation if the text is in MoneyMoney's string tables.
---@param text string Text to translate
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
---When `bom` is true, a byte-order mark is prepended.
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

---AES-256 encryption. Supports CBC (default) and GCM modes.
---In GCM mode, returns `(ciphertext, tag)`. In CBC mode, returns `ciphertext`.
---@param key string Binary AES key (32 bytes)
---@param iv string Binary IV (16 bytes for CBC, 12 bytes for GCM)
---@param plaintext string Data to encrypt
---@param mode? string Cipher mode, e.g. `"aes256 gcm"`. Default: CBC.
---@param aad? string Additional authenticated data (GCM only)
---@return string ciphertext
---@return string? tag Authentication tag (GCM only, 16 bytes)
function MM.aes256encrypt(key, iv, plaintext, mode, aad) end

---AES-256 decryption. Supports CBC (default) and GCM modes.
---@param key string Binary AES key (32 bytes)
---@param iv string Binary IV
---@param ciphertext string Data to decrypt (in GCM mode, may include appended auth tag)
---@param mode? string Cipher mode, e.g. `"aes256 gcm"`. Default: CBC.
---@param aad? string Additional authenticated data (GCM only)
---@return string? plaintext Decrypted data, or nil on failure
function MM.aes256decrypt(key, iv, ciphertext, mode, aad) end

---AES-128 encryption. Same interface as `aes256encrypt` but with 16-byte key.
---@param key string Binary AES key (16 bytes)
---@param iv string Binary IV
---@param plaintext string Data to encrypt
---@param mode? string Cipher mode
---@param aad? string Additional authenticated data (GCM only)
---@return string ciphertext
---@return string? tag Authentication tag (GCM only)
function MM.aes128encrypt(key, iv, plaintext, mode, aad) end

---AES-128 decryption. Same interface as `aes256decrypt` but with 16-byte key.
---@param key string Binary AES key (16 bytes)
---@param iv string Binary IV
---@param ciphertext string Data to decrypt
---@param mode? string Cipher mode
---@return string? plaintext Decrypted data, or nil on failure
function MM.aes128decrypt(key, iv, ciphertext, mode) end

---RSA encryption with the given public key.
---@param key MM.RSAKey RSA key object
---@param plaintext string Data to encrypt
---@param padding string Padding mode, e.g. `"pkcs1-oaep sha256"`, `"pkcs1-oaep sha256 sha1"`
---@return string? ciphertext Encrypted data, or nil on failure
function MM.rsaEncrypt(key, plaintext, padding) end

---RSA decryption with the given private key.
---@param key MM.RSAKey RSA key object
---@param ciphertext string Data to decrypt
---@param padding string Padding mode, e.g. `"pkcs1-oaep sha256"`
---@return string? plaintext Decrypted data, or nil on failure
function MM.rsaDecrypt(key, ciphertext, padding) end

---Generate an RSA key pair of the specified bit size.
---@param keySize integer Key size in bits (e.g. 2048, 4096)
---@return MM.RSAKey key Generated key pair
function MM.rsaGenerateKeys(keySize) end

---Compute an RSA signature.
---@param key MM.RSAKey RSA private key
---@param message string Data to sign
---@param padding string Padding/hash mode, e.g. `"pkcs1-v1_5 sha256"`
---@return string? signature Binary signature, or nil on failure
function MM.rsaSign(key, message, padding) end

---Verify an RSA signature.
---@param key MM.RSAKey RSA public key
---@param message string Original data
---@param signature string Binary signature to verify
---@param padding string Padding/hash mode, e.g. `"pkcs1-v1_5 sha256"`
---@return boolean valid True if signature is valid
function MM.rsaVerify(key, message, signature, padding) end

---Export an RSA key in PKCS#8 PEM format (public key).
---@param key MM.RSAKey RSA key object
---@return string pem PEM-encoded public key string
function MM.rsaPkcs8(key) end

---Import an RSA public key from PKCS#8 PEM format.
---@param pem string PEM-encoded key string
---@return MM.RSAKey? key Parsed key, or nil on failure
function MM.rsaPkcs8decode(pem) end

---Export an RSA key in PKCS#1 format.
---@param key MM.RSAKey RSA key object
---@return string der PKCS#1 encoded key
function MM.rsaPkcs1(key) end

---Apply RSA padding to data.
---@param data string Data to pad
---@param padding string Padding mode
---@param keySize integer Key size in bits
---@return string padded Padded data
function MM.rsaPad(data, padding, keySize) end

---Generate an elliptic curve key pair.
---@param curve string Curve name, e.g. `"prime256v1"`
---@return MM.ECKey key Key object with `.x`, `.y` (public) and `.d` (private) fields
function MM.ecGenerateKeys(curve) end

---Compute an ECDSA signature.
---@param key MM.ECKey EC key object
---@param message string Data to sign
---@param algorithm string Signature algorithm, e.g. `"ecdsa sha256"`
---@return string signature Binary DER-encoded signature
function MM.ecSign(key, message, algorithm) end

---Convert binary data to lowercase hexadecimal string.
---@param data string Binary input
---@return string hex Hex string, e.g. `"746573747573"`
function MM.binToHex(data) end

---Convert hexadecimal string to binary data.
---@param hex string Hex string (case-insensitive)
---@return string data Binary output
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

---Get or calculate a date/time with timezone conversion.
---
---Three calling conventions:
--- 1. `MM.date()` — returns the current POSIX timestamp.
--- 2. `MM.date{year=2024, month=3, day=15, hour=14, from="GMT", to="Europe/Berlin"}` — timezone-aware date construction.
--- 3. `MM.date(timestamp, offset)` — apply a relative offset. Offset format: `"-3Y"` (years), `"-31D"` (days), `"-6M"` (months).
---@overload fun(): MM.Timestamp
---@overload fun(spec: {year: integer, month: integer, day: integer, hour?: integer, min?: integer, sec?: integer, from?: string, to?: string}): MM.Timestamp
---@param timestamp MM.Timestamp Base timestamp
---@param offset string Relative offset string, e.g. `"-3Y"`, `"-31D"`, `"-6M"`
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

---Get the system's IANA timezone identifier.
---@return string timezone e.g. `"Europe/Berlin"`
function MM.timezone() end

---Get the length of a UTF-8 string in characters (not bytes).
---@param s string UTF-8 string
---@return integer length Character count
function MM.utf8len(s) end

---Extract a UTF-8-aware substring by character indices.
---@param s string UTF-8 string
---@param i integer Start character index (1-based)
---@param j? integer End character index (inclusive). Default: end of string.
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

---Application build number as string, e.g. `"503"`.
---@type string
MM.productBuild = ""

---Unique device identifier (short hex), e.g. `"81E37074"`.
---@type string
MM.deviceId = ""

---Human-readable device name, e.g. `"John's MacBook Pro"`.
---@type string
MM.deviceName = ""

---Full device UUID, e.g. `"81e37074-623e-42d0-b24f-6da495d57ec4"`.
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

---User's system language code, e.g. `"de"`.
---@type string
MM.language = ""

---WebKit locale string for web views, e.g. `"de-DE"`.
---@type string
MM.webkitLocale = ""

---`true` when running a debug/development build.
---@type boolean?
MM.DEBUG = nil

---`true` when running the Mac App Store build.
---@type boolean?
MM.APPSTORE = nil

---`true` when running a beta channel build.
---@type boolean?
MM.BETA = nil

-- ── Opaque Types ─────────────────────────────────────────────────────────────

---Opaque RSA key object returned by `MM.rsaGenerateKeys` or `MM.rsaPkcs8decode`.
---@class MM.RSAKey

---Elliptic curve key object returned by `MM.ecGenerateKeys`.
---@class MM.ECKey
---@field curve string Curve name, e.g. `"prime256v1"`
---@field x string Binary public key X coordinate
---@field y string Binary public key Y coordinate
---@field d string Binary private key scalar

---Opaque big number object for arbitrary-precision arithmetic.
---Created by `MM.hexToBigNum()`, consumed by `MM.bigNumToHex()` and arithmetic functions.
---@class MM.BigNum

--#endregion MM Table — Global Utility Functions and Properties

--#region Connection Object

---HTTPS connection object with cookie jar, persistent state, and HTTP/WebSocket support.
---
---For HTTP: `Connection()` creates a standard HTTPS connection.
---For WebSocket: `Connection(wsUrl)` or `Connection(wsUrl, protocols, useragent, language)`.
---@class MM.Connection
---@field useragent string User-Agent header value. Readable and writable.
---@field language string Accept-Language header value. Readable and writable.
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
---@param method MM.Conection.RequestMethod HTTP method
---@param url string Absolute or relative URL
---@param postContent? string Request body (for POST/PUT/PATCH)
---@param postContentType? string Content-Type header, e.g. `"application/json"`
---@param headers? table<string, string> Additional HTTP headers
---@return string content Response body (binary)
---@return string charset Response character encoding
---@return string mimeType Response MIME type
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
---Base signature with additional `headers` parameter.
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
---@return MM.HTMLElements element Single-element selection
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

---Execute a relative XPath query (must start with `.`).
---@param query string Relative XPath, e.g. `".//td"`, `"./input[@type='hidden']"`
---@return MM.HTMLElements elements
function HTMLElements:xpath(query) end

---Get the combined inner text content of all selected elements.
---@return string text
function HTMLElements:text() end

---Get an attribute value from the first selected element.
---@param attribute string Attribute name (lowercase)
---@return string? value Attribute value, or nil if not present
---@overload fun(self: MM.HTMLElements, attribute: string, value: string) Set attribute on all elements
function HTMLElements:attr(attribute) end

---Get the value of a form field. Respects `disabled` state and `<select>` option state.
---@return string? value
function HTMLElements:val() end

---Select an `<option>` within a `<select>` element by value.
---@param value string Option value to select
function HTMLElements:select(value) end

---Simulate clicking a link (`<a>`) or submit button.
---Returns an HTTP request tuple for `connection:request()`.
---@return "GET"|"POST" method HTTP method
---@return string url Target URL
---@return string? postContent POST body (for form submissions)
---@return string? postContentType Content-Type
function HTMLElements:click() end

---Submit a form (ignoring submit buttons — uses form action directly).
---Returns an HTTP request tuple for `connection:request()`.
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
---that login credentials were incorrect.
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
---@param charset? string Character encoding. Auto-detected if omitted.
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

---Global persistent key-value store. Values survive across script invocations
---for the same bank connection. Can store strings, numbers, booleans, tables,
---and even Connection objects.
---
---Clear all stored state with `LocalStorage = {}`.
---@type table<string, any>
LocalStorage = {}

--#endregion Persistent Storage

--#region Data Structures

---Account descriptor. Returned by `ListAccounts`, passed to `RefreshAccount` et al.
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
---@field comment? string Free-text comment
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
---@field transactionCode? integer ISO 20022 business transaction code
---@field textKeyExtension? integer Text key extension (FinTS-specific)
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
---@field transactionId? string Unique transaction identifier (for `isKnownTransactionId`)
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
---@field purchasePrice? number Purchase price per unit
---@field currencyOfPurchasePrice? string Purchase price currency
---@field exchangeRateOfPurchasePrice? number Exchange rate at purchase time
---@field price? number Current price per unit
---@field currencyOfPrice? string Current price currency
---@field exchangeRateOfPrice? number Current exchange rate
---@field amount? number Position value in account currency
---@field originalAmount? number Position value in original/foreign currency
---@field currencyOfOriginalAmount? string Original currency code
---@field market? string Exchange/market name
---@field tradeTimestamp? MM.Timestamp Price quote timestamp

---Response from `RefreshAccount`.
---
---When both `balance` and `balances` are present, `balances` takes priority for multi-currency
---display. The `balance` field is still read but `balances` provides the authoritative values.
---Same precedence applies to `pendingBalance` vs `pendingBalances`.
---@class MM.RefreshAccountResponse
---@field balance? number Account balance in default currency
---@field balances? {[1]: number, [2]: string}[] Multi-currency balances as `{amount, currencyCode}` tuples. Takes priority over `balance`.
---@field pendingBalance? number Pending balance in default currency
---@field pendingBalances? {[1]: number, [2]: string}[] Multi-currency pending balances as `{amount, currencyCode}` tuples. Takes priority over `pendingBalance`.
---@field transactions? MM.Transaction[] Transactions, newest first
---@field securities? MM.Security[] Portfolio positions
---@field payments? MM.ScheduledPayment[] Scheduled/standing payments (convenience shortcut; dedicated `FetchScheduledPayments` callback is the standard path)
---@field statements? MM.Statement[] PDF bank statements (convenience shortcut; dedicated `FetchStatements` callback is the standard path)
---@field bonusPoints? number Loyalty/bonus points balance
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
---@field standingOrderDay? integer Day of month (1–31) or day of week (1–7)
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

---Login credentials passed on step 1. Positional array of login fields,
---typically `{username, password}`. Password is always the last element.
---@class MM.LoginCredentials
---@field [1] string Username
---@field [2] string Password (or intermediate field if more than 2 fields)
---@field [3]? string Password (when 3 or more fields)
---@field [4]? string Password (when 4 fields)

---TAN/SCA response passed on step 2+, after the user entered a TAN or completed a challenge.
---@class MM.TanCredentials
---@field [1] string TAN value entered by user, or `""` if cancelled/empty
---@field [2] string Cancel message
---@field [3] boolean `true` if this is a decoupled polling re-call

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

---TAN challenge data. MoneyMoney auto-detects the content type
---(image, flicker code, URL, or plain text) and displays it accordingly.
---@alias MM.ChallengeData string

---2FA challenge returned by `InitializeSession2` and `RefreshAccount`.
---
---Fields are interpreted in priority order: `tanMethods` triggers a method selection
---dialog, `challenge`/`label` triggers a TAN entry dialog, and `appToApp`/`state`
---triggers an OAuth redirect.
---@class MM.SessionChallenge
---@field challenge? MM.ChallengeData Challenge data, auto-classified by content
---@field label? string Input field label. Alone (no challenge/poll) still triggers a TAN input dialog.
---@field tanMethods? MM.TanMethod[] TAN method selection — takes priority over all other fields when present
---@field tanMethod? MM.TanMethod Override current TAN method for this step. Properties (isNumeric, minLength, etc.) copied to challenge input.
---@field title? string Dialog window title. Auto-generated from TAN method + bank name if absent.
---@field poll? boolean Enable polling: MoneyMoney re-calls with same step and `credentials[3]=true`. With tanMethods: marks methods as polling-capable.
---@field startCode? string Reference number displayed alongside the challenge in the TAN entry dialog
---@field button? string `"next"` shows a "Next" button instead of "OK" (for multi-step QR flows)
---@field appToApp? string App name for app-redirect, or `https://` URL for OAuth.
---@field state? string OAuth state parameter, passed with appToApp URL for callback verification

---TAN method name. Controls which UI MoneyMoney shows for the TAN challenge.
---
---Using `poll=true` on the SessionChallenge triggers the decoupled polling UI
---(spinner, no TAN input) regardless of name.
---@alias MM.TanMethodName
---| "iTAN"               # Indexed TAN list entry
---| "mobileTAN"          # SMS code entry (also: `smsTAN`, `mTAN`)
---| "chipTAN manuell"    # Manual chipTAN (type start code on TAN generator)
---| "chipTAN Bluetooth"  # chipTAN via Bluetooth reader
---| "chipTAN optisch"    # Optical chipTAN (flicker code animation)
---| "chipTAN QR"         # QR-based chipTAN
---| "chipTAN photo"      # Photo-based chipTAN
---| "photoTAN"           # photoTAN image (user reads code from image)
---| "pushTAN"            # Decoupled app approval (also: `appTAN`, `BestSign`, `SecureGo plus`, `easyTAN`, `SealOne`)

---TAN method descriptor. Returned by `GetTanMethods` or within `MM.SessionChallenge.tanMethods`.
---
---The `hbciMethod` field is opaque — stored and passed back.
---@class MM.TanMethod
---@field name MM.TanMethodName Display name — **required**, entry skipped if nil. Controls UI type.
---@field hbciMethod? string Opaque identifier passed back in callbacks (conventionally FinTS codes like `"700"`, `"901"`)
---@field webMethod? string Extension-specific identifier
---@field mediumName? string Device/medium description, e.g. `"+49***123"` or "iPhone". Displayed next to the `name` in the selection dialog UI.
---@field errorMessage? string If set, method is disabled in UI — selecting it shows this error
---@field isPreferred? boolean Mark as preferred/default method
---@field isNumeric? boolean Numeric-only input (default: true)
---@field isUppercase? boolean Uppercase input
---@field tanLength? integer Expected TAN length (default: 6)
---@field minLength? integer Minimum input length
---@field maxLength? integer Maximum input length

---@class MM.FetchStatementsResponse
---@field statements MM.Statement[]

---A single PDF bank statement.
---@class MM.Statement
---@field account MM.Account The account this statement belongs to
---@field creationDate MM.Timestamp Statement date
---@field identifier string|table Unique identifier (used in `knownIdentifiers` to deduplicate)
---@field filename string Suggested filename for the PDF
---@field pdf string Binary PDF data

---@class MM.FetchScheduledPaymentsResponse
---@field payments MM.ScheduledPayment[]

---@alias MM.StandingOrderUnit
---| "M" # Month
---| "W" # Week

---A scheduled or standing payment.
---@class MM.ScheduledPayment
---@field type MM.PaymentTypeConst Payment type (`PaymentTypeScheduledTransfer` or `PaymentTypeStandingOrder`)
---@field orderId string|integer Unique payment identifier
---@field accountNumber string Recipient IBAN
---@field name string Recipient name
---@field purpose string Payment purpose/memo
---@field amount number Payment amount
---@field currency? string Currency code
---@field timezone? string Timezone for dates, e.g. `"GMT"`
---@field scheduledDate? MM.Timestamp Execution date or next execution
---@field endToEndReference? string SEPA end-to-end reference
---@field standingOrderStart? MM.Timestamp First execution date
---@field standingOrderEnd? MM.Timestamp Last execution date (nil = indefinite)
---@field standingOrderUnit? MM.StandingOrderUnit Recurrence unit: month or week
---@field standingOrderPeriod? integer Units between executions (1 = monthly, 3 = quarterly)

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
---function M.InitializeSession(protocol, bankCode, username, reserved, password) ... end
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
---@field SupportsBank fun(protocol: MM.ProtocolConst, bankCode: string, fetchStatements?: boolean, fetchScheduledPayments?: boolean, isPaymentSession?: boolean): boolean|string|MM.SupportsBankResponse Determine whether this extension handles a given bank connection.
---@field ListAccounts fun(knownAccounts: MM.Account[]): MM.Account[]|MM.ErrorMessage List all accounts available for scraping.
---@field RefreshAccount fun(account: MM.Account, since?: MM.Timestamp, isKnownTransactionId?: fun(id: string): {bookingDate: number, amount: number}?, step?: integer, credentials?: MM.TanCredentials|MM.TanMethod[]): MM.RefreshAccountResponse|MM.ErrorMessage|MM.SessionChallenge Fetch balance, transactions, and/or securities for one account.
---@field EndSession fun(): nil|MM.ErrorMessage Perform logout / cleanup.
--- Login — implement exactly one ───────────────────────────────────────────────
---@field InitializeSession? fun(protocol: MM.ProtocolConst, bankCode: string, username: string, reserved: string, password: string): nil|MM.ErrorMessage Simple single-step login. Legacy — prefer `InitializeSession2`.
---@field InitializeSession2? fun(protocol: MM.ProtocolConst, bankCode: string, step: integer, credentials: MM.Credentials, interactive: boolean, tanMethods?: MM.TanMethod[], session?: MM.SessionType): nil|MM.ErrorMessage|MM.SessionChallenge Login with two-factor authentication support.
--- Optional ────────────────────────────────────────────────────────────────────
---@field GetTanMethods? fun(account: MM.Account): MM.TanMethod[] Return available TAN/SCA methods. Called before `InitializeSession2`.
---@field MapAccount? fun(account: MM.Account): MM.Account Map/transform an account returned by `ListAccounts`.
---@field FetchStatements? fun(accounts: MM.Account[], knownIdentifiers: table<string, boolean>, step?: integer, credentials?: string[], interactive?: boolean): MM.FetchStatementsResponse|MM.ErrorMessage Fetch PDF bank statements.
---@field FetchScheduledPayments? fun(account: MM.Account): MM.FetchScheduledPaymentsResponse|MM.ErrorMessage Fetch scheduled/standing payments.
---@field SubmitPayment? fun(step: integer, account: MM.Account, payment: MM.Payment, tanMethod?: MM.TanMethod, credentials?: string[]): MM.SubmitPaymentResult Submit a payment; supports multi-step 2FA flows. Must return table or error string.

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
