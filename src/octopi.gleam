import envoy
import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{Some}
import gleam/string
import octopi/fuzz
import octopi/harness
import octopi/harnesses/llm_agent
import octopi/harnesses/mirror
import octopi/harnesses/synthetic
import octopi/runner
import octopi/strategists/llm

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

  io.println("")
  io.println("== iterative fuzz: LLM strategist vs synthetic tester ==")
  case envoy.get("ANTHROPIC_API_KEY") {
    Error(Nil) -> io.println("  skipped: ANTHROPIC_API_KEY not set")
    Ok(api_key) -> demo_iterative_fuzz(api_key)
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

fn demo_iterative_fuzz(api_key: String) -> Nil {
  let tester =
    synthetic.build([
      synthetic.MaxLength(focus: "len", limit: 50),
      synthetic.ForbiddenSubstring(focus: "tone", needle: "stupid"),
      synthetic.RequireNonEmpty(focus: "presence"),
    ])

  case
    llm.build(
      api_key: api_key,
      model: "claude-haiku-4-5-20251001",
      max_tokens: 512,
      batch_size: 3,
    )
  {
    Error(e) ->
      io.println("  failed to build strategist: " <> string.inspect(e))
    Ok(strategist) -> run_strategist_demo(strategist, tester)
  }
}

fn run_strategist_demo(
  strategist: fuzz.Strategist,
  tester: harness.Harness,
) -> Nil {
  io.println(
    "  rules: MaxLength(len)=50, ForbiddenSubstring(tone)='stupid', RequireNonEmpty(presence)",
  )
  io.println("")

  let report =
    fuzz.run_iterative(
      strategist: strategist,
      harness: tester,
      trigger: harness.Manual,
      timeout_ms: 30_000,
      iterations: 2,
    )

  list.index_map(report.rounds, fn(round, idx) { print_round(idx, round) })

  let total_cases =
    list.fold(report.rounds, 0, fn(acc, r) { acc + list.length(r.cases) })
  let total_failures =
    list.fold(report.rounds, 0, fn(acc, r) { acc + list.length(r.failures) })
  io.println("")
  io.println(
    "  summary: "
    <> int.to_string(list.length(report.rounds))
    <> " rounds, "
    <> int.to_string(total_cases)
    <> " cases, "
    <> int.to_string(total_failures)
    <> " failures",
  )
}

fn print_round(idx: Int, round: fuzz.FuzzReport) -> Nil {
  io.println("  -- round " <> int.to_string(idx) <> " --")
  list.each(round.cases, fn(c) {
    io.println("    input: " <> string.inspect(c.input.prompt))
    case c.result {
      runner.Completed(out) ->
        list.each(out.verdicts, fn(v) {
          case v.outcome {
            harness.Pass -> io.println("      " <> v.focus <> ": PASS")
            harness.Fail(reason) ->
              io.println("      " <> v.focus <> ": FAIL — " <> reason)
          }
        })
      runner.TimedOut -> io.println("      <timed out>")
      runner.Crashed(reason) -> io.println("      <crashed> " <> reason)
    }
  })
}
