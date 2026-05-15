import gleam/string
import gleeunit/should
import octopi/llm/anthropic

// ==== build_request_body ====
// * ✅ encodes model, max_tokens, and a single user message
// * ✅ extracts system messages into the top-level `system` field
// * ✅ joins multiple system messages with a blank line
// * ✅ omits `system` when no system messages are present
pub fn build_request_body_basic_test() {
  let body =
    anthropic.build_request_body(
      "claude-haiku-4-5-20251001",
      [anthropic.Message(role: anthropic.User, content: "hello")],
      256,
    )

  string.contains(body, "\"model\":\"claude-haiku-4-5-20251001\"")
  |> should.be_true
  string.contains(body, "\"max_tokens\":256") |> should.be_true
  string.contains(body, "\"role\":\"user\"") |> should.be_true
  string.contains(body, "\"content\":\"hello\"") |> should.be_true
  string.contains(body, "\"system\"") |> should.be_false
}

pub fn build_request_body_system_extraction_test() {
  let body =
    anthropic.build_request_body(
      "claude-haiku-4-5-20251001",
      [
        anthropic.Message(role: anthropic.System, content: "be terse"),
        anthropic.Message(role: anthropic.System, content: "no emojis"),
        anthropic.Message(role: anthropic.User, content: "hi"),
      ],
      128,
    )

  string.contains(body, "\"system\":\"be terse\\n\\nno emojis\"")
  |> should.be_true
  // System should be lifted out — only the user message remains in `messages`.
  string.contains(body, "\"role\":\"system\"") |> should.be_false
  string.contains(body, "\"role\":\"user\"") |> should.be_true
}

// ==== parse_response ====
// * ✅ extracts text from a single text content block
// * ✅ concatenates multiple text content blocks
// * ✅ ignores non-text content blocks (e.g. tool_use)
// * ✅ surfaces token usage and stop_reason
// * ✅ returns DecodeError on malformed JSON
pub fn parse_response_single_text_block_test() {
  let body =
    "{\"id\":\"msg_1\",\"type\":\"message\",\"role\":\"assistant\","
    <> "\"model\":\"claude-haiku-4-5-20251001\","
    <> "\"content\":[{\"type\":\"text\",\"text\":\"hi there\"}],"
    <> "\"stop_reason\":\"end_turn\",\"stop_sequence\":null,"
    <> "\"usage\":{\"input_tokens\":5,\"output_tokens\":3}}"

  let assert Ok(c) = anthropic.parse_response(body)
  c.text |> should.equal("hi there")
  c.input_tokens |> should.equal(5)
  c.output_tokens |> should.equal(3)
  c.stop_reason |> should.equal("end_turn")
}

pub fn parse_response_concatenates_text_blocks_test() {
  let body =
    "{\"content\":[{\"type\":\"text\",\"text\":\"hello \"},"
    <> "{\"type\":\"text\",\"text\":\"world\"}],"
    <> "\"stop_reason\":\"end_turn\","
    <> "\"usage\":{\"input_tokens\":1,\"output_tokens\":2}}"

  let assert Ok(c) = anthropic.parse_response(body)
  c.text |> should.equal("hello world")
}

pub fn parse_response_ignores_non_text_blocks_test() {
  let body =
    "{\"content\":[{\"type\":\"tool_use\",\"id\":\"t_1\",\"name\":\"x\",\"input\":{}},"
    <> "{\"type\":\"text\",\"text\":\"after tool\"}],"
    <> "\"stop_reason\":\"end_turn\","
    <> "\"usage\":{\"input_tokens\":1,\"output_tokens\":2}}"

  let assert Ok(c) = anthropic.parse_response(body)
  c.text |> should.equal("after tool")
}

pub fn parse_response_decode_error_test() {
  case anthropic.parse_response("{not json") {
    Error(anthropic.DecodeError(_)) -> Nil
    other -> panic as { "expected DecodeError, got " <> string.inspect(other) }
  }
}
