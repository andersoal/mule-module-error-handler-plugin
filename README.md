# MuleSoft Error Handler Plugin

A Mule XML SDK module that provides standardized REST API error response handling for MuleSoft applications. Converts any Mule error into proper JSON response bodies with correct HTTP status codes.

**Full Documentation**: [Exchange Docs](./exchange-docs/home.md)
**Improvements Log**: [IMPROVEMENTS.md](./IMPROVEMENTS.md)

---

## Features

- Converts all Mule errors (APIKit, HTTP, Validation, Custom) into proper API JSON responses
- Supports `childErrors` from composite scopes (Scatter-Gather, Parallel-Foreach, Validation:ALL)
- Supports `suppressedErrors` from retry scopes (Until-Successful, Validation:ANY)
- Customizable error messages via DataWeave
- Previous error propagation from downstream APIs
- Response key customization
- Compatible with `on-error-propagate` and `on-error-continue`

---

## Recent Improvements

### Safe Payload Extraction (2026-07-09)

The plugin now handles edge cases that previously caused failures:

| Edge Case | Before | After |
|-----------|--------|-------|
| `text/plain` payload | Broke on `error.errorMessage.payload` | Safely reads as string |
| `Binary` payload | Threw exception | Graceful fallback to `[Binary content]` |
| Null `errorMessage` | Null pointer | Returns empty string |
| Missing `payload` field | Selector error | Returns empty string |
| Deeply nested `childErrors` | Only 1 level | Recursive traversal |

### New Safe Functions (`module_error_handler_plugin::common`)

```dataweave
import * from module_error_handler_plugin::common

// Unified safe extractor — handles childErrors + suppressedErrors + standard errors
var previousError = getPreviousErrorMessage(error)

// Safe HTTP attribute access with defaults
var statusCode   = getStatusCode(error)      // defaults to 500
var reasonPhrase = getReasonPhrase(error)    // defaults to "Internal Server Error"
```

See [IMPROVEMENTS.md](./IMPROVEMENTS.md) for full migration guide.

---

## MUnit Tests

The project includes a comprehensive MUnit test suite with **18 test cases**:

| Category | Tests | Description |
|----------|-------|-------------|
| Standard HTTP Errors | 4 | NOT_FOUND, TIMEOUT, CONNECTIVITY, EXPRESSION |
| Composite childErrors | 3 | Scatter-Gather, Parallel-Foreach, Validation:ALL |
| Suppressed Errors | 1 | Until-Successful retry errors |
| Custom Errors | 1 | Previous error extraction with custom definitions |
| Edge Cases | 5 | text/plain, binary, null, missing fields, nested |
| Response Key | 2 | Custom key name, root-level payload |

### Running Tests

```bash
# Run all MUnit tests
mvn clean test

# Run with detailed logs
mvn clean test -Dorg.slf4j.simpleLogger.defaultLogLevel=debug
```

---

## Quick Start

```xml
<error-handler name="api-error-handler">
    <on-error-continue enableNotifications="true" logException="true">
        <module-error-handler-plugin:process-error doc:name="Process Error" />
        <set-variable variableName="httpStatus" value="#[attributes.httpStatus]" />
        <logger level="ERROR" message='#[{ code: attributes.httpStatus, message: attributes.errorLog }]' />
    </on-error-continue>
</error-handler>
```

### With Custom Errors (Recommended Pattern)

```xml
<module-error-handler-plugin:process-error doc:name="Process Error">
    <module-error-handler-plugin:custom-errors>
        <![CDATA[#[${file::errors/customErrors.dwl}]]]>
    </module-error-handler-plugin:custom-errors>
</module-error-handler-plugin:process-error>
```

The `customErrors.dwl` template using the new safe functions:

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

## Building & Deploying

See [Exchange Docs - Building & Deploying](./exchange-docs/home.md#building) for detailed instructions.

Quick build:
```bash
./build.sh install ORG_ID_TOKEN
```

---

## Compatibility

| Version | Minimum Runtime | Java |
|---------|----------------|------|
| 6.3.0 | 4.6.0 | 17 |
| 6.0.0 - 6.2.0 | 4.4.0 | 9/11 |

---

## Project Structure

```
.
├── src/main/resources/
│   ├── module-error-handler-plugin.xml          # Main module definition
│   ├── module_error_handler_plugin/
│   │   ├── common.dwl                            # Helper functions (safe extractors)
│   │   └── defaultErrors.dwl                     # Default error mappings
│   ├── custom-errors-schema.json
│   ├── output-response-schema.json
│   └── output-attribute-schema.json
├── src/test/
│   ├── munit/error-handler-plugin-test-suite.xml # MUnit tests (18 cases)
│   └── resources/examples/                       # Test fixtures (10 JSON files)
├── examples/
│   └── customErrors.dwl                          # Template with safe patterns
├── exchange-docs/home.md                         # Full documentation
├── IMPROVEMENTS.md                               # Change log
└── pom.xml
```
