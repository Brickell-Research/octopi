import gleam/dynamic/decode
import gleam/erlang/application
import gleam/int
import gleam/json
import gleam/list
import gleam/result
import gleam/string
import octopi/fuzz.{type IterativeReport, type Strategist}
import octopi/harness.{type Input}
import octopi/llm/anthropic
import octopi/runner
import simplifile

/// Reasons a strategist could not be constructed. Currently only covers the
/// asset-loading path (system prompt template); more variants will land as
/// build acquires more inputs that can fail at construction time.
pub type LoadError {
  /// The system-prompt template file at priv/strategists/llm_system_prompt.md
  /// is missing or unreadable. Indicates a packaging or deployment bug.
  PromptTemplateUnreadable(reason: String)
}

/// Builds a Strategist that asks Claude for the next batch of inputs to try
/// against a harness tester. Black-box: the LLM only sees prior inputs and
/// their verdicts; it does not know what rules the tester evaluates.
///
/// Loads the system-prompt template from priv/ at construction. On any
/// Anthropic failure during a round (transport, API, decode) the returned
/// strategist emits an empty batch — that round produces zero cases and the
/// loop moves on.
pub fn build(
  api_key api_key: String,
  model model: String,
  max_tokens max_tokens: Int,
  batch_size batch_size: Int,
) -> Result(Strategist, LoadError) {
  use system <- result.try(load_system_prompt(batch_size))

  Ok(fn(history: IterativeReport) -> List(Input) {
    let messages = [
      anthropic.Message(role: anthropic.System, content: system),
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
  })
}

/// Loads the system-prompt template from priv/ and substitutes the
/// `{{batch_size}}` placeholder. Exposed for tests so they can verify the
/// template is loadable and the substitution happens.
@internal
pub fn load_system_prompt(batch_size: Int) -> Result(String, LoadError) {
  use priv <- result.try(
    application.priv_directory("octopi")
    |> result.map_error(fn(_) {
      PromptTemplateUnreadable(reason: "could not locate octopi priv directory")
    }),
  )

  let path = priv <> "/strategists/llm_system_prompt.md"

  use template <- result.try(
    simplifile.read(from: path)
    |> result.map_error(fn(e) {
      PromptTemplateUnreadable(
        reason: "read failed at " <> path <> ": " <> string.inspect(e),
      )
    }),
  )

  Ok(string.replace(template, "{{batch_size}}", int.to_string(batch_size)))
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
  "  - " <> string.inspect(c.input.prompt) <> " → " <> verdicts_summary
}

fn format_verdict(v: harness.Verdict) -> String {
  case v.outcome {
    harness.Pass -> v.focus <> "=PASS"
    harness.Fail(reason) -> v.focus <> "=FAIL(" <> reason <> ")"
  }
}

/// Decodes the LLM reply as a JSON array of strings, one Input per element.
/// Tolerant of common LLM wrappers: leading/trailing whitespace and
/// markdown code fences (```json ... ``` or ``` ... ```). Returns an empty
/// list on any decode failure — the round produces zero cases and the loop
/// continues.
@internal
pub fn parse_inputs(text: String) -> List(Input) {
  let cleaned = strip_code_fence(text)
  case json.parse(cleaned, decode.list(decode.string)) {
    Ok(strings) -> list.map(strings, fn(s) { harness.Input(prompt: s) })
    Error(_) -> []
  }
}

/// Strips a leading ```language? fence and a trailing ``` fence if present,
/// then trims whitespace. Pass-through for inputs without fences.
@internal
pub fn strip_code_fence(text: String) -> String {
  let trimmed = string.trim(text)
  case string.starts_with(trimmed, "```") {
    False -> trimmed
    True -> {
      let after_open = string.drop_start(trimmed, 3)
      let after_lang_tag = case string.split_once(after_open, "\n") {
        Ok(#(_lang, rest)) -> rest
        Error(_) -> after_open
      }
      let final = case string.ends_with(after_lang_tag, "```") {
        True -> string.drop_end(after_lang_tag, 3)
        False -> after_lang_tag
      }
      string.trim(final)
    }
  }
}
