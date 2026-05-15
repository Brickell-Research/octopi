import octopi/harness

// ==== ToolCall ====
// * ✅ records name, args, and result fields verbatim
pub fn tool_call_record_test() {
  let call =
    harness.ToolCall(name: "search", args: "{\"q\":\"otp\"}", result: "ok")

  assert call.name == "search"
  assert call.args == "{\"q\":\"otp\"}"
  assert call.result == "ok"
}
