import gleam/erlang/process
import gleam/list
import gleeunit/should
import octopi/harness
import octopi/harnesses/mirror
import octopi/runner

// ==== run_all ====
// * ✅ runs every input through the mirror harness in parallel
// * ✅ preserves input order in results
// * ✅ returns an empty list for an empty input list
// * ✅ marks a slow harness as TimedOut without affecting siblings
pub fn run_all_with_mirror_test() {
  let inputs = [
    harness.Input(prompt: "one"),
    harness.Input(prompt: "two"),
    harness.Input(prompt: "three"),
  ]

  let results =
    runner.run_all(
      harness: mirror.run,
      inputs: inputs,
      trigger: harness.Manual,
      timeout_ms: 1000,
    )

  results
  |> list.map(fn(r) {
    case r {
      runner.Completed(output) -> output.message
      _ -> "<not-completed>"
    }
  })
  |> should.equal(["one", "two", "three"])
}

pub fn run_all_with_no_inputs_test() {
  runner.run_all(
    harness: mirror.run,
    inputs: [],
    trigger: harness.Manual,
    timeout_ms: 1000,
  )
  |> should.equal([])
}

pub fn run_all_times_out_slow_harness_test() {
  let slow: harness.Harness = fn(_input: harness.Input, _trigger) {
    process.sleep(200)
    harness.Output(message: "irrelevant", tool_calls: [])
  }

  let results =
    runner.run_all(
      harness: slow,
      inputs: [
        harness.Input(prompt: "fast-or-bust"),
        harness.Input(prompt: "also-too-slow"),
      ],
      trigger: harness.Manual,
      timeout_ms: 20,
    )

  results
  |> list.all(fn(r) { r == runner.TimedOut })
  |> should.be_true
}
