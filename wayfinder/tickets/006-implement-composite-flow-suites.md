---
id: 006
title: "Implement flow-based composite error suites"
label: wayfinder:task
status: closed
assignee: anderson.guarnier
blocked-by: [004, 009, 010]
---

## Resolution (2026-07-19)

Six per-construct suites implemented (layout per ticket 004), all raising **genuine** runtime errors — validation failures and dead-endpoint HTTP connectivity errors, no serialized fixtures:

- `scatter-gather-test-suite` (4): real `MULE:COMPOSITE_ROUTING` from failing routes — default 500, unwrap picks highest-status leaf (mixed VALIDATION 400 + HTTP:CONNECTIVITY 503 → 503), validation-only unwrap → 400, childErrors aggregation.
- `parallel-foreach-test-suite` (3): same pattern via failing iterations.
- `until-successful-test-suite` (3): absorbed the ticket-009 capture test + unwrap via suppressedErrors leaf → 503 + default-off 500.
- `validation-test-suite` (3): real `VALIDATION:MULTIPLE` → 400, unwrap keeps 400 via leaves, rule-message aggregation. **Validation Any: skipped-with-reason** — no fixture exists and its childErrors shape is unverified on 2.0.7; revisit if the `any` scope enters real use.
- `vm-test-suite` (2): absorbed the capture test + unwrap-falls-back-to-wrapper-mapping (custom entry), matching 4.6.1's empty nested errors.
- `async-foreach-test-suite` (2): Foreach propagates the plain item error (APP type, UNKNOWN 500, description as message); Async never reaches the caller (queue-observed characterization).
- `explore-error-shapes-suite` dissolved: capture tests moved to until-successful / vm / payload-shapes suites.

**Module bug found and fixed by these tests**: a live validation error's `errorMessage.payload` is an `ImmutableValidationResult` Java bean, and `toString`'s `application/java` write rendered it as `ClassName@hash`, losing the rule messages (serialized fixtures had hidden this). `toString` now writes complex values as JSON first, Java form as last resort.

Build additions: `mule-validation-module` 2.0.7 as a munit-extensions plugin dependency. Full run: **46 tests green across 9 suites**.

## Question

Implement the per-construct MUnit suites (layout per ticket 004: scatter-gather, parallel-foreach, until-successful, validation, vm, async-foreach; the explore suite's capture tests dissolve into them) where real flows raise genuine composite errors — Scatter-Gather, Parallel For-Each, Until-Successful, Validation All/Any, nested composites, and Async/VM/Foreach propagation — using the patterns from ticket 001 and asserting the matrix cells from ticket 004 (including whichever unwrapping behavior ticket 003 locked in, plus any module changes that decision spawned).

Resolution: suites merged and green via the munit-extensions-maven-plugin build; note any matrix cells that couldn't be realized as real flows and fell back to fixtures.
