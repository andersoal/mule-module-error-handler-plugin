---
id: 010
title: "Implement resolveNestedErrors in the module"
label: wayfinder:task
status: open
assignee:
blocked-by: [009]
---

## Question

Implement the unwrapping behavior decided in ticket 003 (`resolveNestedErrors` parameter, default false; tiered trigger; recursion to deduped leaf standard errors across `childErrors`/`suppressedErrors`; numeric-max severity; unwrap-wins precedence with composite mapping as fallback) in the module: new operation parameter in `src/main/resources/module-error-handler-plugin.xml`, unwrapping functions in `common.dwl`, and any schema/doc updates (`output-*-schema.json`, exchange-docs).

Blocked by ticket 009 because the `suppressedErrors` runtime shape (Until-Successful and VM publish-consume) must be verified before the leaf-walker is written against it.

Resolution: implementation merged, guarded by unit tests at the DataWeave-function level (`common-functions-test-suite.xml`); full scenario coverage lands via tickets 006/007.
