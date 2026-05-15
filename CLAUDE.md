# CLAUDE.md

Guidance for Claude when working in this repository.

## What this project is

Octopi is an agentic fuzz-testing harness, written in Gleam targeting Erlang/OTP. The high-level intent lives in `idea.md` — read it before making architectural suggestions.

## Style guide

`style.md` is the source of truth for Gleam style in this repo. Follow it. Highlights to keep front of mind:

- Import types unqualified (`{type Foo}`); qualify everything else (functions, constructors, constants).
- Doc comments (`///`) required on all `pub` items.
- Tests mirror `src/` layout one-to-one.
- Each test function has a `// ==== name ====` header and `// * ✅ case` lines.
- Prefer `test_helpers.table_test_N` for any test with more than one case.
- Use `gleeunit/should` assertions (`x |> should.equal(y)`) for single-case checks. Never use raw `assert x == y` — gleeunit everywhere.
- Custom error types over `String`; use `Result`, not exceptions.
- `let assert` only for structural invariants — never as a substitute for real validation.
- Never `panic` / `todo` in production code.

## Commands

| Task | Command |
|------|---------|
| Build | `make build` |
| Run tests | `make test` |
| Format check | `make lint` |
| Format fix | `make lint-fix` |
| Full CI locally | `make ci` |

CI runs `make ci` equivalent on push to `main` and on every PR.

## Layout

```
src/
  octopi.gleam              # entry point
  octopi/
    harness.gleam           # core types: Input, Trigger, Output, ToolCall, Harness
    harnesses/              # concrete harness implementations
    runner.gleam            # parallel harness execution with per-run timeout + crash isolation
    mutator.gleam           # Mutator type: fn(Input) -> Input
    mutators/               # concrete mutator implementations
    fuzz.gleam              # single-pass fuzz loop: corpus → mutate → agent → scorer → report
test/
  test_helpers.gleam        # table_test_N executors
  octopi/                   # mirrors src/octopi/
```

## Workflow

- Ship small. One small PR per increment, not batched branches. Default to creating a feature branch and opening a PR even for changes as small as one new module.
- Don't commit directly to `main` — direct push is blocked anyway.
- Never use `--no-verify`, `--amend` on pushed commits, or force-push to `main`.
