import gleam/list
import octopi/harness.{type Harness, type Input, type Trigger}
import octopi/mutator.{type Mutator}
import octopi/runner.{type RunResult}

/// A single fuzz attempt: one seed → mutated input → one run through the
/// harness tester. The harness tester is responsible for invoking the agent
/// and any scorers internally; whatever it produces (message, tool_calls,
/// verdicts) lands in `result`.
pub type FuzzCase {
  FuzzCase(seed: Input, mutated: Input, result: RunResult)
}

/// Outcome of a fuzz pass: every case that ran and a curated subset
/// considered failures.
pub type FuzzReport {
  FuzzReport(cases: List(FuzzCase), failures: List(FuzzCase))
}

/// Single-pass fuzz: mutate every corpus input once and run all mutated
/// inputs through `harness` in parallel via the runner. The harness is
/// expected to be a "harness tester" — it owns whatever scoring logic
/// applies and reports verdicts on its Output.
///
/// A case is a failure if the harness did not complete (TimedOut / Crashed)
/// or the resulting Output contains at least one verdict whose outcome is
/// Fail.
pub fn run(
  corpus corpus: List(Input),
  mutator mutate: Mutator,
  harness tester: Harness,
  trigger trigger: Trigger,
  timeout_ms timeout_ms: Int,
) -> FuzzReport {
  let mutated = list.map(corpus, mutate)

  let results =
    runner.run_all(
      harness: tester,
      inputs: mutated,
      trigger: trigger,
      timeout_ms: timeout_ms,
    )

  let cases =
    list.zip(list.zip(corpus, mutated), results)
    |> list.map(fn(t) {
      let #(#(seed, mutated_input), result) = t
      FuzzCase(seed: seed, mutated: mutated_input, result: result)
    })

  let failures = list.filter(cases, is_failure)
  FuzzReport(cases: cases, failures: failures)
}

fn is_failure(c: FuzzCase) -> Bool {
  case c.result {
    runner.Completed(output) ->
      list.any(output.verdicts, fn(v) {
        case v.outcome {
          harness.Fail(_) -> True
          harness.Pass -> False
        }
      })
    _ -> True
  }
}
