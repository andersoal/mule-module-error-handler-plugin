---
id: 002
title: "Research: anatomy of childErrors/suppressedErrors per construct and payload type"
label: wayfinder:research
status: closed
assignee: anderson.guarnier
blocked-by: []
---

## Resolution (2026-07-19)

Findings: `research/composite-error-anatomy.md` on branch `research/composite-error-anatomy` (commit 538376b). Key points:

- **Scatter-Gather and Parallel For-Each are structurally identical**: top errorType `MULE:COMPOSITE_ROUTING`; inner errors carried redundantly in `childErrors[]` (full Error objects) and `errorMessage.payload.failures["<route>"]`. The inner error's type is directly readable at `childErrors[n].errorType` — unwrapping to re-resolve a mapping is mechanical.
- **Until-Successful is NOT a composite**: `MULE:RETRY_EXHAUSTED` has empty `childErrors`; the inner type surfaces via Mule 4.4 error suppression as `errorType.parentErrorType`; per-attempt errors sit in `suppressedErrors[]` (present only in the newer fixture); `errorMessage.payload` is the raw inner payload, no failures wrapper.
- **Validation `all`** raises `VALIDATION:MULTIPLE` with inner errors only in `childErrors[]`, and its top-level `errorMessage` is **null**. Validation `any` has no fixture — low confidence, verify during implementation.
- **Payload shapes**: value/descendant selectors throw on String and Binary payloads; `isEmpty(Binary)` throws before DataWeave 2.11 — matching each guard in `common.dwl`.
- **childErrors recurse** (each node has its own `childErrors`/`suppressedErrors`) and each leaf error appears 3–4× per composite, so an unwrapper needs level-by-level recursion plus dedup.

### Addendum — maintainer-confirmed (2026-07-19)

From Anderson's field experience, confirming/extending the findings:

- **VM publish-consume errors carry `suppressedErrors` like Until-Successful does** — the wrapper `VM:PUBLISH_CONSUMER_FLOW_ERROR` is not the whole story; the inner flow's error travels in `suppressedErrors`. Runtime verification widened to cover it (ticket 009). *Update: ticket 009's 4.6.1 capture with a `raise-error` consumer observed EMPTY suppressedErrors — the claim may hold only for connector failures or other runtime versions; treat as unconfirmed on 4.6.1.*
- **Validation All carries `childErrors`** — confirms the fixture-based finding for `VALIDATION:MULTIPLE`.

## Question

What do Mule Error objects actually look like — field by field — for each composite construct and payload shape this effort must cover, per Mule runtime primary docs and the captured fixtures in `src/test/resources/examples/`?

- For Scatter-Gather, Parallel For-Each, Until-Successful, Validation All/Any: which fields carry the nested errors (`childErrors`, `suppressedErrors`, `exception.errorMessage`, `errorMessage.payload`), what the top-level `errorType` is (e.g. `MULE:COMPOSITE_ROUTING`, `MULE:RETRY_EXHAUSTED`, `VALIDATION:MULTIPLE`), and where the *inner standard error's type* is accessible (needed by the unwrapping decision).
- How `errorMessage.payload` presents for each reply shape: JSON object, HTML/text string, Binary, XML (`application/xml`), null/absent, Java exception objects, repeatable streams — and which DataWeave selectors fail on which (relevant to `evalOrElse` guards in `common.dwl`).
- Whether nested composites (SG inside PFE) produce recursive `childErrors` trees and how deep the fixtures/docs show them going.

Deliverable: findings markdown — a per-construct field map plus a payload-shape × selector-behavior table, with citations.
