---
id: 016
title: "Pin thin edge-case extraction scenarios"
label: wayfinder:task
status: closed
assignee: anderson.guarnier
blocked-by: []
---

## Question

Lock the three payload/extraction edge shapes that the feature branch's fixtures target but this branch's suite does not yet assert directly. The extraction path already handles them by construction; this ticket pins that behaviour so a regression can't slip through.

The three shapes:

- **childError with no `errorMessage` field** — a composite whose children are structurally inconsistent (some carry a payload, some carry nothing); extraction skips the empty ones without failing.
- **mixed-payload composite including null/missing** — one composite whose `childErrors` mix JSON object, plain text, `null`, and absent payloads; aggregation collects the real messages, drops the empties, and does not break on the mix.
- **4-level nesting** — Parallel-Foreach › Scatter-Gather › Validation-style depth; the recursive walk reaches the deep leaves.

**Status:** closed (2026-07-20)

- [x] A composite with a childError lacking `errorMessage` extracts the other children's messages without failing.
- [x] A composite mixing JSON / text / null / missing child payloads aggregates the non-empty messages, drops empties (all-empty children → `''`), and does not throw.
- [x] A 4-level nested composite is walked to its deep leaves — both `getPreviousErrorMessage` aggregation and `resolveNestedErrorMapping` mapping (→ 404).
- [x] Full suite green via `mvn clean verify`.

## Resolution (2026-07-20)

Added `get-previous-error-message-structural-edge-cases` to `common-functions-test-suite.xml` (child with no errorMessage → sibling still extracts; mixed JSON/text/null/missing → non-empties aggregated; all-empty → `''`; 4-level deep leaf reached) plus a 4-level assertion in `resolve-nested-error-mapping-rules`. Behaviour already correct by construction; these pin it. 64 tests green.
