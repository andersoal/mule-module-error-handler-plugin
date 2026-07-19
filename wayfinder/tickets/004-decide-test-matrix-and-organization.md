---
id: 004
title: "Decide the test matrix and suite organization"
label: wayfinder:grilling
status: open
assignee:
blocked-by: [001, 003, 008, 011, 014]
---

## Question

Which exact scenario × payload combinations become MUnit tests, and how are the suites and fixtures organized?

- The matrix: constructs (standard error; SG; PFE; Until-Successful; Validation All/Any; nested composites; Async/VM/Foreach) × payload shapes (JSON, HTML, text, Binary, XML, null/empty/missing, Java objects/streams) — which cells are real-flow tests (per ticket 001's patterns), which are fixture tests, and which are deliberately skipped as redundant.
- Expected assertions per cell, per the unwrapping decision (ticket 003): httpStatus, payload.error.{code,reason,message}, attributes.errorLog, previousError aggregation.
- Suite file layout (e.g. one suite per construct family vs per payload family), naming conventions, fixture directory structure, and which existing tests get absorbed or kept.

Resolution is a matrix table + layout decision recorded on this ticket; implementation tickets (005–007) build from it.
