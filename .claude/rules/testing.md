---
paths:
  - "Packages/**/Tests/**"
  - "LaunchUITests/**"
---

## Framework and Structure

- Swift Testing only (`@Test`, `#expect`, `#require`, `@Suite`); XCTest is reserved for the
  XCUITest launch target in `LaunchUITests/`
- Use `@Test(arguments:)` for input/output variations; don't copy-paste test bodies
- Group related tests in a `@Suite`; annotate `@MainActor` suites that touch view models
- TDD is required: write the failing test first, then implement to green

## What to Test

- Test *behavior and contracts*, not implementation details
- Always test the happy path AND the error path for every public API
- Error-path tests assert the thrown error's payload with `#expect(throws:)`, not just its type

## Edge Cases (always consider these)

- **Boundary values**: values at, just inside, and just outside every bound
- **Repeated operations**: idempotence at bounds (clamp twice, reset twice)
- **State transitions**: initial state, after one operation, after error recovery
- **Both branches** of every conditional in Core (the coverage floor will notice if you don't)

## Hygiene

- Tests are independent: no shared mutable state, no ordering assumptions
- No `sleep`/timing-based assertions in unit tests; that flakiness belongs to no one
- NEVER weaken an assertion to make a test pass — fix the code
