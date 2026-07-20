---
id: 015
title: "Harden the module against corrupted error objects"
label: wayfinder:task
status: open
assignee:
blocked-by: []
---

## Question

Make `process-error` survive a corrupted, unserializable, or otherwise fatally-inaccessible `error` object and always return a valid response, instead of throwing a fatal that leaves the caller with no reply. Covers IMPROVEMENTS.md §2 (the one consideration from the feature branch not yet treated on this branch), merged with its DataWeave-level guards.

Two layers, one ticket:

- **Guard the direct reads.** The error-type resolution (`getErrorTypeAsString(error.errorType)`) and every `error.description` access (debug logger and the attributes transform) currently propagate if the access misbehaves. Make them degrade gracefully (e.g. via the existing `evalOrElse` guard idiom) so an absent/empty/odd `errorType` or `description` still yields a clean 500.
- **Wrap the body with a catastrophic fallback.** Enclose the operation body in a `<try>` with an `on-error-continue` that emits a guaranteed 500 JSON response (`httpStatus: 500`, a fallback `errorLog`) if any step still throws, and normalize the incoming error into a guaranteed-shaped value the happy path reads.

Constraint: keep reading the verified `error.errorMessage.attributes` path for downstream status (per ticket 011) — do **not** adopt the feature branch's `error.exception.errorMessage.attributes` path, which ticket 011 showed is wrong.

Note on verification: a genuinely DataWeave-fataling error object cannot be manufactured deterministically in MUnit (no way to fake a Java accessor that throws), so verify the guards against null/absent/empty/odd shapes and verify the wrap's fallback by forcing a throw where one can be forced.

**Status:** ready-for-agent

- [ ] `error.errorType` and `error.description` access no longer propagate on absent/empty/malformed shapes; a clean 500 is produced.
- [ ] Operation body wrapped so any residual throw yields a guaranteed 500 JSON (`httpStatus: 500` + fallback `errorLog`), never a no-response fatal.
- [ ] Happy-path behaviour and all existing tests unchanged (backward compatible).
- [ ] Downstream status still read from `error.errorMessage.attributes` (not `.exception.`).
- [ ] Tests: null / absent-errorType / missing-description / empty-errorType cases return 500 cleanly; a forced-throw case returns the fallback response.
- [ ] Behaviour documented in `exchange-docs` (home.md + CHANGELOG).
