---
id: 001
title: "Research: raising genuine composite errors inside MUnit flows"
label: wayfinder:research
status: closed
assignee: anderson.guarnier
blocked-by: []
---

## Resolution (2026-07-19)

Findings: `research/munit-composite-error-flows.md` on branch `research/munit-composite-error-flows` (commit 1d74b57). Key points:

- **Yes — genuine composite errors are producible in MUnit.** Suite files accept top-level `<flow>` elements; helper flows with `raise-error` routes inside Scatter-Gather / Parallel For-Each (real `MULE:COMPOSITE_ROUTING` with `childErrors`), Until-Successful (`MULE:RETRY_EXHAUSTED`), and `validation:all` (`VALIDATION:MULTIPLE`), caught by `on-error-continue` → `#[error]` → variable → `process-error`. Per-construct XML sketches are in the findings doc.
- **XML-SDK constraint is mild**: `munit:enable-flow-sources` matters only for flow *sources*, not `flow-ref`; core scopes need no extra dependency, but the Validation module / VM connector must be added as `mule-plugin` dependencies of the `munit-extensions-maven-plugin`.
- **Caveat — `suppressedErrors` is undocumented** in primary sources (absent from docs and the mule-api `Error` interface; only the suppression behavior is official, 4.4.0 release notes). Needs an exploratory test on the pinned runtime before assertions rely on it; `raise-error` inside Until-Successful won't reproduce connector-namespaced suppressed errors — a real connector failure is needed. → spawned ticket 009.
- **Async never propagates to the caller** (observe via blocking `munit-tools` queue/dequeue); `vm:publish-consume` propagates synchronously but wrapped as `VM:PUBLISH_CONSUMER_FLOW_ERROR`; plain `foreach` propagates the plain non-composite error deterministically.
- **Fidelity**: helper-flow errors are genuine runtime errors; only *mocked* errors differ (`MULE:UNKNOWN` fallback, no connector `errorMessage`). Serialized JSON fixtures over-represent live error objects (the DataWeave `Error` type exposes fewer fields).

## Question

What are the reliable MUnit patterns for producing **genuine** Mule composite error objects inside a test, so `process-error` can be exercised against real `childErrors`/`suppressedErrors` structures instead of serialized fixtures?

Specifically, against MUnit + Mule runtime primary docs (versions per this repo's `pom.xml`):

- Can a test (or a helper flow invoked via `flow-ref`) contain a Scatter-Gather / Parallel For-Each / Until-Successful / Validation All whose routes fail (via `raise-error` or `munit-tools:mock-when`), with the resulting error caught by an `on-error-continue` that calls `process-error` and exposes the result for assertions?
- How does `munit:enable-flow-sources` / test-flow structure constrain this for an XML-SDK module test suite (no app flows of its own)?
- How are errors raised inside Async / VM publish-consume / Foreach surfaced to the caller's error handler, and can MUnit observe them deterministically?
- Any known limitations where the MUnit runtime's composite error differs from a production one (e.g. `exception` field, `errorMessage` typedValue serialization)?

Deliverable: findings markdown with citations + minimal working XML sketches per construct.
