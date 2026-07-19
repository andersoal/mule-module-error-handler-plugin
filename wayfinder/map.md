---
label: wayfinder:map
title: MUnit coverage for composite & standard error structures
created: 2026-07-19
---

# MUnit coverage for composite & standard error structures

Tickets live in `wayfinder/tickets/`. A ticket is claimed by setting its `assignee:`; it is open until `status: closed`. Blocking uses the `blocked-by:` frontmatter list (ticket ids). The frontier = open, unblocked, unassigned tickets.

## Destination

New MUnit test suites merged and passing in this repo, systematically covering the error-shape matrix — standard and composite errors × payload shapes (JSON, HTML, plain text, Binary, XML, null/empty, Java objects/streams) — with real MUnit flows producing genuine composite errors, plus the composite-unwrapping decision resolved and locked in by tests.

## Notes

- **This is a plugin** (XML-SDK module), not an app: it has no flows, listeners, or error handlers of its own. Tests exercise the `process-error` operation directly (or via helper flows defined inside the MUnit suite files); consumer-app wiring is out of scope. Any default-mapping change (e.g. 422) must weigh backward compatibility for existing consumers.
- HTTP 422 (Unprocessable Entity) is in scope — no default mapping exists today; see the 422 decision ticket.
- Mule SDK (XML) module; logic is DataWeave in `src/main/resources/module_error_handler_plugin/` (`common.dwl`, `defaultErrors.dwl`) plus the module XML in `src/main/resources/`.
- Existing suites: `src/test/munit/common-functions-test-suite.xml`, `src/test/munit/process-error-test-suite.xml` (12 tests). Fixtures: `src/test/resources/examples/*.json` (serialized Mule errors captured from real apps).
- **This effort carries execution into the map**: the final tickets implement the suites, not just decide them.
- Error-source strategy: real MUnit flows for composite scenarios (Scatter-Gather, Parallel For-Each, Until-Successful, Validation All/Any, nested composites, Async/VM/Foreach); JSON fixtures for payload-shape cases.
- No coverage gate — scenario coverage is the deliverable.
- MUnit runs via Maven since tickets 009/013: plain `mvn clean verify` on the raw pom (MUnit 3.1.0 — do NOT bump past the 4.6-compatible line; HTTP 1.9.3 + VM 2.0.1 as munit-extensions plugin deps; Exchange publication only under the `release` profile).
- Older brainstorm test plan at `plan/2026-04-23.plan.md` is input material, not authoritative.
- Skills to consult per ticket type: `/grilling` + `/domain-modeling` for decision tickets, `/research` for research tickets, `/tdd` for implementation tickets.

## Decisions so far

<!-- one line per closed ticket: gist + link -->

