import gleam/int
import gleam/list
import gleam/string
import octopi/harness.{type Harness, type Input, type Output, type Trigger}

/// A deterministic check evaluated against an input prompt. Each rule emits
/// one verdict per run — Pass when the rule is satisfied, Fail with a
/// human-readable reason when it isn't.
pub type Rule {
  /// Fail when the prompt is longer than `limit` characters.
  MaxLength(focus: String, limit: Int)
  /// Fail when `needle` appears anywhere in the prompt.
  ForbiddenSubstring(focus: String, needle: String)
  /// Fail when the prompt is the empty string.
  RequireNonEmpty(focus: String)
}

/// Builds a deterministic harness tester that evaluates every rule against
/// each input and emits one verdict per rule. Used as a cheap demo target so
/// strategist behaviour can be observed without paying for real model calls
/// under test.
pub fn build(rules: List(Rule)) -> Harness {
  fn(input: Input, _trigger: Trigger) -> Output {
    let verdicts = list.map(rules, fn(r) { evaluate(r, input.prompt) })
    harness.Output(
      message: "synthetic: " <> input.prompt,
      tool_calls: [],
      verdicts: verdicts,
    )
  }
}

/// Evaluates one rule against one prompt. Exposed for direct testing of the
/// per-rule logic.
@internal
pub fn evaluate(rule: Rule, prompt: String) -> harness.Verdict {
  case rule {
    MaxLength(focus, limit) -> {
      let len = string.length(prompt)
      case len > limit {
        True ->
          harness.Verdict(
            focus: focus,
            outcome: harness.Fail(
              reason: "prompt length "
              <> int.to_string(len)
              <> " exceeds limit "
              <> int.to_string(limit),
            ),
          )
        False -> harness.Verdict(focus: focus, outcome: harness.Pass)
      }
    }
    ForbiddenSubstring(focus, needle) ->
      case string.contains(prompt, needle) {
        True ->
          harness.Verdict(
            focus: focus,
            outcome: harness.Fail(
              reason: "prompt contains forbidden substring: " <> needle,
            ),
          )
        False -> harness.Verdict(focus: focus, outcome: harness.Pass)
      }
    RequireNonEmpty(focus) ->
      case prompt {
        "" ->
          harness.Verdict(
            focus: focus,
            outcome: harness.Fail(reason: "prompt is empty"),
          )
        _ -> harness.Verdict(focus: focus, outcome: harness.Pass)
      }
  }
}
