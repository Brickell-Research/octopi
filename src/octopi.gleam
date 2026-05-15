import envoy
import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/list
import gleam/string
import octopi/harness
import octopi/harnesses/mirror
import octopi/llm/anthropic
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
    harness.Output(
      message: "would have been a result",
      tool_calls: [],
      verdicts: [],
    )
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

  io.println("")
  io.println("== anthropic live call ==")
  case envoy.get("ANTHROPIC_API_KEY") {
    Error(Nil) -> io.println("  skipped: ANTHROPIC_API_KEY not set")
    Ok(api_key) -> demo_anthropic(api_key)
  }
}

fn demo_anthropic(api_key: String) -> Nil {
  let result =
    anthropic.complete(
      api_key: api_key,
      model: "claude-sonnet-4-6",
      messages: [
        anthropic.Message(
          role: anthropic.System,
          content: "Reply in exactly one sentence.",
        ),
        anthropic.Message(
          role: anthropic.User,
          content: "What is octopus camouflage?",
        ),
      ],
      max_tokens: 256,
    )

  case result {
    Ok(c) -> {
      io.println("  text: " <> c.text)
      io.println(
        "  tokens: in="
        <> int.to_string(c.input_tokens)
        <> " out="
        <> int.to_string(c.output_tokens),
      )
      io.println("  stop_reason: " <> c.stop_reason)
    }
    Error(e) -> io.println("  error: " <> string.inspect(e))
  }
}
