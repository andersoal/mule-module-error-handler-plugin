%dw 2.0

/*
 NOTICE:
    This file must be in the ./resources/<module name> folder in order to be exported in the META-INF/mule-artifact/mule-artifact.json file.  This allows the functions to be used in the module as they are executed in the app's context (without the mule message context).
 */

import try from dw::Runtime
import firstWith from dw::core::Arrays
import toBase64 from dw::core::Binaries

/**
 * Safely evaluates a zero-argument function.
 * Returns the fallback instead of failing when the evaluation raises an error,
 * e.g. selectors applied to unsupported types like Binary or String content.
 *
 * @p fn Zero-argument function to evaluate, e.g. () -> error.errorMessage.payload.message
 * @p fallback Value to return when fn fails.  Note: it is evaluated eagerly, so keep it cheap.
 * @r Result of fn, or the fallback when fn fails.
 */
fun evalOrElse(fn, fallback) = do {
    var attempt = try(fn)
    ---
    if (attempt.success) attempt.result else fallback
}

/**
 * Null-safe and Binary-safe emptiness check.
 * isEmpty() raises an error for unsupported types, e.g. Binary; this function never fails.
 * A Binary value is considered empty when its text content is empty.
 *
 * @p value to check.
 * @r Boolean.  true when the value is null or empty; false otherwise or when emptiness cannot be determined.
 */
fun isEmptyValue(value) = value match {
    case b is Binary -> evalOrElse(() -> isEmpty(read(b, "text/plain") as String), false)
    else             -> evalOrElse(() -> isEmpty(value), false)
}

/*
 *  Get the error type as a String
 */
fun getErrorTypeAsString(errorType) =
    if (!isBlank(errorType.namespace))
        errorType.namespace ++ ":" ++ (errorType.identifier default "")
    else
        "UNKNOWN"

/*
 * Get the proper error from the merged default and custom error lists.  Provide a standard error if none found.
 */
fun getError(errorType, defaultErrors, customErrors = {}) = do {
    import mergeWith from dw::core::Objects

    var errorTypeAnyNamespace  = ( do { var n = ((errorType splitBy  ":")[0] default "") --- if (!isBlank(n)) n ++ ":*" else errorType } )
    var errorTypeAnyIdentifier = ( do { var i = ((errorType splitBy  ":")[1] default "") --- if (!isBlank(i)) "*:" ++ i else errorType } )

    var errorList = (defaultErrors mergeWith (customErrors default {}))

    // e.g. HTTP:CONNECTIVITY
    var foundError         = errorList[errorType]
    // e.g. HTTP:*
    var foundAnyNamespace  = if( isEmpty(foundError)                                ) errorList[errorTypeAnyNamespace]  else {}
    // e.g. *:CONNECTIVITY
    var foundAnyIdentifier = if( isEmpty(foundError) and isEmpty(foundAnyNamespace) ) errorList[errorTypeAnyIdentifier] else {}

    var error = (
         if ( !isEmpty(foundError        ) ) foundError
    else if ( !isEmpty(foundAnyIdentifier) ) foundAnyIdentifier
    else if ( !isEmpty(foundAnyNamespace ) ) foundAnyNamespace
    else                                     errorList["UNKNOWN"]
    )
    ---
    error
}

/**
 * Converts a value to a String representation.
 * Binary is read as text; if the bytes are not readable as text, it falls back to Base64.
 * Primitives are directly converted to Strings.
 * Complex objects, like Objects and Arrays, are converted to the String presentation of their Java form.
 *
 * @p value to convert.
 * @p def is the default value if the provided value is empty.
 * @r String.  If empty, then returns the default value provided
 */
fun toString(value, def="") = do {
    var safeValue = if (!isEmptyValue(value)) value else def default ""  // No nulls allowed
    ---
    safeValue match {
        case s is String -> s
        case n is Number -> n as String
        case b is Binary -> evalOrElse(() -> read(b, "text/plain") as String, toBase64(b))
        else             -> write(safeValue, "application/java")
    }
}

/**
 * Gets the previous (nested) error message from a Mule error object as a String.
 * Handles the main Mule Error formats for nested errors:
 * - childErrors: composite scopes/modules, like Scatter-Gather, Parallel For-Each, and the Validation module's "All" aggregation
 * - suppressedErrors: Until-Successful retries
 * - Standard errors, like Raise Error, Foreach, and most connectors; checked last because composite errors also populate these fields
 * Every access is guarded, so payloads that cannot be inspected with selectors,
 * e.g. Binary or text/plain content, are converted to Strings instead of failing the error handler.
 *
 * @p muleError The Mule error object, usually `error` (or `vars.error` inside the module).
 * @r String with the previous error message(s); empty String when there is none.
 */
fun getPreviousErrorMessage(muleError) = do {
    var nested = [
        evalOrElse(() -> muleError.childErrors..errorMessage.payload, null),        // Composite
        evalOrElse(() -> muleError.suppressedErrors..errorMessage.payload, null),   // Until-Successful
        evalOrElse(() -> muleError.exception.errorMessage.typedValue, null),        // Standard Error: must go last because it has content if this is one of the other types of errors
        evalOrElse(() -> muleError.errorMessage.payload, null)                      // Standard Error fallback, e.g. serialized error objects
    ] firstWith !isEmptyValue($)

    var messages =
        if (nested is Array)
            ((nested map toString($)) filter !isEmpty($)) distinctBy $
        else
            [toString(nested)] filter !isEmpty($)
    ---
    if (isEmpty(messages))
        ""
    else if (sizeOf(messages) == 1)
        messages[0]
    else
        toString(messages)
}
