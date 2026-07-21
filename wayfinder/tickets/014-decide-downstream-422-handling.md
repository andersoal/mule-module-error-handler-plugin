---
id: 014
title: "Decide downstream-422 handling given MULE:UNKNOWN"
label: wayfinder:grilling
status: closed
assignee: anderson.guarnier
blocked-by: []
---

## Resolution (2026-07-19)

**Built-in passthrough, opt-in, generalized** — new optional boolean parameter `propagateStatusCode` (Advanced tab, default `false`):

1. Applies when the error type has **no mapping** (would fall to the UNKNOWN entry) and `error.errorMessage.attributes.statusCode` is readable as a number — covers downstream 422 and any other unmapped status (495, 418, …).
2. The response uses the downstream `statusCode` and `reasonPhrase` (falling back to the UNKNOWN entry's reason when absent); the message keeps the UNKNOWN entry's message semantics (body propagation stays the `previousError` mechanism's job).
3. An explicit mapping — including a custom `MULE:UNKNOWN` entry — wins over passthrough: the consumer's stated intent beats inference.
4. Precedence order in the operation: nested resolution (`resolveNestedErrors`) → status-code passthrough (`propagateStatusCode`) → normal `getError` resolution.

Implemented in this session (same TDD flow as ticket 010).

## Question

Ticket 011 proved a downstream 422 reply surfaces as `MULE:UNKNOWN` — so ticket 008's "map the surfaced type" plan can't work for the downstream case (a `MULE:UNKNOWN` entry would remap every unknown error to 422). How should the plugin propagate a downstream 422, if at all?

Options to grill through:

- **Status-code passthrough logic**: when the resolved error is UNKNOWN and `error.errorMessage.attributes.statusCode` is present, use that status (and reason phrase) instead of 500 — possibly behind its own opt-in, and possibly generalized to any unmapped downstream status, not just 422.
- **Consumer's job**: document that downstream 422s need the consumer to configure the requester's response validator or pass `customErrors`; the plugin only ships the `*:UNPROCESSABLE_ENTITY` wildcard (ticket 012).
- **Do nothing beyond the wildcard** and record the limitation.

The fixture `Http422UnprocessableError.json` and the 422 cells in the matrix (ticket 004) follow this decision.
