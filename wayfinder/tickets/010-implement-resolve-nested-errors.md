---
id: 010
title: "Implement resolveNestedErrors in the module"
label: wayfinder:task
status: closed
assignee: anderson.guarnier
blocked-by: [009]
---

## Resolution (2026-07-19)

Implemented per ticket 003's decision, TDD (red run confirmed, then green: 30 tests):

- `common.dwl`: new `findErrorMapping` (getError's precedence, null instead of UNKNOWN fallback — `getError` now delegates to it), `getNestedErrors` (guarded childErrors ++ suppressedErrors), `getLeafErrors` (recursive walk to leaf standard errors), and `resolveNestedErrorMapping` (tiered trigger: known wrapper list or unmapped-type-with-nested-errors; dedup by leaf type; numeric-max status wins via stable orderBy so ties keep first occurrence; null when nothing resolves).
- `module-error-handler-plugin.xml`: new optional `resolveNestedErrors` boolean parameter (Advanced tab, default false); both transforms resolve `nestedError default getError(...)` — unwrap wins over a custom composite entry, wrapper mapping is the fallback.
- Tests: `resolve-nested-error-mapping-rules` + `find-error-mapping-returns-null-when-unmatched` (DW level, 12 assertions) and 6 operation-level tests (Scatter-Gather leaf → 405, Until-Successful suppressed → 503, mixed leaves → numeric max, unwrap beats custom composite entry, fallback when no leaf resolves, default-off backward compatibility).
- Docs: "Resolve Nested Errors" section in `exchange-docs/home.md`.
- Serialization guards honored (ticket 009's `write()` NPE): all nested-error access goes through `evalOrElse`.

## Question

Implement the unwrapping behavior decided in ticket 003 (`resolveNestedErrors` parameter, default false; tiered trigger; recursion to deduped leaf standard errors across `childErrors`/`suppressedErrors`; numeric-max severity; unwrap-wins precedence with composite mapping as fallback) in the module: new operation parameter in `src/main/resources/module-error-handler-plugin.xml`, unwrapping functions in `common.dwl`, and any schema/doc updates (`output-*-schema.json`, exchange-docs).

Blocked by ticket 009 because the `suppressedErrors` runtime shape (Until-Successful and VM publish-consume) must be verified before the leaf-walker is written against it.

Resolution: implementation merged, guarded by unit tests at the DataWeave-function level (`common-functions-test-suite.xml`); full scenario coverage lands via tickets 006/007.
