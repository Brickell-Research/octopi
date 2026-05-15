import gleam/int
import gleam/list
import gleam/string
import octopi/fuzz.{type IterativeReport, type Strategist}
import octopi/harness.{type Input}
import octopi/llm/anthropic
import octopi/runner

/// Builds a Strategist that asks Claude for the next batch of inputs to try
/// against a harness tester. Black-box: the LLM only sees prior inputs and
/// their verdicts; it does not know what rules the tester evaluates.
///
/// On any Anthropic failure (transport, API, decode) the returned strategist
/// emits an empty batch — that round produces zero cases and the loop moves
/// on. We accept the lossiness for simplicity; future revisions can surface
/// failures explicitly.
pub fn build(
  api_key api_key: String,
  model model: String,
  max_tokens max_tokens: Int,
  batch_size batch_size: Int,
) -> Strategist {
  fn(history: IterativeReport) -> List(Input) {
    let messages = [
      anthropic.Message(
        role: anthropic.System,
        content: system_prompt(batch_size),
      ),
      anthropic.Message(
        role: anthropic.User,
        content: build_prompt(history, batch_size),
      ),
    ]

    case
      anthropic.complete(
        api_key: api_key,
        model: model,
        messages: messages,
        max_tokens: max_tokens,
      )
    {
      Ok(c) -> parse_inputs(c.text)
      Error(_) -> []
    }
  }
}

@internal
pub fn system_prompt(batch_size: Int) -> String {
  "You are a fuzz-testing strategist trying to break a harness tester. Each round you propose inputs you believe will trigger Fail verdicts. Be creative; try edge cases (length extremes, unusual characters, suspicious substrings, empty input, etc.).\n\nOutput exactly "
  <> int.to_string(batch_size)
  <> " inputs, one per line. No numbering, no preamble, no markup, no quotes. Each line is one complete prompt."
}

/// Renders the user prompt for the strategist call. Includes a summary of
/// every prior case (input + verdicts) plus an explicit ask for the next
/// batch.
@internal
pub fn build_prompt(history: IterativeReport, batch_size: Int) -> String {
  let history_section = case history.rounds {
    [] -> "No prior attempts."
    _ -> {
      let cases = list.flat_map(history.rounds, fn(r) { r.cases })
      "Previous attempts:\n"
      <> list.map(cases, format_case) |> string.join("\n")
    }
  }

  history_section
  <> "\n\nGenerate "
  <> int.to_string(batch_size)
  <> " new inputs likely to trigger Fail verdicts."
}

fn format_case(c: fuzz.FuzzCase) -> String {
  let verdicts_summary = case c.result {
    runner.Completed(output) ->
      case output.verdicts {
        [] -> "no verdicts"
        vs -> list.map(vs, format_verdict) |> string.join(", ")
      }
    runner.TimedOut -> "TIMED OUT"
    runner.Crashed(reason) -> "CRASHED: " <> reason
  }
  "  - " <> string.inspect(c.mutated.prompt) <> " → " <> verdicts_summary
}

fn format_verdict(v: harness.Verdict) -> String {
  case v.outcome {
    harness.Pass -> v.focus <> "=PASS"
    harness.Fail(reason) -> v.focus <> "=FAIL(" <> reason <> ")"
  }
}

/// Splits the LLM reply into one Input per non-empty line, trimming
/// whitespace.
@internal
pub fn parse_inputs(text: String) -> List(Input) {
  text
  |> string.split("\n")
  |> list.map(string.trim)
  |> list.filter(fn(s) { s != "" })
  |> list.map(fn(s) { harness.Input(prompt: s) })
}
