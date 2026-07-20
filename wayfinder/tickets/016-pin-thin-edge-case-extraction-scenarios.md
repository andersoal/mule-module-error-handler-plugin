---
id: 016
title: "Pin thin edge-case extraction scenarios"
label: wayfinder:task
status: open
assignee:
blocked-by: []
---

## Question

Lock the three payload/extraction edge shapes that the feature branch's fixtures target but this branch's suite does not yet assert directly. The extraction path already handles them by construction; this ticket pins that behaviour so a regression can't slip through.

The three shapes:

- **childError with no `errorMessage` field** — a composite whose children are structurally inconsistent (some carry a payload, some carry nothing); extraction skips the empty ones without failing.
- **mixed-payload composite including null/missing** — one composite whose `childErrors` mix JSON object, plain text, `null`, and absent payloads; aggregation collects the real messages, drops the empties, and does not break on the mix.
- **4-level nesting** — Parallel-Foreach › Scatter-Gather › Validation-style depth; the recursive walk reaches the deep leaves.

**Status:** ready-for-agent

- [ ] A composite with a childError lacking `errorMessage` extracts the other children's messages without failing.
- [ ] A composite mixing JSON / text / null / missing child payloads aggregates the non-empty messages, drops empties, and does not throw.
- [ ] A 4-level nested composite is walked to its deep leaves (message aggregation and, where applicable, `resolveNestedErrors` mapping).
- [ ] Full suite green via `mvn clean verify`.
