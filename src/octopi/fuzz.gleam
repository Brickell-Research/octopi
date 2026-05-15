import gleam/list
import octopi/harness.{type Harness, type Input, type Trigger}
import octopi/runner.{type RunResult}

/// A single fuzz attempt: one input run through the harness tester. The
/// harness tester is responsible for invoking any internal agent and
/// scorers; whatever it produces (message, tool_calls, verdicts) lands in
/// `result`.
pub type FuzzCase {
  FuzzCase(input: Input, result: RunResult)
}

/// Outcome of a single fuzz pass: every case that ran and the subset
/// considered failures.
pub type FuzzReport {
  FuzzReport(cases: List(FuzzCase), failures: List(FuzzCase))
}

/// History across an iterative fuzz run, one FuzzReport per round in
/// chronological order.
pub type IterativeReport {
  IterativeReport(rounds: List(FuzzReport))
}

/// A strategist drives an iterative fuzz run by choosing the next batch of
/// inputs given the history so far. Round 0 is invoked with an empty
/// IterativeReport — the strategist is responsible for producing seed
/// inputs in that case.
pub type Strategist =
  fn(IterativeReport) -> List(Input)

/// Single-pass fuzz: run every input through `harness` in parallel via the
/// runner. The harness is expected to be a "harness tester" — it owns
/// whatever scoring logic applies and reports verdicts on its Output.
///
/// A case is a failure if the harness did not complete (TimedOut / Crashed)
/// or the resulting Output contains at least one verdict whose outcome is
/// Fail.
pub fn run(
  inputs inputs: List(Input),
  harness tester: Harness,
  trigger trigger: Trigger,
  timeout_ms timeout_ms: Int,
) -> FuzzReport {
  let results =
    runner.run_all(
      harness: tester,
      inputs: inputs,
      trigger: trigger,
      timeout_ms: timeout_ms,
    )

  let cases =
    list.zip(inputs, results)
    |> list.map(fn(pair) {
      let #(input, result) = pair
      FuzzCase(input: input, result: result)
    })

  let failures = list.filter(cases, is_failure)
  FuzzReport(cases: cases, failures: failures)
}

/// Iterative fuzz: invoke the strategist `iterations` times, each time
/// passing the history of completed rounds. The strategist returns the next
/// batch of inputs, which we run through the harness tester via the runner.
/// Each round's FuzzReport is appended to the history before the next
/// strategist call so feedback loops are observable.
///
/// `iterations <= 0` is a no-op and returns an empty IterativeReport. There
/// is no early-stop on first failure yet — every round runs.
pub fn run_iterative(
  strategist strategist: Strategist,
  harness tester: Harness,
  trigger trigger: Trigger,
  timeout_ms timeout_ms: Int,
  iterations iterations: Int,
) -> IterativeReport {
  list.repeat(Nil, iterations)
  |> list.fold(IterativeReport(rounds: []), fn(history, _) {
    let inputs = strategist(history)
    let round =
      run(
        inputs: inputs,
        harness: tester,
        trigger: trigger,
        timeout_ms: timeout_ms,
      )
    IterativeReport(rounds: list.append(history.rounds, [round]))
  })
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
