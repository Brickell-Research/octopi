import octopi/harness
import octopi/harnesses/mirror
import test_helpers

// ==== run ====
// * ✅ echoes prompt verbatim as message with no tool calls
// * ✅ preserves empty prompt
// * ✅ preserves multiline prompt
pub fn run_test() {
  [
    #("ping", harness.Input(prompt: "ping"), #("ping", [])),
    #("empty prompt", harness.Input(prompt: ""), #("", [])),
    #(
      "multiline prompt",
      harness.Input(prompt: "line1\nline2"),
      #("line1\nline2", []),
    ),
  ]
  |> test_helpers.table_test_1(fn(input) {
    let out = mirror.run(input, harness.Manual)
    #(out.message, out.tool_calls)
  })
}
