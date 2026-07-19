---
id: 006
title: "Implement flow-based composite error suites"
label: wayfinder:task
status: open
assignee:
blocked-by: [004, 009, 010]
---

## Question

Implement the MUnit suites where real flows raise genuine composite errors — Scatter-Gather, Parallel For-Each, Until-Successful, Validation All/Any, nested composites, and Async/VM/Foreach propagation — using the patterns from ticket 001 and asserting the matrix cells from ticket 004 (including whichever unwrapping behavior ticket 003 locked in, plus any module changes that decision spawned).

Resolution: suites merged and green via the munit-extensions-maven-plugin build; note any matrix cells that couldn't be realized as real flows and fell back to fixtures.
