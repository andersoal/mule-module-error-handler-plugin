/**
 * This provides custom error handling for the API Error Handler.
 */

%dw 2.0
output application/json
import * from module_error_handler_plugin::common

/**
 * Previous error nested in the Mule error object.
 * Provides the entire payload of the previous error as a String.
 * getPreviousErrorMessage handles the main Mule Error formats to get nested errors:
 * - Composite modules/scopes, like Scatter-Gather, Parallel-Foreach, Group Validation Module (childErrors)
 * - Until-Successful (suppressedErrors)
 * - Standard Error, like Raise Error, Foreach, and most connectors and errors.
 * It is also safe for error payloads that are Binary or plain text (e.g. text/plain responses),
 * which cannot be accessed with selectors like error.errorMessage.payload.message and would
 * otherwise fail the error handler.
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
    It uses the error.message field from the response of the HTTP call that failed for the message, which conforms to the API Error Handler responses.
    If not found, the error.description will be returned, which generally says an internal server error occurred.
    This useful for process or experience APIs to pass through system API errors.
    */
    "HTTP:INTERNAL_SERVER_ERROR": {
        code: 500,
        reason: "Internal Server Error",
        message: if (!isEmpty(previousError)) previousError else error.description
    },

    /*
    Unknown Errors
    This catches unknown errors, which includes any non-standard HTTP error status code and propagates the detailed reason for failure.
    It tries to use the called API's error response code and phrase if available in the error.  If not, it uses the default 500 response.
    It uses the error.message field from the response of the HTTP call that failed for the message, which conforms to the API Error Handler responses.
    If not found, the error.description will be returned, which generally says an internal server error occurred.
    */
    "MULE:UNKNOWN": {
        // evalOrElse guards the selectors when the error message attributes are not accessible, e.g. Binary content.
        code: evalOrElse(() -> error.exception.errorMessage.attributes.statusCode, 500) default 500,
        reason: evalOrElse(() -> error.exception.errorMessage.attributes.reasonPhrase, "Internal Server Error") default "Internal Server Error",
        message: if (!isEmpty(previousError)) previousError else error.description
    }
}