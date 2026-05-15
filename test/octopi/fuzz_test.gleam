import gleam/list
import gleeunit/should
import octopi/fuzz
import octopi/harness
import octopi/harnesses/mirror
import octopi/mutators/append

/// Inline harness tester: runs the mirror agent and tags every output with a
/// single passing verdict on the given focus. Models the "agent + scorer
/// collapsed into one harness" shape the orchestrator now expects.
fn passing_tester(focus: String) -> harness.Harness {
  fn(input, trigger) {
    let agent_out = mirror.run(input, trigger)
    harness.Output(
      message: agent_out.message,
      tool_calls: agent_out.tool_calls,
      verdicts: [harness.Verdict(focus: focus, outcome: harness.Pass)],
    )
  }
}

fn failing_tester(focus: String, reason: String) -> harness.Harness {
  fn(input, trigger) {
    let agent_out = mirror.run(input, trigger)
    harness.Output(
      message: agent_out.message,
      tool_calls: agent_out.tool_calls,
      verdicts: [
        harness.Verdict(focus: focus, outcome: harness.Fail(reason: reason)),
      ],
    )
  }
}

// ==== run ====
// * ✅ applies the mutator to every corpus input
// * ✅ reports zero failures when harness verdicts all pass
// * ✅ flags every case as a failure when harness reports Fail verdicts
// * ✅ preserves seed and mutated input alongside results
pub fn run_with_passing_tester_test() {
  let report =
    fuzz.run(
      corpus: [harness.Input(prompt: "a"), harness.Input(prompt: "b")],
      mutator: append.with("!"),
      harness: passing_tester("smoke"),
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

pub fn run_with_failing_tester_test() {
  let report =
    fuzz.run(
      corpus: [
        harness.Input(prompt: "x"),
        harness.Input(prompt: "y"),
        harness.Input(prompt: "z"),
      ],
      mutator: append.with(""),
      harness: failing_tester("tone", "too curt"),
      trigger: harness.Manual,
      timeout_ms: 1000,
    )

  list.length(report.cases) |> should.equal(3)
  list.length(report.failures) |> should.equal(3)
}
