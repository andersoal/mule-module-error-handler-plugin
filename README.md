# Documentation

[Home - Exchange Docs](./exchange-docs/home.md)

[Changelog](./CHANGELOG.md)

## Testing

MUnit test suites live in `src/test/munit`:

- `process-error-test-suite.xml` — tests the `process-error` operation against serialized real-world Mule error objects (`src/test/resources/examples`), covering composite errors with `childErrors` (Scatter-Gather, Parallel For-Each, Validation _All_), Until-Successful errors with `suppressedErrors`, and error payloads that are plain text (`text/plain`) or Binary.
- `common-functions-test-suite.xml` — unit tests for the exported DataWeave functions in `module_error_handler_plugin::common` (`getErrorTypeAsString`, `getError`, `toString`, `isEmptyValue`, `evalOrElse`, `getPreviousErrorMessage`).

Run them with Maven (requires access to the MuleSoft EE repositories; see `example.settings.xml`):

```sh
mvn clean test
```
