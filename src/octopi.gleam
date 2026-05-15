import envoy
import gleam/erlang/process
import gleam/io
import gleam/list
import gleam/option.{Some}
import gleam/string
import octopi/harness
import octopi/harnesses/llm_agent
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
  io.println("== llm_agent harness via runner, 3 prompts in parallel ==")
  case envoy.get("ANTHROPIC_API_KEY") {
    Error(Nil) -> io.println("  skipped: ANTHROPIC_API_KEY not set")
    Ok(api_key) -> demo_llm_agent(api_key)
  }
}

fn demo_llm_agent(api_key: String) -> Nil {
  let agent =
    llm_agent.build(
      api_key: api_key,
      model: "claude-haiku-4-5-20251001",
      max_tokens: 128,
      system: Some("Reply in exactly one short sentence."),
    )

  let inputs = [
    harness.Input(prompt: "What is octopus camouflage?"),
    harness.Input(prompt: "Why do octopuses have three hearts?"),
    harness.Input(prompt: "What are chromatophores?"),
  ]

  let results =
    runner.run_all(
      harness: agent,
      inputs: inputs,
      trigger: harness.Manual,
      timeout_ms: 30_000,
    )

  list.each(list.zip(inputs, results), fn(pair) {
    let #(input, result) = pair
    io.println("  Q: " <> input.prompt)
    case result {
      runner.Completed(out) -> io.println("  A: " <> out.message)
      runner.TimedOut -> io.println("  A: <timed out>")
      runner.Crashed(reason) -> io.println("  A: <crashed> " <> reason)
    }
    io.println("")
  })
}
