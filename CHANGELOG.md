# Changelog

All notable changes to the Error Handler Plugin are documented in this file.

## 6.4.0 - 2026-07-09

### Fixed

- **Error handler no longer breaks on Binary or plain-text error payloads.**  When a downstream system returned a `text/plain` or binary error body, accessing `error.errorMessage.payload` (directly or through the previous-error extraction pattern) raised a DataWeave error — `isEmpty()` and value selectors are not defined for `Binary`/`String` content — which failed the error handler itself and masked the original error.  All payload access in the module is now guarded:
  - `toString` no longer fails when checking emptiness of a `Binary` value, and falls back to Base64 when the bytes cannot be read as text.
  - The `previousError` parameter is converted to a String when it is `Binary`, so the JSON response can always be written.
- **`VALIDATION:*` default error returned a `null` message.**  The default error definition referenced a bare `error` object, which is not available inside the module's operation (the error is passed as `vars.error`).  Validation errors now return the validation description as the message.
- **DEBUG logger failures.**  The entry logger used a misspelled output directive (`aplication/java`), and the exit logger concatenated a Number (`attributes.httpStatus`) into a String with `++`, both of which failed when DEBUG logging was enabled for `org.mulesoft.modules.errorhandler`.  Both expressions are fixed (the exit logger now uses string interpolation).

### Added

- **`getPreviousErrorMessage(muleError)` common function** (previously referenced by the documentation but not implemented).  Extracts the previous (nested) error message as a String from:
  - `childErrors` — composite scopes/modules: Scatter-Gather, Parallel For-Each, and the Validation module's _All_ aggregation
  - `suppressedErrors` — Until-Successful retries
  - Standard errors — `error.exception.errorMessage.typedValue`, with a fallback to `error.errorMessage.payload`

  Duplicate nested messages are removed, a single message is returned as-is (not wrapped in an array representation), and Binary/plain-text payloads are converted to Strings instead of failing.
- **`isEmptyValue(value)` common function.**  Behaves like `isEmpty()` but never fails on types `isEmpty()` does not support (e.g. `Binary`).  A Binary value is considered empty when its text content is empty.
- **`evalOrElse(fn, fallback)` common function.**  Safely evaluates a zero-argument function and returns the fallback when the evaluation fails.  Useful to guard selectors on content that may be Binary or plain text, e.g. `evalOrElse(() -> error.errorMessage.payload.message, "")`.
- **MUnit test suites** (`src/test/munit`):
  - `process-error-test-suite.xml` — exercises the `process-error` operation with serialized real-world Mule errors (`src/test/resources/examples`): composite errors with `childErrors` (Scatter-Gather, Parallel For-Each, multi-Validation), Until-Successful errors with `suppressedErrors`, plain-text (HTML) payloads, Binary payloads, custom error overrides, wildcard matching, response-key renaming, and the `useGeneratedError` flag.
  - `common-functions-test-suite.xml` — unit tests for `getErrorTypeAsString`, `getError` lookup precedence (exact → `*:IDENTIFIER` → `NAMESPACE:*` → `UNKNOWN`), `toString`, `isEmptyValue`, and `getPreviousErrorMessage` edge cases.
- **New test fixture** `src/test/resources/examples/UntilSuccessfulSuppressedErrors.json` with a populated `suppressedErrors` array (the existing Until-Successful fixture has an empty one).

### Changed

- `examples/customErrors.dwl` template (and the copies embedded in the Exchange docs) now uses `getPreviousErrorMessage(error)` instead of the inline extraction block, and guards the `MULE:UNKNOWN` status/reason selectors with `evalOrElse`.
- Documentation (`exchange-docs/home.md`, `exchange-docs/How to.md`) updated: common functions reference, previous-error feature notes about Binary/plain-text payloads, and the versions table.

### Notes

- No breaking changes.  Existing custom error definitions keep working; the new functions are additive and the hardened `toString` only changes behavior in cases that previously failed.
