---
id: 007
title: "Implement payload-shape fixture suites"
label: wayfinder:task
status: closed
assignee: anderson.guarnier
blocked-by: [005, 012]
---

## Resolution (2026-07-20)

`payload-shapes-test-suite.xml` grown from the 422 seed to 11 tests covering the payload axis + all five hot intersections from the matrix (ticket 004), operation-level (through the full ee:transform), complementing the DW units in common-functions.

**Payload axis (standard errors)**: JSON object, HTML string (from `errorBody.html`), XML object (from `errorBody.xml`), Java object → JSON (locks the toString bean fix at operation level), null/empty → mapping message. Each asserts the handler responds without failing and the payload surfaces.

**Hot intersections**: SG wrapping a Binary route payload; SG wrapping an HTML route payload; Until-Successful with an HTML suppressed body; nested composite (SG-in-PFE) deep-leaf unwrap → 503; mixed payload types (JSON + Binary + duplicate) aggregated dedup-safe (asserts both messages present and the repeat collapses to one).

**Reconciliation**: plain-text and Binary standard-error operation cases were left in `process-error-test-suite.xml` (not duplicated); DW-unit payload cases stay in `common-functions-test-suite.xml`. **Repeatable stream skipped-with-reason** (comment in the suite): cannot be staged deterministically without a connector round-trip; the Binary cell covers the unreadable-content path.

Full run: **59 tests green across 9 suites** via `mvn clean verify`. Every matrix cell is now tested or explicitly skipped-with-reason — the map's destination is reached.

## Question

Implement the fixture-driven MUnit tests covering the payload-shape cells of the matrix (ticket 004) — JSON, HTML, text, Binary, XML, null/empty/missing, Java objects/streams — for both standard and composite errors, using the fixtures from ticket 005, and reconcile/absorb the overlapping existing tests in `process-error-test-suite.xml` and `common-functions-test-suite.xml`.

Resolution: suites merged and green; the map's destination check — every matrix cell either tested or explicitly skipped with a reason.
