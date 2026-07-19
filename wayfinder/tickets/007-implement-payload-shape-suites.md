---
id: 007
title: "Implement payload-shape fixture suites"
label: wayfinder:task
status: open
assignee:
blocked-by: [005, 012]
---

## Question

Implement the fixture-driven MUnit tests covering the payload-shape cells of the matrix (ticket 004) — JSON, HTML, text, Binary, XML, null/empty/missing, Java objects/streams — for both standard and composite errors, using the fixtures from ticket 005, and reconcile/absorb the overlapping existing tests in `process-error-test-suite.xml` and `common-functions-test-suite.xml`.

Resolution: suites merged and green; the map's destination check — every matrix cell either tested or explicitly skipped with a reason.
