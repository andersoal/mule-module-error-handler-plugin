---
id: 012
title: "Add 422 default mapping to defaultErrors.dwl"
label: wayfinder:task
status: open
assignee:
blocked-by: [011]
---

## Question

Implement the 422 mapping decided in ticket 008, **narrowed by ticket 011's finding** (downstream 422s surface as `MULE:UNKNOWN`, which cannot be a mapping key — downstream handling is now ticket 014's decision): add only the `"*:UNPROCESSABLE_ENTITY"` wildcard entry to `defaultErrors.dwl` as `{code: 422, reason: "Unprocessable Entity", message: "The request was well-formed but could not be processed."}` (fixed static message, no new message variable), and update the exchange-docs error table.

Resolution: entries merged with DataWeave-level tests in `common-functions-test-suite.xml`; scenario tests ride the matrix suites.
