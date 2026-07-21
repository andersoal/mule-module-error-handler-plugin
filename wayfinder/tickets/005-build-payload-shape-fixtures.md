---
id: 005
title: "Build the payload-shape fixture set"
label: wayfinder:task
status: closed
assignee: anderson.guarnier
blocked-by: [004]
---

## Resolution (2026-07-19)

Fixture strategy per the matrix (ticket 004): typed payloads are to be staged at test time by ticket 007 (`readUrl` with the right MIME type, or inline DW) so they are genuinely typed rather than JSON-flattened — the fixtures below are ready but unreferenced until 007's tests land. Added to `src/test/resources/examples/`:

- `errorBody.xml` — XML error document (parsed as `application/xml` at test time)
- `errorBody.html` — HTML error page (nginx-style 502)
- (Earlier sessions: `VmPublishConsumeError.json`, `Http422UnprocessableError.json` — captured serialized errors)

Not faked, by design: **Java-object payloads** are produced inline (`output application/java`); **repeatable streams** cannot be staged deterministically without a connector round-trip — the Binary cell covers the unreadable-content path, recorded as skipped-with-reason for the matrix. Null/empty shapes need no fixture (inline objects).

## Question

Create the serialized-error fixtures the matrix (ticket 004) calls for that don't exist yet in `src/test/resources/examples/` — XML error bodies, Java exception objects, repeatable-stream payloads, null/empty/missing `errorMessage`, HTML pages — either captured from a scratch Mule app or hand-crafted to match the anatomy documented in ticket 002.

Resolution records which fixtures were added, how each was produced (captured vs crafted), and any shapes that proved impossible to fake faithfully (those cells move to real-flow tests or get flagged on the map).
