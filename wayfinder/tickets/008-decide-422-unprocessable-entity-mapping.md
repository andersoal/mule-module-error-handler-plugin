---
id: 008
title: "Decide 422 Unprocessable Entity coverage"
label: wayfinder:grilling
status: closed
assignee: anderson.guarnier
blocked-by: []
---

## Resolution (2026-07-19)

422 is handled for **both sources**:

1. **App-raised 422**: add a `"*:UNPROCESSABLE_ENTITY"` wildcard entry to `defaultErrors.dwl` (uses the existing `*:identifier` machinery in `getError`), so any app raising e.g. `APP:UNPROCESSABLE_ENTITY` via raise-error gets 422. Purely additive — no existing type resolves to that identifier today.
2. **Downstream 422 replies**: map whatever error type the HTTP requester actually surfaces for a 422 response on the pinned runtime — that type is a fact to verify, not guess (suspected an unmapped/unknown HTTP error). Graduated to ticket 011; the mapping entry follows the verified type.
3. **Message**: fixed static message — `reason: "Unprocessable Entity"`, `message: "The request was well-formed but could not be processed."` No new message variable; consumers who want different text override via `customErrors`.

Implementation graduated to ticket 012 (blocked by the verification). Test cells land in the matrix (ticket 004).

## Question

How should HTTP 422 (Unprocessable Entity) be represented and tested? `defaultErrors.dwl` currently has no 422 mapping.

Sub-decisions:

- Which error type(s) should map to 422 by default — a semantic-validation error type (e.g. a custom namespace like `APP:UNPROCESSABLE`), an existing standard type, or none (422 only reachable via the `customErrors` parameter)? Note: neither the HTTP connector nor APIKIT raises a dedicated 422 error type out of the box — verify what type a downstream 422 response actually surfaces as before choosing.
- Does adding a 422 entry to `defaultErrors.dwl` risk changing behavior for existing plugin consumers, or is it purely additive?
- Which message variable does it use (a new `vars.unprocessableEntityError` default, following the existing pattern)?

Resolution feeds the test matrix (ticket 004): 422 cells for both standard and composite-wrapped cases, asserting httpStatus/code/reason/message.
