---
id: 014
title: "Decide downstream-422 handling given MULE:UNKNOWN"
label: wayfinder:grilling
status: open
assignee:
blocked-by: []
---

## Question

Ticket 011 proved a downstream 422 reply surfaces as `MULE:UNKNOWN` — so ticket 008's "map the surfaced type" plan can't work for the downstream case (a `MULE:UNKNOWN` entry would remap every unknown error to 422). How should the plugin propagate a downstream 422, if at all?

Options to grill through:

- **Status-code passthrough logic**: when the resolved error is UNKNOWN and `error.errorMessage.attributes.statusCode` is present, use that status (and reason phrase) instead of 500 — possibly behind its own opt-in, and possibly generalized to any unmapped downstream status, not just 422.
- **Consumer's job**: document that downstream 422s need the consumer to configure the requester's response validator or pass `customErrors`; the plugin only ships the `*:UNPROCESSABLE_ENTITY` wildcard (ticket 012).
- **Do nothing beyond the wildcard** and record the limitation.

The fixture `Http422UnprocessableError.json` and the 422 cells in the matrix (ticket 004) follow this decision.
