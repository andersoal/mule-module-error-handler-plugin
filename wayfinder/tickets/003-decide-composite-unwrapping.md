---
id: 003
title: "Decide composite unwrapping behavior"
label: wayfinder:grilling
status: closed
assignee: anderson.guarnier
blocked-by: [002]
---

## Resolution (2026-07-19)

Unwrapping is IN, behind an opt-in flag. The rules:

1. **Opt-in parameter**: `resolveNestedErrors` on `process-error`, **default `false`** — existing consumers see zero behavior change.
2. **Trigger (tiered)**: with the flag on, attempt unwrap when (a) the top-level error type is in the known composite/wrapper list — `MULE:COMPOSITE_ROUTING`, `MULE:RETRY_EXHAUSTED`, `VM:PUBLISH_CONSUMER_FLOW_ERROR`, `VALIDATION:MULTIPLE` — or (b) the type is not in the list but would resolve to `UNKNOWN` *and* nested errors (`childErrors`/`suppressedErrors`) are present (catch-all for uncataloged wrapper types).
3. **Depth**: recurse `childErrors`/`suppressedErrors` trees to the **leaf standard errors**, skipping intermediate composite types, deduplicating (each leaf appears 3–4× per the anatomy research).
4. **Mixed leaves**: resolve each deduped leaf's mapping against the merged default+custom error list; **numeric max of status codes wins** (503 beats 404; ties → first occurrence's mapping supplies reason/message).
5. **Precedence**: when the flag is on, **unwrapping wins** over an explicit `customErrors` entry for the composite type itself; that entry (and the composite's default mapping, then `UNKNOWN`) is the **fallback** when unwrapping finds no resolvable leaf. Custom entries for *inner* types always participate in leaf resolution.

### Vocabulary (ubiquitous language)

- **Nested errors** — the union of the two channels: `childErrors` (Scatter-Gather, Parallel For-Each, Validation All) and `suppressedErrors` (Until-Successful, VM publish-consume).
- **Leaf standard error** — a nested error that is not itself composite; the unit whose mapping gets resolved.
- **Severity** — the resolved mapping's numeric HTTP status code; "highest severity" = numeric max.

## Question

Should `process-error` resolve the **nested standard error's** mapping when the top-level error is composite — e.g. a Scatter-Gather wrapping only an `HTTP:NOT_FOUND` returns 404 instead of the current UNKNOWN/500 — and if so, under what rules?

Sub-decisions to grill through (informed by ticket 002's anatomy findings):

- Unwrap at all, or keep current behavior (composite → its own mapping or UNKNOWN, inner errors surface only via `previousError` text)?
- If unwrapping: what wins when multiple child errors have *different* types/statuses (first? highest severity? fall back to composite mapping)?
- Precedence vs `customErrors`: does a custom `MULE:COMPOSITE_ROUTING` entry beat the unwrapped inner mapping?
- Depth: unwrap one level or recurse through nested composites?
- Backward compatibility: is a behavior change acceptable for existing consumers, or does it need an opt-in parameter?

Resolution defines the expected values the test matrix (ticket 004) asserts.
