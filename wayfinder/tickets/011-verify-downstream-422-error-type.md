---
id: 011
title: "Verify what error type a downstream 422 reply surfaces as"
label: wayfinder:task
status: closed
assignee: anderson.guarnier
blocked-by: []
---

## Resolution (2026-07-19)

Verified on Mule EE 4.6.1 + HTTP connector 1.9.3, via `capture-downstream-422-error-shape` in `src/test/munit/explore-error-shapes-suite.xml` (a real listener replying 422, called by a real requester):

- The requester raises **`MULE:UNKNOWN`** (parent `MULE:ANY`) — there is no `HTTP:` error type for 422, and the surfaced type is the generic unknown.
- `error.description` = `"HTTP POST on resource '…' failed with status code 422."`
- The reliable signals are in the error message: `error.errorMessage.attributes.statusCode` = `422`, `reasonPhrase` = `"Unprocessable Entity"`, and `errorMessage.payload` carries the response body.
- Full serialized error captured as fixture `src/test/resources/examples/Http422UnprocessableError.json`.

**Consequence — partial invalidation of ticket 008's downstream plan**: a `defaultErrors.dwl` entry keyed `MULE:UNKNOWN` is impossible (it would remap every unknown error to 422). Propagating downstream 422s needs either status-code-aware logic or must be left to consumers. That decision graduated to ticket 014; ticket 012 was narrowed to the `*:UNPROCESSABLE_ENTITY` wildcard entry only.

## Question

On this repo's pinned Mule runtime and HTTP connector version: when an HTTP requester receives a 422 response (a status code with no dedicated `HTTP:` error type), what error does it raise — namespace, identifier, `errorType.parentErrorType`, and what lands in `errorMessage.payload`/`attributes.statusCode`?

Run a small exploratory MUnit/lab test (e.g. requester against a mocked 422 endpoint) and capture the full serialized error as a fixture in `src/test/resources/examples/`.

Resolution records the surfaced type — it becomes the key of the downstream-422 entry in `defaultErrors.dwl` (ticket 012) and defines the 422 cells in the matrix (ticket 004).
