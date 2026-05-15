import gleam/list
import gleeunit/should
import octopi/fuzz
import octopi/harness
import octopi/harnesses/mirror
import octopi/mutators/append

fn always_pass_scorer(focus: String) -> harness.Harness {
  fn(_input, _trigger) {
    harness.Output(message: "judged", tool_calls: [], verdicts: [
      harness.Verdict(focus: focus, outcome: harness.Pass),
    ])
  }
}

fn always_fail_scorer(focus: String, reason: String) -> harness.Harness {
  fn(_input, _trigger) {
    harness.Output(message: "judged", tool_calls: [], verdicts: [
      harness.Verdict(focus: focus, outcome: harness.Fail(reason: reason)),
    ])
  }
}

// Toy scorer-input builder. Real scorers would format the original prompt
// and the agent output into a judge prompt; for tests the scorer ignores
// content so we just hand it a placeholder.
fn echo_scorer_input(
  _input: harness.Input,
  _output: harness.Output,
) -> harness.Input {
  harness.Input(prompt: "judge this")
}

// ==== run ====
// * ✅ applies the mutator to every corpus input
// * ✅ reports zero failures when scorer always passes
// * ✅ flags every case as a failure when scorer always fails
// * ✅ preserves seed and mutated input alongside results
pub fn run_with_passing_scorer_test() {
  let report =
    fuzz.run(
      corpus: [harness.Input(prompt: "a"), harness.Input(prompt: "b")],
      mutator: append.with("!"),
      agent: mirror.run,
      scorer: always_pass_scorer("smoke"),
      scorer_input: echo_scorer_input,
      trigger: harness.Manual,
      timeout_ms: 1000,
    )

  list.length(report.cases) |> should.equal(2)
  list.length(report.failures) |> should.equal(0)

  list.map(report.cases, fn(c) { c.seed.prompt })
  |> should.equal(["a", "b"])
  list.map(report.cases, fn(c) { c.mutated.prompt })
  |> should.equal(["a!", "b!"])
}

pub fn run_with_failing_scorer_test() {
  let report =
    fuzz.run(
      corpus: [
        harness.Input(prompt: "x"),
        harness.Input(prompt: "y"),
        harness.Input(prompt: "z"),
      ],
      mutator: append.with(""),
      agent: mirror.run,
      scorer: always_fail_scorer("tone", "too curt"),
      scorer_input: echo_scorer_input,
      trigger: harness.Manual,
      timeout_ms: 1000,
    )

  list.length(report.cases) |> should.equal(3)
  list.length(report.failures) |> should.equal(3)
}
