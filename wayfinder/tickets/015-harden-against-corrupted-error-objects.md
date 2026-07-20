---
id: 015
title: "Harden the module against corrupted error objects"
label: wayfinder:task
status: closed
assignee: anderson.guarnier
blocked-by: []
---

## Question

Make `process-error` survive a corrupted, unserializable, or otherwise fatally-inaccessible `error` object and always return a valid response, instead of throwing a fatal that leaves the caller with no reply. Covers IMPROVEMENTS.md §2 (the one consideration from the feature branch not yet treated on this branch), merged with its DataWeave-level guards.

Two layers, one ticket:

- **Guard the direct reads.** The error-type resolution (`getErrorTypeAsString(error.errorType)`) and every `error.description` access (debug logger and the attributes transform) currently propagate if the access misbehaves. Make them degrade gracefully (e.g. via the existing `evalOrElse` guard idiom) so an absent/empty/odd `errorType` or `description` still yields a clean 500.
- **Wrap the body with a catastrophic fallback.** Enclose the operation body in a `<try>` with an `on-error-continue` that emits a guaranteed 500 JSON response (`httpStatus: 500`, a fallback `errorLog`) if any step still throws, and normalize the incoming error into a guaranteed-shaped value the happy path reads.

Constraint: keep reading the verified `error.errorMessage.attributes` path for downstream status (per ticket 011) — do **not** adopt the feature branch's `error.exception.errorMessage.attributes` path, which ticket 011 showed is wrong.

Note on verification: a genuinely DataWeave-fataling error object cannot be manufactured deterministically in MUnit (no way to fake a Java accessor that throws), so verify the guards against null/absent/empty/odd shapes and verify the wrap's fallback by forcing a throw where one can be forced.

**Status:** closed (2026-07-20)

- [x] `error.errorType` and `error.description` access no longer propagate on absent/empty/malformed shapes; a clean 500 is produced.
- [x] Operation body wrapped so any residual throw yields a guaranteed 500 JSON (`httpStatus: 500` + fallback `errorLog`), never a no-response fatal.
- [x] Happy-path behaviour and all existing tests unchanged (backward compatible).
- [x] Downstream status still read from `error.errorMessage.attributes` (not `.exception.`).
- [x] Tests: null / empty-errorType / missing-description cases return 500/404 cleanly *via the normal path* (asserted `errorLog` does not contain `fallback`); the forced-throw case (custom `code` that can't coerce to Number) returns the fallback.
- [x] Behaviour documented in `exchange-docs` (home.md "Fatal-Error Safety" + CHANGELOG).

## Resolution (2026-07-20)

TDD: the forced-throw test (custom error with non-numeric `code` → `code as Number` fatals the attributes transform) failed with `Cannot coerce String (not-a-number) to Number` before the wrap, passed after. Implemented in `module-error-handler-plugin.xml`: body wrapped in `<mule:try>` + `on-error-continue` catastrophic fallback (guaranteed 500, fixed `error` key, `errorLog: "Error Handler Plugin fatal fallback"`); `errorType` and a new `safeDescription` var read through `evalOrElse`. Verified `errorMessage.attributes` path unchanged (not `.exception.`). Two-axis review passed; strengthened the null/empty-errorType tests with a negative `errorLog` assertion so they distinguish the guarded path from the fallback. 64 tests green.
