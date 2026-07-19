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

/**
 * Finds the error definition for an error type in the merged default and custom error lists.
 * Precedence: exact match, then *:IDENTIFIER, then NAMESPACE:*.
 * Unlike getError, returns null when nothing matches instead of the UNKNOWN fallback,
 * so callers can distinguish "mapped" from "unmapped" error types.
 *
 * @p errorType The error type as a String, e.g. "HTTP:NOT_FOUND".
 * @p defaultErrors The default error definitions object.
 * @p customErrors Optional custom error definitions; merged over the defaults.
 * @r The matching error definition, or null when there is none.
 */
fun findErrorMapping(errorType, defaultErrors, customErrors = {}) = do {
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
    ---
         if ( !isEmpty(foundError        ) ) foundError
    else if ( !isEmpty(foundAnyIdentifier) ) foundAnyIdentifier
    else if ( !isEmpty(foundAnyNamespace ) ) foundAnyNamespace
    else                                     null
}

/*
 * Get the proper error from the merged default and custom error lists.  Provide a standard error if none found.
 */
fun getError(errorType, defaultErrors, customErrors = {}) = do {
    import mergeWith from dw::core::Objects
    ---
    findErrorMapping(errorType, defaultErrors, customErrors)
        default (defaultErrors mergeWith (customErrors default {}))["UNKNOWN"]
}

/**
 * Collects the nested errors of a Mule error: childErrors (composite scopes like
 * Scatter-Gather, Parallel For-Each, Validation "All") and suppressedErrors
 * (Until-Successful retries).  Every access is guarded because these fields may be
 * absent or unreadable on some error shapes.
 *
 * @p muleError The Mule error object.
 * @r Array of nested error objects; empty when there are none.
 */
fun getNestedErrors(muleError) =
    (evalOrElse(() -> muleError.childErrors, []) default []) ++ (evalOrElse(() -> muleError.suppressedErrors, []) default [])

/**
 * Recursively walks the nested-error tree down to the leaf standard errors —
 * nested errors that carry no nested errors of their own.  Intermediate composite
 * nodes are skipped; e.g. a Scatter-Gather inside a Parallel For-Each yields the
 * failing routes' errors, not the inner Scatter-Gather wrapper.
 *
 * @p muleError The Mule error object.
 * @r Array of leaf error objects; empty when the error has no nested errors.
 */
fun getLeafErrors(muleError) =
    getNestedErrors(muleError) flatMap ((child) -> do {
        var deeper = getLeafErrors(child)
        ---
        if (isEmpty(deeper)) [child] else deeper
    })

/**
 * Resolves the error definition of the standard error(s) nested inside a composite or
 * wrapper error (the resolveNestedErrors operation behavior).
 *
 * Unwrapping is attempted when the top-level error type is a known wrapper type
 * (Scatter-Gather/Parallel For-Each, Until-Successful, VM publish-consume, Validation "All"),
 * or — as a catch-all for uncataloged wrapper types — when the type has no mapping of its
 * own and nested errors are present.
 *
 * The nested-error tree is walked to its leaf standard errors (deduplicated by error type);
 * each leaf resolves against the merged default+custom list, and the definition with the
 * highest status code wins (ties keep the first occurrence).
 *
 * @p muleError The Mule error object.
 * @p defaultErrors The default error definitions object.
 * @p customErrors Optional custom error definitions; merged over the defaults.
 * @r The winning leaf error definition, or null when unwrapping does not apply or no leaf
 *    has a mapping (callers then fall back to the top-level error's own resolution).
 */
fun resolveNestedErrorMapping(muleError, defaultErrors, customErrors = {}) = do {
    var wrapperTypes = ["MULE:COMPOSITE_ROUTING", "MULE:RETRY_EXHAUSTED", "VM:PUBLISH_CONSUMER_FLOW_ERROR", "VALIDATION:MULTIPLE"]

    var errorType     = getErrorTypeAsString(evalOrElse(() -> muleError.errorType, null))
    var hasOwnMapping = findErrorMapping(errorType, defaultErrors, customErrors) != null
    // Leaves without a readable errorType stringify to UNKNOWN and must not resolve (the UNKNOWN
    // entry would outvote mapped siblings); they fall out here instead.
    var leafTypes     = ((getLeafErrors(muleError) map ((leaf) -> getErrorTypeAsString(evalOrElse(() -> leaf.errorType, null)))) distinctBy $) filter ($ != "UNKNOWN")

    var shouldAttempt = (wrapperTypes contains errorType) or (!hasOwnMapping and !isEmpty(leafTypes))

    var resolvable =
        if (shouldAttempt)
            (leafTypes map ((leafType) -> findErrorMapping(leafType, defaultErrors, customErrors))) filter ($ != null)
        else
            []
    ---
    if (isEmpty(resolvable))
        null
    else
        // Highest status code wins; orderBy is stable, so ties keep the first occurrence.
        (resolvable orderBy (-(($.code default 0) as Number)))[0]
}

/**
 * Resolves an error definition from the downstream response's status code
 * (the propagateStatusCode operation behavior).
 *
 * Applies only when the error type has no mapping of its own — an explicit mapping,
 * including a custom MULE:UNKNOWN entry, always wins — and the downstream status code
 * at errorMessage.attributes.statusCode is readable as a number.  The resulting
 * definition uses the downstream statusCode and reasonPhrase (the UNKNOWN entry's
 * reason when absent) and keeps the UNKNOWN entry's message.
 *
 * @p muleError The Mule error object.
 * @p defaultErrors The default error definitions object.
 * @p customErrors Optional custom error definitions; merged over the defaults.
 * @r An error definition with the downstream status, or null when passthrough does not apply.
 */
fun resolveStatusCodePassthrough(muleError, defaultErrors, customErrors = {}) = do {
    var errorType    = getErrorTypeAsString(evalOrElse(() -> muleError.errorType, null))
    var unmapped     = findErrorMapping(errorType, defaultErrors, customErrors) == null
    var statusCode   = evalOrElse(() -> muleError.errorMessage.attributes.statusCode as Number, null)
    var reason       = evalOrElse(() -> muleError.errorMessage.attributes.reasonPhrase, null)
    var unknownEntry = getError(errorType, defaultErrors, customErrors)
    ---
    if (unmapped and (statusCode != null))
        // Built explicitly (not via update) so a partial UNKNOWN entry cannot silently drop the status.
        {
            code   : statusCode,
            reason : reason default (unknownEntry.reason default "Internal Server Error"),
            message: unknownEntry.message
        }
    else
        null
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
