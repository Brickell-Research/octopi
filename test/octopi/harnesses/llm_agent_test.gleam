import gleam/list
import gleam/option.{None, Some}
import gleeunit/should
import octopi/harnesses/llm_agent
import octopi/llm/anthropic

// ==== build_messages ====
// * ✅ no system prompt → only the user message
// * ✅ system prompt present → system message followed by user message
// * ✅ user prompt content is preserved verbatim
pub fn build_messages_no_system_test() {
  let messages = llm_agent.build_messages(None, "hello there")

  list.length(messages) |> should.equal(1)
  let assert [msg] = messages
  msg
  |> should.equal(anthropic.Message(
    role: anthropic.User,
    content: "hello there",
  ))
}

pub fn build_messages_with_system_test() {
  let messages =
    llm_agent.build_messages(Some("be terse"), "describe an octopus")

  list.length(messages) |> should.equal(2)
  let assert [first, second] = messages
  first
  |> should.equal(anthropic.Message(role: anthropic.System, content: "be terse"))
  second
  |> should.equal(anthropic.Message(
    role: anthropic.User,
    content: "describe an octopus",
  ))
}
