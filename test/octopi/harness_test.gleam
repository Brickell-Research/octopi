import gleeunit/should
import octopi/harness

// ==== ToolCall ====
// * ✅ records name, args, and result fields verbatim
pub fn tool_call_record_test() {
  let call =
    harness.ToolCall(name: "search", args: "{\"q\":\"otp\"}", result: "ok")

  call.name |> should.equal("search")
  call.args |> should.equal("{\"q\":\"otp\"}")
  call.result |> should.equal("ok")
}
