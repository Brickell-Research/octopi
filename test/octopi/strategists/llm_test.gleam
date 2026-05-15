import gleam/list
import gleam/string
import gleeunit/should
import octopi/fuzz
import octopi/harness
import octopi/runner
import octopi/strategists/llm

// ==== load_system_prompt ====
// * ✅ loads the prompt template from priv/ and substitutes {{batch_size}}
// * ✅ contains the strategy-priority guidance text
pub fn load_system_prompt_substitutes_batch_size_test() {
  let assert Ok(prompt) = llm.load_system_prompt(7)

  string.contains(prompt, "Output exactly 7 inputs") |> should.be_true
  string.contains(prompt, "{{batch_size}}") |> should.be_false
  string.contains(prompt, "fuzz-testing strategist") |> should.be_true
}

// ==== parse_inputs ====
// * ✅ empty string returns no inputs
// * ✅ single line becomes one input
// * ✅ multiple lines become a list, in order
// * ✅ leading and trailing whitespace is trimmed
// * ✅ blank lines are skipped
pub fn parse_inputs_empty_test() {
  llm.parse_inputs("") |> should.equal([])
}

pub fn parse_inputs_single_line_test() {
  llm.parse_inputs("hello world")
  |> should.equal([harness.Input(prompt: "hello world")])
}

pub fn parse_inputs_multi_line_test() {
  llm.parse_inputs("alpha\nbeta\ngamma")
  |> should.equal([
    harness.Input(prompt: "alpha"),
    harness.Input(prompt: "beta"),
    harness.Input(prompt: "gamma"),
  ])
}

pub fn parse_inputs_trims_whitespace_test() {
  llm.parse_inputs("  padded  \n\thelloworld\t\n")
  |> should.equal([
    harness.Input(prompt: "padded"),
    harness.Input(prompt: "helloworld"),
  ])
}

pub fn parse_inputs_skips_blank_lines_test() {
  llm.parse_inputs("a\n\n\nb\n   \nc")
  |> should.equal([
    harness.Input(prompt: "a"),
    harness.Input(prompt: "b"),
    harness.Input(prompt: "c"),
  ])
}

// ==== build_prompt ====
// * ✅ asks for the requested batch_size
// * ✅ "no prior attempts" message when history is empty
// * ✅ includes prior inputs and verdict summaries when history has cases
// * ✅ summarizes Fail verdicts with their reason
pub fn build_prompt_requests_batch_size_test() {
  let prompt = llm.build_prompt(fuzz.IterativeReport(rounds: []), 7)
  string.contains(prompt, "Generate 7 new inputs") |> should.be_true
}

pub fn build_prompt_empty_history_test() {
  let prompt = llm.build_prompt(fuzz.IterativeReport(rounds: []), 3)
  string.contains(prompt, "No prior attempts") |> should.be_true
}

pub fn build_prompt_summarizes_pass_test() {
  let case_ =
    fuzz.FuzzCase(
      input: harness.Input(prompt: "hello"),
      result: runner.Completed(
        harness.Output(message: "synthetic: hello", tool_calls: [], verdicts: [
          harness.Verdict(focus: "tone", outcome: harness.Pass),
        ]),
      ),
    )
  let history =
    fuzz.IterativeReport(rounds: [fuzz.FuzzReport(cases: [case_], failures: [])])

  let prompt = llm.build_prompt(history, 1)

  string.contains(prompt, "Previous attempts") |> should.be_true
  string.contains(prompt, "hello") |> should.be_true
  string.contains(prompt, "tone=PASS") |> should.be_true
}

pub fn build_prompt_summarizes_fail_with_reason_test() {
  let case_ =
    fuzz.FuzzCase(
      input: harness.Input(prompt: "this is stupid"),
      result: runner.Completed(
        harness.Output(
          message: "synthetic: this is stupid",
          tool_calls: [],
          verdicts: [
            harness.Verdict(
              focus: "tone",
              outcome: harness.Fail(reason: "contains forbidden substring"),
            ),
          ],
        ),
      ),
    )
  let history =
    fuzz.IterativeReport(rounds: [
      fuzz.FuzzReport(cases: [case_], failures: [case_]),
    ])

  let prompt = llm.build_prompt(history, 1)

  string.contains(prompt, "tone=FAIL(contains forbidden substring)")
  |> should.be_true
}

pub fn build_prompt_includes_all_rounds_test() {
  let make_case = fn(p: String) {
    fuzz.FuzzCase(
      input: harness.Input(prompt: p),
      result: runner.Completed(
        harness.Output(message: p, tool_calls: [], verdicts: [
          harness.Verdict(focus: "len", outcome: harness.Pass),
        ]),
      ),
    )
  }
  let history =
    fuzz.IterativeReport(rounds: [
      fuzz.FuzzReport(cases: [make_case("first")], failures: []),
      fuzz.FuzzReport(cases: [make_case("second")], failures: []),
    ])

  let prompt = llm.build_prompt(history, 1)

  list.each(["first", "second"], fn(p) {
    string.contains(prompt, p) |> should.be_true
  })
}
