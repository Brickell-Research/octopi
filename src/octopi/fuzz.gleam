import gleam/list
import gleam/option.{type Option, None, Some}
import octopi/harness.{type Harness, type Input, type Output, type Trigger}
import octopi/mutator.{type Mutator}
import octopi/runner.{type RunResult}

/// A single fuzz attempt: one seed → mutated input → agent run → optional
/// scorer run. `scorer_result` is `None` when the agent did not complete
/// (we skip scoring runs that have no output to score).
pub type FuzzCase {
  FuzzCase(
    seed: Input,
    mutated: Input,
    agent_result: RunResult,
    scorer_result: Option(RunResult),
  )
}

/// Outcome of a fuzz pass: every case that ran and a curated subset
/// considered failures.
pub type FuzzReport {
  FuzzReport(cases: List(FuzzCase), failures: List(FuzzCase))
}

/// Single-pass fuzz: mutate every corpus input once, run all through the
/// agent in parallel via the runner, build scorer inputs from each completed
/// agent run, run all through the scorer in parallel, and report which cases
/// failed.
///
/// A case is a failure if any of: the agent did not complete, the scorer did
/// not complete, or the scorer's `Output` contains at least one `Fail`
/// verdict.
pub fn run(
  corpus corpus: List(Input),
  mutator mutate: Mutator,
  agent agent: Harness,
  scorer scorer: Harness,
  scorer_input build_scorer_input: fn(Input, Output) -> Input,
  trigger trigger: Trigger,
  timeout_ms timeout_ms: Int,
) -> FuzzReport {
  let mutated = list.map(corpus, mutate)

  let agent_results =
    runner.run_all(
      harness: agent,
      inputs: mutated,
      trigger: trigger,
      timeout_ms: timeout_ms,
    )

  let scorer_inputs_per_case =
    list.map2(mutated, agent_results, fn(m, ar) {
      case ar {
        runner.Completed(output) -> Some(build_scorer_input(m, output))
        _ -> None
      }
    })

  let scorer_inputs_batch =
    list.filter_map(scorer_inputs_per_case, fn(o) { option.to_result(o, Nil) })

  let scorer_results_batch =
    runner.run_all(
      harness: scorer,
      inputs: scorer_inputs_batch,
      trigger: trigger,
      timeout_ms: timeout_ms,
    )

  let cases =
    stitch(
      corpus,
      mutated,
      agent_results,
      scorer_inputs_per_case,
      scorer_results_batch,
    )
  let failures = list.filter(cases, is_failure)
  FuzzReport(cases: cases, failures: failures)
}

fn stitch(
  corpus: List(Input),
  mutated: List(Input),
  agent_results: List(RunResult),
  scorer_inputs_per_case: List(Option(Input)),
  scorer_results_batch: List(RunResult),
) -> List(FuzzCase) {
  let triples = list.zip(list.zip(corpus, mutated), agent_results)
  let pairs = list.zip(triples, scorer_inputs_per_case)

  let #(_, cases_rev) =
    list.fold(pairs, #(scorer_results_batch, []), fn(state, item) {
      let #(remaining, acc) = state
      let #(triple, maybe_scorer_input) = item
      let #(#(seed, mutated_input), agent_result) = triple
      let #(scorer_result, new_remaining) = case maybe_scorer_input {
        Some(_) ->
          case remaining {
            [r, ..rest] -> #(Some(r), rest)
            [] -> #(None, [])
          }
        None -> #(None, remaining)
      }
      let fuzz_case =
        FuzzCase(
          seed: seed,
          mutated: mutated_input,
          agent_result: agent_result,
          scorer_result: scorer_result,
        )
      #(new_remaining, [fuzz_case, ..acc])
    })

  list.reverse(cases_rev)
}

fn is_failure(c: FuzzCase) -> Bool {
  case c.agent_result, c.scorer_result {
    runner.Completed(_), Some(runner.Completed(scorer_output)) ->
      list.any(scorer_output.verdicts, fn(v) {
        case v.outcome {
          harness.Fail(_) -> True
          harness.Pass -> False
        }
      })
    _, _ -> True
  }
}
