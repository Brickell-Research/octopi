import envoy
import gleam/int
import gleam/io
import gleam/list
import gleam/string
import octopi/fuzz
import octopi/harness
import octopi/harnesses/mirror
import octopi/harnesses/synthetic
import octopi/runner
import octopi/strategists/llm

pub fn main() -> Nil {
  smoke_runner()

  io.println("")
  io.println("== iterative fuzz: LLM strategist vs synthetic tester ==")
  case envoy.get("ANTHROPIC_API_KEY") {
    Error(Nil) -> io.println("  skipped: ANTHROPIC_API_KEY not set")
    Ok(api_key) -> iterative_fuzz_demo(api_key)
  }
}

fn smoke_runner() -> Nil {
  io.println("== runner smoke: mirror harness, 3 inputs ==")
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
  |> list.each(fn(r) { io.println("  " <> string.inspect(r)) })
}

fn iterative_fuzz_demo(api_key: String) -> Nil {
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
    Ok(strategist) -> run_strategist_loop(strategist, tester)
  }
}

fn run_strategist_loop(
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
      iterations: 4,
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
