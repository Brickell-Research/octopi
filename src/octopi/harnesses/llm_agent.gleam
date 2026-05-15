import gleam/option.{type Option, None, Some}
import gleam/string
import octopi/harness.{type Harness, type Input, type Output, type Trigger}
import octopi/llm/anthropic

/// Builds a Harness backed by the Anthropic Messages API. Each Input.prompt
/// becomes the user message, optionally prepended with a fixed system prompt.
///
/// On success the Output's `message` is the assistant text and `tool_calls`
/// / `verdicts` are empty — agents don't self-judge.
///
/// On a transport / API / decode failure the Output's `message` embeds the
/// inspected error so it is visible to downstream scorers and the fuzz
/// report. The harness does not panic, so the runner records the call as
/// Completed (with an error-shaped message) rather than Crashed.
pub fn build(
  api_key api_key: String,
  model model: String,
  max_tokens max_tokens: Int,
  system system: Option(String),
) -> Harness {
  fn(input: Input, _trigger: Trigger) -> Output {
    let messages = build_messages(system, input.prompt)
    case
      anthropic.complete(
        api_key: api_key,
        model: model,
        messages: messages,
        max_tokens: max_tokens,
      )
    {
      Ok(c) -> harness.Output(message: c.text, tool_calls: [], verdicts: [])
      Error(e) ->
        harness.Output(
          message: "[anthropic error] " <> string.inspect(e),
          tool_calls: [],
          verdicts: [],
        )
    }
  }
}

/// Composes the messages list sent to Anthropic from an optional system
/// prompt and the user's prompt.
@internal
pub fn build_messages(
  system: Option(String),
  prompt: String,
) -> List(anthropic.Message) {
  case system {
    Some(s) -> [
      anthropic.Message(role: anthropic.System, content: s),
      anthropic.Message(role: anthropic.User, content: prompt),
    ]
    None -> [anthropic.Message(role: anthropic.User, content: prompt)]
  }
}
