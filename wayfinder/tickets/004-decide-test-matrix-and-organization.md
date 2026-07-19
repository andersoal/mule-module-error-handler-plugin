---
id: 004
title: "Decide the test matrix and suite organization"
label: wayfinder:grilling
status: closed
assignee: anderson.guarnier
blocked-by: [001, 003, 008, 011, 014]
---

## Resolution (2026-07-19)

**Density: axes + hot intersections** (~25–30 new tests, no redundant cells — payload handling and construct resolution are independent code paths, so the cross-product is sampled only where they actually interact).

**Suite layout: one suite per construct.** Final file set (`src/test/munit/`):

- `common-functions-test-suite.xml` — DW units (as-is)
- `process-error-test-suite.xml` — operation semantics: params, mappings, unwrapping, passthrough (as-is)
- `payload-shapes-test-suite.xml` — NEW: payload axis + hot intersections (fixture/inline-driven)
- `scatter-gather-test-suite.xml`, `parallel-foreach-test-suite.xml`, `until-successful-test-suite.xml`, `validation-test-suite.xml`, `vm-test-suite.xml`, `async-foreach-test-suite.xml` — NEW: real-flow construct suites (Async+Foreach share one; both are propagation paths with few tests)
- `explore-error-shapes-test-suite.xml` **dissolves**: its three capture tests move into until-successful, vm, and process-error/payload suites respectively.

**Standard assertions per cell**: `attributes.httpStatus`, `payload.error.{code, reason, message}`, `attributes.errorLog`; construct cells additionally assert both `resolveNestedErrors` off (backward compat) and on (leaf mapping) where nested errors exist.

**The matrix**:

*Payload axis* (standard errors, `payload-shapes-test-suite`): JSON object; HTML page (text/html string); plain text; Binary; XML (application/xml); null/absent errorMessage + empty childErrors/suppressedErrors; Java exception object & repeatable stream. Each cell: `getPreviousErrorMessage` extracts safely, operation responds without failing.

*Construct axis* (real flows, one representative payload, per-construct suites):
- Scatter-Gather: two failing routes → `MULE:COMPOSITE_ROUTING`, default 500 + unwrap → leaf mapping + childErrors aggregation.
- Parallel For-Each: failing iterations → same pattern.
- Until-Successful: genuine connector failure (capture test absorbed) + unwrap → leaf via suppressedErrors.
- Validation All: two failing rules → `VALIDATION:MULTIPLE` 400 + aggregation. Validation Any: attempt; feasibility unverified (no fixture exists) — implementer may record it as skipped-with-reason.
- VM publish-consume: capture test absorbed + unwrap-fallback behavior (no nested errors on 4.6.1).
- Async: error never reaches the caller — characterization via queue-based observation.
- Foreach: plain propagation of the item error.

*Hot intersections* (`payload-shapes-test-suite`): SG wrapping a Binary route payload; SG wrapping text/HTML payload; Until-Successful with HTML error body; nested composite (SG inside PFE) with deep-leaf unwrap; mixed payload types (JSON + Binary) in one composite with dedup-safe aggregation.

*Deliberately skipped*: all other construct × payload combinations (same code path as an axis cell), Async × payloads (error never reaches the handler).

## Question

Which exact scenario × payload combinations become MUnit tests, and how are the suites and fixtures organized?

- The matrix: constructs (standard error; SG; PFE; Until-Successful; Validation All/Any; nested composites; Async/VM/Foreach) × payload shapes (JSON, HTML, text, Binary, XML, null/empty/missing, Java objects/streams) — which cells are real-flow tests (per ticket 001's patterns), which are fixture tests, and which are deliberately skipped as redundant.
- Expected assertions per cell, per the unwrapping decision (ticket 003): httpStatus, payload.error.{code,reason,message}, attributes.errorLog, previousError aggregation.
- Suite file layout (e.g. one suite per construct family vs per payload family), naming conventions, fixture directory structure, and which existing tests get absorbed or kept.

Resolution is a matrix table + layout decision recorded on this ticket; implementation tickets (005–007) build from it.
