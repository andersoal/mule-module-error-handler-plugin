---
id: 012
title: "Add 422 default mapping to defaultErrors.dwl"
label: wayfinder:task
status: closed
assignee: anderson.guarnier
blocked-by: [011]
---

## Resolution (2026-07-19)

- `defaultErrors.dwl`: added `"*:UNPROCESSABLE_ENTITY"` → `{code: 422, reason: "Unprocessable Entity", message: "The request was well-formed but could not be processed."}` (fixed static message per ticket 008; comment notes the downstream-422/MULE:UNKNOWN limitation).
- Test: `unprocessable-entity-wildcard-maps-to-422` asserts status, reason, and the fixed message for an app-raised `APP:UNPROCESSABLE_ENTITY`.
- Docs: Features bullet + "422 Unprocessable Entity" section in `exchange-docs/home.md`, including the documented workaround for downstream 422s (a `MULE:UNKNOWN` custom entry inspecting `error.errorMessage.attributes.statusCode`) pending ticket 014.

## Question

Implement the 422 mapping decided in ticket 008, **narrowed by ticket 011's finding** (downstream 422s surface as `MULE:UNKNOWN`, which cannot be a mapping key — downstream handling is now ticket 014's decision): add only the `"*:UNPROCESSABLE_ENTITY"` wildcard entry to `defaultErrors.dwl` as `{code: 422, reason: "Unprocessable Entity", message: "The request was well-formed but could not be processed."}` (fixed static message, no new message variable), and update the exchange-docs error table.

Resolution: entries merged with DataWeave-level tests in `common-functions-test-suite.xml`; scenario tests ride the matrix suites.
