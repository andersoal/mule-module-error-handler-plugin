# Error Handler Plugin - Improvements

## Summary of Changes (2026-07-09)

This document describes the improvements made to the Error Handler Plugin to enhance robustness when handling various error payload types, particularly edge cases like `text/plain`, binary content, null payloads, deeply nested composite errors, and **fatal crashes when the error object itself is inaccessible**.

---

## 1. Safe Payload Extraction Functions (`common.dwl`)

### Problem
The original `previousError` pattern in `customErrors.dwl` directly accessed `error.childErrors..errorMessage.payload` and `error.exception.errorMessage.typedValue`. This approach breaks when:
- The payload is `text/plain` (not JSON)
- The payload is `Binary` (e.g., PDF, image)
- `errorMessage` or `payload` fields are null or missing
- childErrors have inconsistent structure (some with payload, some without)

### Solution
Added six new safe extraction functions to `module_error_handler_plugin::common`:

#### `getSafePayload(errorMsg)`
Safely extracts payload from an error message structure. Handles:
- `null`/`empty` errorMessage → returns `""`
- `Binary` payloads → reads as text/plain with fallback to Java serialization
- `String` payloads → returns as-is
- Structured data (Object/Array) → returns payload or typedValue safely

#### `extractCompositeErrors(err)`
Recursively extracts error payloads from `childErrors` (Scatter-Gather, Parallel-Foreach, Validation:ALL). Features:
- Null-safe traversal of child error trees
- Recursive handling for deeply nested composite structures
- Deduplication of error messages
- Graceful handling of children without `errorMessage`

#### `extractSuppressedErrors(err)`
Recursively extracts error payloads from `suppressedErrors` (Until-Successful, Validation:ANY). Features:
- Same safety guarantees as `extractCompositeErrors`
- Handles nested suppressed errors
- Deduplication of repeated messages

#### `extractStandardError(err)`
Safely extracts payload from standard (non-composite) errors via `error.exception.errorMessage`. Wraps access in try/catch to prevent failures when `exception` or `errorMessage` is missing.

#### `getPreviousErrorMessage(err)`
**Unified extractor** that combines all three sources:
1. `childErrors` (composite errors)
2. `suppressedErrors` (retry/validation errors)
3. Standard error payload

Returns a single string with all unique messages joined by `" | "`. This is the **recommended** function for custom error definitions.

#### `getStatusCode(err, def)` and `getReasonPhrase(err, def)`
Safe extractors for HTTP attributes that default to `500` and `"Internal Server Error"` when attributes are missing.

### Usage (Recommended Pattern)

Replace the manual `previousError` construction with:

```dataweave
%dw 2.0
import * from module_error_handler_plugin::common

var previousError = getPreviousErrorMessage(error)
---
{
    "HTTP:INTERNAL_SERVER_ERROR": {
        code: 500,
        reason: "Internal Server Error",
        message: if (!isEmpty(previousError)) previousError else error.description
    },
    "MULE:UNKNOWN": {
        code: getStatusCode(error),
        reason: getReasonPhrase(error),
        message: if (!isEmpty(previousError)) previousError else error.description
    }
}
```

---

## 2. Fatal Error Handling in Module XML (CRITICAL)

### Problem
When the `error` object itself is **corrupted, null, or fatally inaccessible**, even reading `error.description` or `error.errorType` throws a **fatal exception** that crashes the entire error handling flow. This happens when:
- `#[error]` is evaluated outside an error handler context
- The error object is a Java exception that DataWeave cannot serialize
- `error.errorType` is an internal Java class that DataWeave cannot introspect
- The error object has been garbage-collected or is in an invalid state

**Before this fix:** The module would throw a fatal, the API would return no response, and the caller would get a connection timeout.

### Solution
The entire operation body is now wrapped in a **`<try>` scope with `<on-error-continue>`**:

```xml
<mule:try doc:name="Safe Error Processing Wrapper">
    <!-- Normal processing steps -->
    <mule:error-handler>
        <mule:on-error-continue doc:name="On Fatal - Safe Fallback">
            <!-- Returns guaranteed 500 response -->
        </mule:on-error-continue>
    </mule:error-handler>
</mule:try>
```

