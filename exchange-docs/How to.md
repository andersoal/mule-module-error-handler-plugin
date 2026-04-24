
# How to

This document provides a step-by-step guide on how to configure and use the error handler plugin effectively in your application. This module does not have a separate global configuration for ease of use, so all configurations are done within the application itself.

### Installation

#### Studio or Anypoint Code Builder

You can find and install from Exchange in Studio or Anypoint Code Builder (vscode). Search for "Error Handler" and select the appropriate version for your project.

#### Maven Dependency

If you are using Maven, add the following dependency to your `pom.xml` file:

```xml
<dependency>
    <groupId>${replace-with-group-id}</groupId>
    <artifactId>error-handler-plugin</artifactId>
    <version>6.3.1</version>
    <classifier>mule-plugin</classifier>
</dependency>
```

### App Configuration

Add file `error.xml` to your app's `src/main/mule` directory with the following content:

...

### Add Custom Errors

The module provides a set of default errors, but you can also add custom errors to fit your application's needs. To add custom errors, follow these steps:

1. Create a new file in `errors/customErrors.dwl` and define your custom errors in the following format:

```js,dw,dwl
%dw 2.0
output application/json
import * from module_error_handler_plugin::common

/**
 * Previous error nested in the Mule error object.
 * Provides the entire payload of the previous error as a String.
 * Handles the main Mule Error formats to get nested errors:
 * - Composite modules/scopes, like Scatter-Gather, Parallel-Foreach, Group Validation Module
 * - Until-Successful
 * - Standard Error, like Raise Error, ForEach, and most connectors and errors.
 */
var previousError = do {
    var nested = [
        error.childErrors..errorMessage.payload,        // Composite
        error.suppressedErrors..errorMessage.payload,   // Until-Successful
        error.exception.errorMessage.typedValue         // Standard Error: must go last because it has content if this is one of the other types of errors
    ] dw::core::Arrays::firstWith !isEmpty($)
    ---
    if (nested is Array)
        toString(nested map (toString($)) distinctBy $)
    else
        toString(nested)
}
---
{
    "APP:NO_CONTENT": {
        code: 200,
        reason: "OK with No Content",
        message: error.description,
    },
    "APP:UNAUTHORIZED": {
        code: 401,
        reason: "Unauthorized",
        message: error.description
    },
    "APP:NOT_FOUND": {
        code: 404,
        reason: "Resource Not Found",
        message: error.description,
    },
    "APP:NOT_ACCEPTABLE": {
        code: 406,
        reason: "Not Acceptable",
        message: error.description,
    },
    "APP:NOT_IMPLEMENTED": {
        code: 501,
        reason: "Not Implemented",
        message: error.description,
    },
    "APP:SERVICE_UNAVAILABLE": {
        code: 503,
        reason: "Service Unavailable",
        message: error.description
    },
    "HTTP:INTERNAL_SERVER_ERROR": {
        code: 500,
        reason: "Internal Server Error",
        message: if (!isEmpty(previousError)) previousError else error.description
    },
    "MULE:UNKNOWN": {
        code   : error.exception.errorMessage.attributes.statusCode default 500,
        reason : error.exception.errorMessage.attributes.reasonPhrase default "Internal Server Error",
        message: if (!isEmpty(previousError)) previousError else error.description
    },
    "OS:KEY_NOT_FOUND": {
        code   : 404, // 204 No Content / 404 Not Found
        reason : "Id Not Found",
        message: "Some of the parameters was not found."
    },
    // Others HTTP:*
    "HTTP:BASIC_AUTHENTICATION"  : { code: 401, reason: error.exception.errorMessage.attributes.reasonPhrase default "Unauthorized"          , message: error.description },
    "HTTP:GATEWAY_TIMEOUT"       : { code: 504, reason: error.exception.errorMessage.attributes.reasonPhrase default "Time Out"              , message: error.description },
    "HTTP:SERVER_SECURITY"       : { code: 511, reason: error.exception.errorMessage.attributes.reasonPhrase default "Server Security Issue" , message: error.description },
    "HTTP:SERVICE_UNAVAILABLE"   : { code: 511, reason: error.exception.errorMessage.attributes.reasonPhrase default "Service Unavailable"   , message: error.description },
    "HTTP:TRANSFORMATION"        : { code: 500, reason: error.exception.errorMessage.attributes.reasonPhrase default "Bad Request"           , message: "Error with data transformation. See log for details." },
    "HTTP:UNSUPPORTED_MEDIA_TYPE": { code: 415, reason: error.exception.errorMessage.attributes.reasonPhrase default "Unsupported Media Type", message: error.description },
    //
    "MULE:DUPLICATE_MESSAGE": {
        code         : 409,/** 409-Conflict 208-AlreadyReported */
        reason       : "Already Processing",
        message      : "A request is already being processed" ++ (
            if(not isEmpty(vars.valueIdempotentMessageValidator))
                " for transaction [$(vars.valueIdempotentMessageValidator default '')]."
            else "."
        ),
    },
    "VALIDATION:INVALID_BOOLEAN": {
        code        : 400,
        reason      : "Bad Request",
        message     : error.description,
    },
    "VALIDATION:*": {
        code        : 400,
        reason      : "Bad Request",
        message     : error.description,
    },
    "APP:VALIDATION": {
        code        : 400,
        reason      : "Bad Request",
        message     : error.description,
    },
    "MULE:EXPRESSION": {
        code: 500,
        reason: "Internal Server Error",
        // usually it will capture fail() dataweave function
        message: (
        if(error.description contains( "org.mule.weave.v2.exception.UserException: "))
            (
                (error.description splitBy "\n\n")[0]
                splitBy "org.mule.weave.v2.exception.UserException: "
            )[1]
        else if(error.description contains "org.mule.weave.v2.core.exception.UserException: ")
            (
                (error.description splitBy "\n\n")[0]
                splitBy "org.mule.weave.v2.core.exception.UserException: "
            )[1]
        else if(error.description contains "fun fail (message:" )
            (
                (error.description splitBy "\n\n")[0]
                splitBy "\""
            )[1]
        else ""
        )
    },
    // Composite Errors
    "MULE:RETRY_EXHAUSTED": {
        code: 503,
        reason: "Service Unavailable",
        message: error.description,
        //details: (error.suppressedErrors default []) map((item,index) -> {})
    },
    "VM:PUBLISH_CONSUMER_FLOW_ERROR":{
        code: 503,
        reason: "Service Unavailable",
        message: error.description,
        //details: (error.suppressedErrors default []) map((item,index) -> {})
    },
    "VALIDATION:MULTIPLE": {
        code: 400,
        reason: "Multiple Validation Errors",
        message: error.description,
        //details: (error.childErrors default []) map((item,index) -> {})
    },
    "MULE:COMPOSITE_ROUTING": {
        code: 400,
        reason: "Multiple Validation Errors",
        message: error.description,
        //details: (error.childErrors default []) map((item,index) -> {})
    },
}
```
