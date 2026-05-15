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

// ==== Verdict ====
// * ✅ records focus and Pass outcome
// * ✅ records focus and Fail outcome with reason
pub fn verdict_record_test() {
  let pass = harness.Verdict(focus: "tone", outcome: harness.Pass)
  pass.focus |> should.equal("tone")
  pass.outcome |> should.equal(harness.Pass)

  let fail =
    harness.Verdict(
      focus: "factuality",
      outcome: harness.Fail(reason: "fabricated citation"),
    )
  fail.focus |> should.equal("factuality")
  fail.outcome |> should.equal(harness.Fail(reason: "fabricated citation"))
}