### Three-Layer Defense

#### Layer 1: Safe Error Object Normalization
Before any DataWeave script touches the error, a `safeError` variable is created with guaranteed non-null fields:

```xml
<mule:set-variable variableName="safeError">
    <mule:value><![CDATA[#[
        if ( vars.error != null
             and (vars.error.errorType != null or vars.error.description != null)
           )
            vars.error
        else
            {
                errorType: { namespace: "MULE", identifier: "UNKNOWN" },
                description: (vars.error default {}).description
                    default "An unexpected error occurred",
                childErrors: (vars.error default {}).childErrors default [],
                suppressedErrors: (vars.error default {}).suppressedErrors default []
            }
    ]]></mule:value>
</mule:set-variable>
```

**Key point:** Downstream DataWeave scripts use `vars.safeError` (guaranteed non-null) instead of `vars.error` (potentially fatal).

#### Layer 2: Try/Catch in DataWeave
Every DataWeave expression that accesses error fields is wrapped in `try {} catch() {}`:

```dataweave
// Error type resolution
try
    getErrorTypeAsString(vars.safeError.errorType)
catch(e)
    "MULE:UNKNOWN"

// Description access
try
    "Error Description: " ++ (vars.safeError.description default "")
catch(e)
    "Error Description: [inaccessible]"

// Log writing
try
    write(payload, "application/json") default ""
catch(e)
    "[unwritable]"
```

#### Layer 3: Catastrophic Fallback
If **any** step in the body still throws (e.g., a corrupted Java exception that crashes DataWeave), the `<on-error-continue>` produces a guaranteed valid response:

```json
{
  "error": {
    "code": 500,
    "reason": "Internal Server Error",
    "message": "An unexpected error occurred while processing the error response"
  }
}
```

With attributes:
```json
{
  "httpStatus": 500,
  "errorLog": "Error Handler Plugin fatal fallback"
}
```

### Result
| Scenario | Before | After |
|----------|--------|-------|
| `error` is null | Fatal crash | 500 with safe fallback |
| `error.errorType` is unreadable Java class | Fatal crash | MULE:UNKNOWN + 500 |
| `error.description` throws on access | Fatal crash | "[inaccessible]" + 500 |
| DataWeave cannot serialize payload | Fatal crash | 500 with fallback JSON |
| Module called outside error handler | Fatal crash | 500 with safe fallback |

---

## 3. Updated `customErrors.dwl` Example

The example file has been refactored to:
- Use `getPreviousErrorMessage()` instead of manual error extraction
- Use `getStatusCode()` and `getReasonPhrase()` for safe HTTP attribute access
- Include comprehensive documentation for each error handler
- Document edge cases (text/plain, binary payloads)

---

## 4. MUnit Test Suite

Created `src/test/munit/error-handler-plugin-test-suite.xml` with **18 test cases** across 6 categories:

### Category 1: Standard HTTP Errors (4 tests)
- `test-http-not-found-standard-error` — HTTP:NOT_FOUND → 404
- `test-http-timeout-standard-error` — HTTP:TIMEOUT → 408
- `test-http-connectivity-standard-error` — HTTP:CONNECTIVITY → 503
- `test-expression-error-security` — MULE:EXPRESSION message does NOT expose generated error (security)

### Category 2: Composite Errors with childErrors (3 tests)
- `test-scatter-gather-child-errors` — Uses `ScatterGather.json` fixture
- `test-parallel-foreach-child-errors` — Uses `ParallelForeachError.json` fixture
- `test-validation-all-child-errors` — Uses `MultiValidationModuleError.json` fixture

### Category 3: Suppressed Errors (1 test)
- `test-until-successful-suppressed-errors` — Uses `UntilSuccessfulError.json` fixture

### Category 4: Custom Errors with Previous Error (1 test)
- `test-custom-errors-with-previous-error` — Tests `customErrors.dwl` integration

