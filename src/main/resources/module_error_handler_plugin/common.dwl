%dw 2.0

/*
 NOTICE:
    This file must be in the ./resources/<module name> folder in order to be exported in the META-INF/mule-artifact/mule-artifact.json file.  This allows the functions to be used in the module as they are executed in the app's context (without the mule message context).
 */

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
 * Safely extracts a payload from an error message structure.
 * Handles nulls, missing fields, Binary payloads, and text/plain content.
 *
 * @p errorMsg The errorMessage object from a Mule error.
 * @r The payload as a usable value, or empty string if unavailable.
 */
fun getSafePayload(errorMsg) = do {
    var typedVal = errorMsg.typedValue default ""
    ---
    if (isEmpty(typedVal))
        ""
    else if (typeOf(typedVal) == "Binary")
        try read(typedVal, "text/plain") default write(typedVal, "application/java")
        catch(e) write(typedVal, "application/java")
    else if (typeOf(typedVal) == "String")
        typedVal
    else
        // For objects, arrays, and other structured data
        try (errorMsg.payload default typedVal)
        catch(e) typedVal
}

/**
 * Extracts error payloads from composite error structures (childErrors).
 * Used by Scatter-Gather, Parallel-Foreach, and Validation:ALL errors.
 * Safely navigates potentially null or incomplete error structures.
 *
 * @p err The parent Mule error object.
 * @r Array of stringified error payloads from all child errors.
 */
fun extractCompositeErrors(err) = do {
    var children = err.childErrors default []
    ---
    if (isEmpty(children))
        []
    else
        (children flatMap (child) -> do {
            var childPayload = try getSafePayload(child.errorMessage) default ""
            var grandChildren = extractCompositeErrors(child)
            ---
            if (isEmpty(childPayload))
                grandChildren
            else
                [toString(childPayload)] ++ grandChildren
        }) distinctBy $
}

/**
 * Extracts error payloads from suppressed error structures.
 * Used by Until-Successful and Validation:ANY errors.
 * Safely navigates potentially null or incomplete error structures.
 *
 * @p err The parent Mule error object.
 * @r Array of stringified error payloads from all suppressed errors.
 */
fun extractSuppressedErrors(err) = do {
    var suppressed = err.suppressedErrors default []
    ---
    if (isEmpty(suppressed))
        []
    else
        (suppressed flatMap (sup) -> do {
            var supPayload = try getSafePayload(sup.errorMessage) default ""
            var nestedSuppressed = extractSuppressedErrors(sup)
            ---
            if (isEmpty(supPayload))
                nestedSuppressed
            else
                [toString(supPayload)] ++ nestedSuppressed
        }) distinctBy $
}

/**
 * Extracts the payload from a standard (non-composite) Mule error.
 * This accesses error.exception.errorMessage.typedValue safely.
 *
 * @p err The Mule error object.
 * @r The stringified payload, or empty string if unavailable.
 */
fun extractStandardError(err) = do {
    var stdErrMsg = try err.exception.errorMessage default {} catch(e) {}
    ---
    if (isEmpty(stdErrMsg))
        ""
    else
        toString(getSafePayload(stdErrMsg))
}

/**
 * Safely extracts the HTTP status code from error attributes.
 * Handles cases where attributes or statusCode may be missing.
 *
 * @p err The Mule error object.
 * @p def Default status code if not found (default: 500).
 * @r The HTTP status code as a Number.
 */
fun getStatusCode(err, def = 500) = do {
    var attrs = try err.exception.errorMessage.attributes default {} catch(e) {}
    ---
    (attrs.statusCode default def) as Number
}

/**
 * Safely extracts the HTTP reason phrase from error attributes.
 * Handles cases where attributes or reasonPhrase may be missing.
 *
 * @p err The Mule error object.
 * @p def Default reason phrase if not found (default: "Internal Server Error").
 * @r The HTTP reason phrase as a String.
 */
fun getReasonPhrase(err, def = "Internal Server Error") = do {
    var attrs = try err.exception.errorMessage.attributes default {} catch(e) {}
    ---
    attrs.reasonPhrase default def
}

/**
 * Unified safe extractor for previous/nested error messages.
 * Combines childErrors (composite), suppressedErrors, and standard error extraction.
 * Returns a single string with all unique error messages joined by " | ".
 *
 * Priority order:
 * 1. childErrors (Scatter-Gather, Parallel-Foreach, Validation:ALL)
 * 2. suppressedErrors (Until-Successful, Validation:ANY)
 * 3. Standard error payload (most connector errors, Raise Error)
 *
 * @p err The Mule error object.
 * @r String with all unique nested error messages, or empty string if none found.
 */
fun getPreviousErrorMessage(err) = do {
    var composite  = extractCompositeErrors(err)
    var suppressed = extractSuppressedErrors(err)
    var standard   = extractStandardError(err)
    ---
    // Combine all sources, filter empties, deduplicate, join
    var allErrors = ((composite ++ suppressed ++ [standard]) filter !isEmpty($)) distinctBy $
    ---
    if (isEmpty(allErrors))
        ""
    else
        allErrors joinBy " | "
}

/**
 * Converts a value to a String representation.
 * Binary is converted as-is to Strings since it must be read to get content.
 * Primitives are directly converted to Strings.
 * Complex objects, like Objects and Arrays, are converted to the String presentation of their Java form.
 * Now includes try/catch to handle unwritable types gracefully.
 *
 * @p value to convert.
 * @p def is the default value if the provided value is empty.
 * @r String.  If empty, then returns the default value provided
 */
fun toString(value, def="") = do {
    var safeValue = if (!isEmpty(value)) value else def default ""  // No nulls allowed
    ---
    typeOf(safeValue) match {
        case "String"  -> safeValue
        case "Number"  -> safeValue as String
        case "Binary"  -> try read(safeValue, "text/plain") default write(safeValue, "application/java")
                           catch(e) "[Binary content]"
        case "Null"    -> def default ""
        else           -> try write(safeValue, "application/java")
                           catch(e) try safeValue as String
                           catch(e2) def default ""
    }
}
