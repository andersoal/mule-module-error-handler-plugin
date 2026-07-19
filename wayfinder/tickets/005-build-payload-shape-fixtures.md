---
id: 005
title: "Build the payload-shape fixture set"
label: wayfinder:task
status: open
assignee:
blocked-by: [004]
---

## Question

Create the serialized-error fixtures the matrix (ticket 004) calls for that don't exist yet in `src/test/resources/examples/` — XML error bodies, Java exception objects, repeatable-stream payloads, null/empty/missing `errorMessage`, HTML pages — either captured from a scratch Mule app or hand-crafted to match the anatomy documented in ticket 002.

Resolution records which fixtures were added, how each was produced (captured vs crafted), and any shapes that proved impossible to fake faithfully (those cells move to real-flow tests or get flagged on the map).