- [Research: raising genuine composite errors inside MUnit flows](tickets/001-research-munit-composite-error-flows.md) — feasible: helper flows inside suite files with raise-error routes produce real composite errors caught via on-error-continue; Validation/VM need extra munit-extensions-maven-plugin dependencies; `suppressedErrors` is undocumented and needs runtime verification (spawned ticket 009); Async needs queue-based observation; VM wraps as `VM:PUBLISH_CONSUMER_FLOW_ERROR` and (maintainer-confirmed) carries the inner error in `suppressedErrors` like Until-Successful. Full findings on branch `research/munit-composite-error-flows`.
- [Research: anatomy of childErrors/suppressedErrors per construct and payload type](tickets/002-research-composite-error-anatomy.md) — SG/PFE expose inner error types at `childErrors[n].errorType` (unwrapping is mechanical); Until-Successful is not a composite (inner type via `errorType.parentErrorType`, attempts in `suppressedErrors`); Validation `all` has null top-level errorMessage; childErrors recurse with 3–4× leaf duplication. Full findings on branch `research/composite-error-anatomy`.
- [Decide composite unwrapping behavior](tickets/003-decide-composite-unwrapping.md) — unwrapping is in, behind opt-in `resolveNestedErrors` (default false): tiered trigger (known wrapper types, else UNKNOWN+nested-errors catch-all), recursion to deduped leaf standard errors, numeric-max status wins, unwrap beats a custom composite entry with the composite mapping as fallback. Implementation graduated to ticket 010.
- [Decide 422 Unprocessable Entity coverage](tickets/008-decide-422-unprocessable-entity-mapping.md) — both sources: a `*:UNPROCESSABLE_ENTITY` wildcard default for app-raised 422s, plus a mapping for whatever type a downstream 422 reply actually surfaces as (fact to verify — ticket 011); fixed static message, no new message variable. Implementation graduated to ticket 012.
- [Verify suppressedErrors shape on the pinned runtime](tickets/009-verify-suppressed-errors-on-runtime.md) — on 4.6.1: Until-Successful carries ONE suppressed inner error (not per-attempt) and `write(error, …)` throws NPE on it; VM publish-consume has EMPTY childErrors/suppressedErrors (inner error is description text only — new fixture `VmPublishConsumeError.json`); MUnit is now runnable via Maven (MTF wiring added to pom, MUnit 3.1.0, all 18 existing tests green). Repeatable-run fix graduated to ticket 013.
- [Verify what error type a downstream 422 reply surfaces as](tickets/011-verify-downstream-422-error-type.md) — `MULE:UNKNOWN` (status/reason/body only in `errorMessage.attributes`/`payload`; fixture `Http422UnprocessableError.json`), so no default-mapping key exists for downstream 422s; that decision graduated to ticket 014 and ticket 012 narrowed to the wildcard entry.
- [Make the Maven MUnit run repeatable](tickets/013-make-maven-munit-run-repeatable.md) — `mvn clean verify` now runs all suites on the raw pom: groupId token typo fixed, exchange plugin moved to a `release` profile (build.sh deploy passes `-Prelease`), README documents the command.
- [Implement resolveNestedErrors in the module](tickets/010-implement-resolve-nested-errors.md) — shipped TDD: `findErrorMapping`/`getLeafErrors`/`resolveNestedErrorMapping` in common.dwl, opt-in `resolveNestedErrors` parameter wired into both transforms, 8 new tests covering all decided rules, docs section added. 30 tests green.
- [Add 422 default mapping to defaultErrors.dwl](tickets/012-add-422-default-mapping.md) — `*:UNPROCESSABLE_ENTITY` wildcard entry with the fixed static message, test, and docs (including the downstream-422 workaround note pending the 014 decision).
- [Decide the test matrix and suite organization](tickets/004-decide-test-matrix-and-organization.md) — axes + hot intersections (~25–30 new tests); one suite per construct (6 new construct suites + payload-shapes suite; explore suite dissolves into them); standard assertion set per cell with unwrap on/off where nested errors exist. The full matrix lives on the ticket.
- [Decide downstream-422 handling given MULE:UNKNOWN](tickets/014-decide-downstream-422-handling.md) — built-in opt-in passthrough, generalized: new `propagateStatusCode` parameter (default false) uses `errorMessage.attributes.statusCode`/`reasonPhrase` when the error type is unmapped; explicit mappings (incl. custom `MULE:UNKNOWN`) win; precedence nested-resolution → passthrough → normal.
- [Build the payload-shape fixture set](tickets/005-build-payload-shape-fixtures.md) — errorBody.xml/.html added; typed payloads staged at test time via readUrl/inline DW; Java objects inline, repeatable streams skipped-with-reason.
- [Implement flow-based composite suites](tickets/006-implement-composite-flow-suites.md) — six per-construct suites with genuine runtime errors (46 tests green across 9 suites); explore suite dissolved; found+fixed a real bug: toString rendered live Java-bean payloads as ClassName@hash, now writes JSON first. Validation Any skipped-with-reason.

## Not yet specified

- **Docs updates** — `exchange-docs/` (How to, Troubleshooting) may need updating to describe composite behavior and the new test matrix; depends on the unwrapping decision.
- **Runtime/version quirks** — remaining unknowns after ticket 009: whether a *connector* failure (vs raise-error) inside a VM consumer flow populates `suppressedErrors`, and other runtime-vs-fixture divergences that may surface while implementing flow-based suites.
- **Fixture capture tooling** — if hand-crafting XML/Java-object fixtures proves unfaithful, a small capture app or script may be worth a ticket.

## Out of scope

- **MUnit coverage gate** — decided against wiring coverage thresholds into the pom for this effort; can be revisited once the suite stabilizes.
- **Upstream contribution** — getting these changes into `mulesoft-catalyst/error-handler-plugin` is a separate effort; this map ends at this repo's master.
