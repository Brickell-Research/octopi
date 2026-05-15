import gleam/list
import gleeunit/should
import octopi/compose
import octopi/harness
import octopi/harnesses/mirror

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

fn multi_verdict_scorer() -> harness.Harness {
  fn(_input, _trigger) {
    harness.Output(message: "multi", tool_calls: [], verdicts: [
      harness.Verdict(focus: "tone", outcome: harness.Pass),
      harness.Verdict(
        focus: "factuality",
        outcome: harness.Fail(reason: "made it up"),
      ),
      harness.Verdict(focus: "schema", outcome: harness.Pass),
    ])
  }
}

// Echo scorer-input builder — these toy scorers ignore content.
fn echo_scorer_input(
  _input: harness.Input,
  _output: harness.Output,
) -> harness.Input {
  harness.Input(prompt: "judge this")
}

// ==== compose ====
// * ✅ keeps agent's message and tool_calls
// * ✅ appends a single Pass verdict from the scorer
// * ✅ appends a Fail verdict from the scorer
// * ✅ surfaces every verdict when the scorer reports many
pub fn compose_keeps_agent_message_and_appends_pass_test() {
  let tester =
    compose.compose(
      agent: mirror.run,
      scorer: always_pass_scorer("smoke"),
      scorer_input: echo_scorer_input,
    )

  let out = tester(harness.Input(prompt: "ping"), harness.Manual)

  out.message |> should.equal("ping")
  out.tool_calls |> should.equal([])
  out.verdicts
  |> should.equal([
    harness.Verdict(focus: "smoke", outcome: harness.Pass),
  ])
}

pub fn compose_appends_fail_verdict_test() {
  let tester =
    compose.compose(
      agent: mirror.run,
      scorer: always_fail_scorer("tone", "too curt"),
      scorer_input: echo_scorer_input,
    )

  let out = tester(harness.Input(prompt: "hello"), harness.Manual)

  out.message |> should.equal("hello")
  out.verdicts
  |> should.equal([
    harness.Verdict(focus: "tone", outcome: harness.Fail(reason: "too curt")),
  ])
}

pub fn compose_surfaces_multiple_verdicts_test() {
  let tester =
    compose.compose(
      agent: mirror.run,
      scorer: multi_verdict_scorer(),
      scorer_input: echo_scorer_input,
    )

  let out = tester(harness.Input(prompt: "x"), harness.Manual)

  list.length(out.verdicts) |> should.equal(3)
}
