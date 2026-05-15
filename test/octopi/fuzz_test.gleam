import gleam/int
import gleam/list
import gleeunit/should
import octopi/fuzz
import octopi/harness
import octopi/harnesses/mirror

/// Inline harness tester: runs the mirror agent and tags every output with a
/// single passing verdict on the given focus.
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
// * ✅ runs every input through the harness tester
// * ✅ reports zero failures when harness verdicts all pass
// * ✅ flags every case as a failure when harness reports Fail verdicts
// * ✅ preserves input alongside results
pub fn run_with_passing_tester_test() {
  let report =
    fuzz.run(
      inputs: [harness.Input(prompt: "a"), harness.Input(prompt: "b")],
      harness: passing_tester("smoke"),
      trigger: harness.Manual,
      timeout_ms: 1000,
    )

  list.length(report.cases) |> should.equal(2)
  list.length(report.failures) |> should.equal(0)

  list.map(report.cases, fn(c) { c.input.prompt })
  |> should.equal(["a", "b"])
}

pub fn run_with_failing_tester_test() {
  let report =
    fuzz.run(
      inputs: [
        harness.Input(prompt: "x"),
        harness.Input(prompt: "y"),
        harness.Input(prompt: "z"),
      ],
      harness: failing_tester("tone", "too curt"),
      trigger: harness.Manual,
      timeout_ms: 1000,
    )

  list.length(report.cases) |> should.equal(3)
  list.length(report.failures) |> should.equal(3)
}

// Strategist that always returns the same fixed batch, ignoring history.
fn fixed_strategist(inputs: List(harness.Input)) -> fuzz.Strategist {
  fn(_history) { inputs }
}

// ==== run_iterative ====
// * ✅ runs strategist `iterations` times and accumulates rounds in order
// * ✅ each round's report has the strategist's inputs as cases
// * ✅ iterations <= 0 returns an empty IterativeReport
// * ✅ strategist sees the prior history and can react to it
pub fn run_iterative_basic_test() {
  let report =
    fuzz.run_iterative(
      strategist: fixed_strategist([
        harness.Input(prompt: "alpha"),
        harness.Input(prompt: "beta"),
      ]),
      harness: passing_tester("smoke"),
      trigger: harness.Manual,
      timeout_ms: 1000,
      iterations: 3,
    )

  list.length(report.rounds) |> should.equal(3)
  list.each(report.rounds, fn(r) {
    list.length(r.cases) |> should.equal(2)
    list.length(r.failures) |> should.equal(0)
  })
}

pub fn run_iterative_zero_iterations_test() {
  let report =
    fuzz.run_iterative(
      strategist: fixed_strategist([harness.Input(prompt: "n/a")]),
      harness: passing_tester("smoke"),
      trigger: harness.Manual,
      timeout_ms: 1000,
      iterations: 0,
    )

  report.rounds |> should.equal([])
}

pub fn run_iterative_strategist_sees_history_test() {
  let strategist = fn(history: fuzz.IterativeReport) -> List(harness.Input) {
    let n = list.length(history.rounds)
    [harness.Input(prompt: "round-" <> int.to_string(n))]
  }

  let report =
    fuzz.run_iterative(
      strategist: strategist,
      harness: passing_tester("smoke"),
      trigger: harness.Manual,
      timeout_ms: 1000,
      iterations: 4,
    )

  let prompts =
    report.rounds
    |> list.flat_map(fn(r) { list.map(r.cases, fn(c) { c.input.prompt }) })

  prompts
  |> should.equal(["round-0", "round-1", "round-2", "round-3"])
}
