/**
 * This provides custom error handling for the API Error Handler.
 *
 * IMPROVEMENTS (2026-07-09):
 * - Uses getPreviousErrorMessage() for safe extraction of nested errors from:
 *   childErrors (Scatter-Gather, Parallel-Foreach, Validation:ALL),
 *   suppressedErrors (Until-Successful, Validation:ANY),
 *   and standard error payloads.
 * - Uses getStatusCode() and getReasonPhrase() for safe HTTP attribute access.
 * - All functions handle nulls, missing fields, text/plain, and binary payloads.
 */

%dw 2.0
output application/json
import * from module_error_handler_plugin::common

/**
 * Previous error extracted safely from the Mule error object.
 * Handles all Mule Error formats:
 * - Composite modules/scopes: childErrors (Scatter-Gather, Parallel-Foreach, Validation:ALL)
 * - Retry scopes: suppressedErrors (Until-Successful, Validation:ANY)
 * - Standard errors: exception.errorMessage (HTTP connectors, Raise Error, etc.)
 *
 * EDGE CASES HANDLED:
 * - text/plain payloads: safely read as string
 * - Binary payloads: safely converted without breaking
 * - Null/missing errorMessage: returns empty string
 * - Mixed error types: merges all sources with " | " separator
 */
var previousError = getPreviousErrorMessage(error)

---
{
    /*
    APP 401 Unauthorized
    This catches custom service unauthorized error from app and formats the response accordingly.
    */
    "APP:UNAUTHORIZED": {
        code: 401,
        reason: "Unauthorized",
        message: error.description
    },

    /*
    APP 503 Service Unavailable
    This catches custom service unavailable error from app and formats the response accordingly.
    */
    "APP:SERVICE_UNAVAILABLE": {
        code: 503,
        reason: "Service Unavailable",
        message: error.description
    },

    /*
    HTTP 500 Pass Through
    This catches HTTP 500 errors and propagates the detailed reason for failure.
    Uses getPreviousErrorMessage() to safely extract downstream error messages.
    Falls back to error.description if no previous error is available.

    EDGE CASE: When the downstream API returns text/plain or binary, the safe
    extractor handles it without throwing. Previously, accessing
    error.errorMessage.payload directly would break on non-JSON payloads.
    */
    "HTTP:INTERNAL_SERVER_ERROR": {
        code: 500,
        reason: "Internal Server Error",
        message: if (!isEmpty(previousError)) previousError else error.description
    },

    /*
    Unknown Errors (MULE:UNKNOWN)
    This catches unknown errors, including non-standard HTTP status codes.
    Uses safe getters for status code and reason phrase to handle cases where
    the HTTP response attributes may be missing or incomplete.

    EDGE CASE: When the called API returns a non-JSON response (e.g., text/plain
    error page from a load balancer), getStatusCode() and getReasonPhrase()
    safely extract what they can, defaulting to 500/"Internal Server Error".
    */
    "MULE:UNKNOWN": {
        code: getStatusCode(error),
        reason: getReasonPhrase(error),
        message: if (!isEmpty(previousError)) previousError else error.description
    }
}
