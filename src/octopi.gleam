import gleam/erlang/process
import gleam/io
import gleam/list
import gleam/string
import octopi/harness
import octopi/harnesses/mirror
import octopi/runner

pub fn main() -> Nil {
  io.println("== mirror harness, 3 inputs, fast ==")
  let fast =
    runner.run_all(
      harness: mirror.run,
      inputs: [
        harness.Input(prompt: "ping"),
        harness.Input(prompt: "pong"),
        harness.Input(prompt: "🐙"),
      ],
      trigger: harness.Manual,
      timeout_ms: 1000,
    )
  list.each(fast, fn(r) { io.println("  " <> string.inspect(r)) })

  io.println("")
  io.println("== slow harness vs 20ms timeout ==")
  let slow: harness.Harness = fn(_input: harness.Input, _trigger) {
    process.sleep(200)
    harness.Output(message: "would have been a result", tool_calls: [])
  }
  let timed_out =
    runner.run_all(
      harness: slow,
      inputs: [
        harness.Input(prompt: "a"),
        harness.Input(prompt: "b"),
      ],
      trigger: harness.Manual,
      timeout_ms: 20,
    )
  list.each(timed_out, fn(r) { io.println("  " <> string.inspect(r)) })
}
