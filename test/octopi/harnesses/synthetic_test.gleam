import gleam/list
import gleeunit/should
import octopi/harness
import octopi/harnesses/synthetic

// ==== evaluate ====
// * ✅ MaxLength passes when prompt is at or below the limit
// * ✅ MaxLength fails when prompt exceeds the limit (reason includes counts)
// * ✅ ForbiddenSubstring passes when needle is absent
// * ✅ ForbiddenSubstring fails when needle is present (reason includes needle)
// * ✅ RequireNonEmpty passes for any non-empty prompt
// * ✅ RequireNonEmpty fails for the empty string
pub fn evaluate_max_length_pass_test() {
  synthetic.evaluate(synthetic.MaxLength(focus: "len", limit: 10), "short")
  |> should.equal(harness.Verdict(focus: "len", outcome: harness.Pass))
}

pub fn evaluate_max_length_fail_test() {
  let v =
    synthetic.evaluate(
      synthetic.MaxLength(focus: "len", limit: 3),
      "way too long",
    )
  v.focus |> should.equal("len")
  case v.outcome {
    harness.Fail(reason) -> {
      should.be_true(case reason {
        "prompt length 12 exceeds limit 3" -> True
        _ -> False
      })
    }
    harness.Pass -> panic as "expected Fail outcome"
  }
}

pub fn evaluate_forbidden_substring_pass_test() {
  synthetic.evaluate(
    synthetic.ForbiddenSubstring(focus: "tone", needle: "stupid"),
    "polite request",
  )
  |> should.equal(harness.Verdict(focus: "tone", outcome: harness.Pass))
}

pub fn evaluate_forbidden_substring_fail_test() {
  let v =
    synthetic.evaluate(
      synthetic.ForbiddenSubstring(focus: "tone", needle: "stupid"),
      "this is stupid",
    )
  v
  |> should.equal(harness.Verdict(
    focus: "tone",
    outcome: harness.Fail(reason: "prompt contains forbidden substring: stupid"),
  ))
}

pub fn evaluate_require_non_empty_pass_test() {
  synthetic.evaluate(synthetic.RequireNonEmpty(focus: "presence"), "hi")
  |> should.equal(harness.Verdict(focus: "presence", outcome: harness.Pass))
}

pub fn evaluate_require_non_empty_fail_test() {
  synthetic.evaluate(synthetic.RequireNonEmpty(focus: "presence"), "")
  |> should.equal(harness.Verdict(
    focus: "presence",
    outcome: harness.Fail(reason: "prompt is empty"),
  ))
}

// ==== build ====
// * ✅ produces an Output with one verdict per rule, in rule order
// * ✅ message echoes the input prompt with a "synthetic:" prefix
// * ✅ empty rule list produces no verdicts (case won't fail)
pub fn build_emits_verdict_per_rule_test() {
  let tester =
    synthetic.build([
      synthetic.MaxLength(focus: "len", limit: 100),
      synthetic.RequireNonEmpty(focus: "presence"),
      synthetic.ForbiddenSubstring(focus: "tone", needle: "x"),
    ])

  let out = tester(harness.Input(prompt: "hello"), harness.Manual)

  list.length(out.verdicts) |> should.equal(3)
  out.message |> should.equal("synthetic: hello")
}

pub fn build_with_no_rules_test() {
  let tester = synthetic.build([])
  let out = tester(harness.Input(prompt: "anything"), harness.Manual)

  out.verdicts |> should.equal([])
  out.message |> should.equal("synthetic: anything")
}
