---
description: Generate tests for a file or the current branch's changes
argument-hint: <file path, or "diff" for the current branch's changes>
---
Find behavior in the target that lacks coverage (check existing tests first).
Write tests that would catch real regressions: boundary values, error paths,
concurrency where relevant. Match the project's existing test framework and
style exactly (backend: JUnit 5 + Spring Boot Test; frontend: flutter_test).
Run the suite (`make test`) and iterate until green. Report the coverage
delta before/after. Never weaken assertions or delete/skip existing tests
to make things pass.