### Category 5: Edge Cases — Payload Type Safety (5 tests)
- `edge-case-text-plain-payload` — text/plain payload doesn't break handler
- `edge-case-null-payload` — null payload with empty child/suppressed arrays
- `edge-case-missing-error-message` — childErrors without errorMessage field
- `edge-case-empty-child-and-suppressed-errors` — empty arrays handled gracefully
- `edge-case-nested-composite-and-suppressed` — deeply nested child + suppressed merge

### Category 6: Response Key Customization (2 tests)
- `test-custom-response-key` — custom key name (e.g., `errorDetails`)
- `test-empty-response-key-root-payload` — root-level payload (no wrapper)

---

## 5. New Test Fixtures (5 JSON files)

| Fixture | Description |
|---------|-------------|
| `TextPlainPayloadError.json` | text/plain payload from load balancer/proxy |
| `BinaryPayloadError.json` | Binary/octet-stream payload (PDF, image) |
| `NullPayloadWithChildErrors.json` | Null parent payload but valid childErrors |
| `MixedPayloadTypesError.json` | childErrors with JSON, text, null, AND missing payloads |
| `DeeplyNestedCompositeError.json` | 4-level deep nesting (Parallel-Foreach > Scatter-Gather > Validation:ALL) |

---

## 6. Code Cleanup

### `toString()` Function Improvements
- Added try/catch for `Binary` type conversion
- Added explicit `Null` type handling
- Added nested try/catch for complex object serialization failures
- Returns `"[Binary content]"` as fallback for unreadable binary data

### Module XML Defensive Architecture
- Entire operation body wrapped in `<try>` with `<on-error-continue>`
- `safeError` variable guarantees non-null error object for DataWeave
- All `vars.error` references replaced with `vars.safeError`
- All DataWeave error access wrapped in `try {} catch() {}`
- Catastrophic fallback produces guaranteed valid 500 JSON response

### Documentation
- All new functions have comprehensive doc comments with `@p` param and `@r` return tags
- Each test has `doc:description` explaining its purpose
- Each JSON fixture has `_description` field explaining the scenario

---

## Backward Compatibility

All changes are **backward compatible**:
- Existing `getErrorTypeAsString()` and `getError()` functions are unchanged
- Existing `toString()` function is enhanced but maintains same signature
- New functions are additive only
- The module XML behavior is unchanged for normal cases — only adds safety for edge cases
- Existing custom error definitions continue to work

---

## Migration Guide

To upgrade existing custom error definitions to use the new safe functions:

### Before (old pattern)
```dataweave
var previousError = do {
    var nested = [
        error.childErrors..errorMessage.payload,
        error.suppressedErrors..errorMessage.payload,
        error.exception.errorMessage.typedValue
    ] dw::core::Arrays::firstWith !isEmpty($)
    ---
    if (nested is Array) toString(nested) else toString(nested)
}
```

### After (new pattern)
```dataweave
var previousError = getPreviousErrorMessage(error)
```

For `MULE:UNKNOWN` with HTTP attribute access:

### Before
```dataweave
code: error.exception.errorMessage.attributes.statusCode default 500,
reason: error.exception.errorMessage.attributes.reasonPhrase default "Internal Server Error"
```

### After
```dataweave
code: getStatusCode(error),
reason: getReasonPhrase(error)
```

---

## Files Changed

| File | Change |
|------|--------|
| `src/main/resources/module-error-handler-plugin.xml` | Wrapped body in try/catch, added safeError normalization, added catastrophic fallback |
| `src/main/resources/module_error_handler_plugin/common.dwl` | Enhanced with 6 new safe functions + improved toString() |
| `examples/customErrors.dwl` | Refactored to use new safe patterns |
| `src/test/munit/error-handler-plugin-test-suite.xml` | New — 18 MUnit tests |
| `src/test/resources/examples/TextPlainPayloadError.json` | New test fixture |
| `src/test/resources/examples/BinaryPayloadError.json` | New test fixture |
| `src/test/resources/examples/NullPayloadWithChildErrors.json` | New test fixture |
| `src/test/resources/examples/MixedPayloadTypesError.json` | New test fixture |
| `src/test/resources/examples/DeeplyNestedCompositeError.json` | New test fixture |
| `IMPROVEMENTS.md` | New — this documentation file |
| `README.md` | Expanded with improvements overview and quick start |
