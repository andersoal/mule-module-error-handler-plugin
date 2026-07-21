---
id: 013
title: "Make the Maven MUnit run repeatable"
label: wayfinder:task
status: closed
assignee: anderson.guarnier
blocked-by: []
---

## Resolution (2026-07-19)

`mvn clean verify` now runs all MUnit suites out of the box on the raw pom (verified: BUILD SUCCESS, 21 tests green). Changes:

- pom groupId fixed to `ORG_ID_TOKEN` (was `ORD_ID_TOKEN`), matching `build.sh`'s substitution.
- `exchange-mule-maven-plugin` moved into a `release` Maven profile, so Exchange pre-deploy validation no longer blocks local/CI test builds; `build.sh` passes `-Prelease` on deploy.
- README documents the test command.

## Question

Give the repo a one-command MUnit run (local + CI-ready). Ticket 009 proved `mvn clean verify` works only with a scratch pom because:

- the pom's groupId placeholder is `ORD_ID_TOKEN` while `build.sh` substitutes `ORG_ID_TOKEN` (mismatch — one of them is a typo), and
- `exchange-mule-maven-plugin:exchange-pre-deploy` runs at validate and fails any build whose groupId isn't a real Anypoint org id.

Fix the token mismatch, and make the exchange plugin skippable for test runs (profile, skip property, or moving the validate execution), so `mvn clean verify` (or a documented `build.sh test`) runs all MUnit suites out of the box. Document the command in the README.

Resolution records the chosen mechanism and the exact command.
