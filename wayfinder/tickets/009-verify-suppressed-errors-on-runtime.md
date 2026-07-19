---
id: 009
title: "Verify suppressedErrors shape on the pinned runtime"
label: wayfinder:task
status: closed
assignee: anderson.guarnier
blocked-by: []
---

## Resolution (2026-07-19)

Verified on Mule EE 4.6.1 via the exploratory suite `src/test/munit/explore-error-shapes-suite.xml` (kept in the repo; both tests green under `mvn verify`).

**Until-Successful** (wrapping a genuine `HTTP:CONNECTIVITY`, maxRetries=2 → 3 attempts):
- `errorType` = `MULE:RETRY_EXHAUSTED`; `errorType.parentErrorType` = `MULE:CONNECTIVITY` — error suppression rewrites the parent chain toward the suppressed error's hierarchy.
- `childErrors` empty; `suppressedErrors` holds **exactly one** entry (`HTTP:CONNECTIVITY`) — NOT one per attempt. The existing fixture `UntilSuccessfulSuppressedErrors.json` (distinct attempt-1/attempt-2 entries) over-represents 4.6.1 behavior; keep it as a shape-robustness fixture but don't treat per-attempt aggregation as guaranteed.
- `description` carries the inner error's message.
- **`write(error, "application/json")` THROWS** (NPE inside `SuppressedMuleException.getVerboseMessage`) — serializing a retry-exhausted error fails on 4.6.1. Any unwrapping/logging code path must guard serialization (`evalOrElse`), and fixtures for this shape cannot be captured via `write()`.

**VM publish-consume** (consumer flow fails with `raise-error APP:BOOM`):
- `errorType` = `VM:PUBLISH_CONSUMER_FLOW_ERROR`, parent `MULE:ANY`.
- `childErrors` **and** `suppressedErrors` both **EMPTY** — contradicts the field expectation recorded on ticket 002's addendum. The inner error surfaces only as text in `description` (`"APP:BOOM: consumer flow failed"`); `errorMessage` is null.
- Full serialization works; captured as new fixture `src/test/resources/examples/VmPublishConsumeError.json`.
- Caveat: only tested with `raise-error` in the consumer; a connector failure inside the consumer flow was not tested and could differ.

**Consequences for the unwrapping implementation (ticket 010)**: the VM wrapper yields no leaves on 4.6.1 → the decided fallback path (composite's own mapping) applies; the leaf-walker must guard every serialization/selector against the RETRY_EXHAUSTED NPE.

**Build wiring facts discovered en route** (pom.xml changes kept):
- MUnit had never been runnable via Maven in this repo. Now wired: `munit-runner`/`munit-tools` **3.1.0** test deps (3.6.3 fails deployment on 4.6.1 with `EnumConstantNotPresentException: JavaVersion.JAVA_21`), maven-resources-plugin copying `src/test/munit` → `target/test-mule/munit` (MTF discovers suites there), plugin execution bound to integration-test, HTTP connector 1.9.3 + VM connector 2.0.1 as plugin deps (2.0.2 does not exist).
- All 18 pre-existing tests pass under `mvn verify` (scratch pom with real groupId and exchange plugin removed).
- `build.sh` substitutes `ORG_ID_TOKEN` but the pom's groupId is `ORD_ID_TOKEN` — token mismatch; and `exchange-pre-deploy` (validate phase) fails any build whose groupId isn't a real org id. Repeatable-run fix graduated to ticket 013.

## Question

`error.suppressedErrors` is undocumented in primary sources (ticket 001) yet `getPreviousErrorMessage` in `common.dwl` depends on it for Until-Successful retries — and per the maintainer's field experience, **VM publish-consume errors carry `suppressedErrors` the same way** (beneath the `VM:PUBLISH_CONSUMER_FLOW_ERROR` wrapper). Before flow-based suites assert on it: run exploratory MUnit tests on this repo's pinned runtime that trigger (a) a real Until-Successful exhaustion (ideally via a genuine connector failure, since `raise-error` won't produce connector-namespaced suppressed errors) and (b) a `vm:publish-consume` whose consumer flow fails, and capture what `error.suppressedErrors`, `errorType.parentErrorType`, and `errorMessage.payload` actually contain in each.

Resolution records the observed shapes (serialize them as new fixtures in `src/test/resources/examples/` — the VM case has no fixture at all today) and whether `UntilSuccessfulSuppressedErrors.json` is faithful.
