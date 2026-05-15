import gleam/dynamic/decode
import gleam/http
import gleam/http/request
import gleam/httpc
import gleam/json
import gleam/list
import gleam/result
import gleam/string

/// Conversational role on a single message.
pub type Role {
  User
  Assistant
  System
}

/// One message in a Claude conversation. `System` messages are extracted out
/// of the messages array and concatenated into the request's `system` field
/// per the Messages API shape.
pub type Message {
  Message(role: Role, content: String)
}

/// Failure modes for an Anthropic completion call.
pub type Error {
  /// Underlying HTTP transport failure (DNS, TLS, timeout, etc.).
  HttpError(reason: String)
  /// Server returned a non-200 status; body included verbatim for diagnosis.
  ApiError(status: Int, body: String)
  /// Request succeeded but the response body did not match the expected shape.
  DecodeError(reason: String)
}

/// Successful completion result.
pub type Completion {
  Completion(
    text: String,
    input_tokens: Int,
    output_tokens: Int,
    stop_reason: String,
  )
}

/// POSTs a Messages request to the Anthropic API and returns the assistant's
/// text reply along with token usage. The caller supplies the API key
/// directly (typically pulled from `ANTHROPIC_API_KEY` at the boundary) so
/// this function stays easy to test against fakes.
pub fn complete(
  api_key api_key: String,
  model model: String,
  messages messages: List(Message),
  max_tokens max_tokens: Int,
) -> Result(Completion, Error) {
  let body = build_request_body(model, messages, max_tokens)

  let req =
    request.new()
    |> request.set_method(http.Post)
    |> request.set_scheme(http.Https)
    |> request.set_host("api.anthropic.com")
    |> request.set_path("/v1/messages")
    |> request.set_header("x-api-key", api_key)
    |> request.set_header("anthropic-version", "2023-06-01")
    |> request.set_header("content-type", "application/json")
    |> request.set_body(body)

  case httpc.send(req) {
    Ok(resp) ->
      case resp.status {
        200 -> parse_response(resp.body)
        status -> Error(ApiError(status: status, body: resp.body))
      }
    Error(reason) -> Error(HttpError(reason: string.inspect(reason)))
  }
}

/// Builds the JSON request body string for the Messages API. System messages
/// are pulled out of the messages array and joined into the top-level
/// `system` field, matching Anthropic's shape.
@internal
pub fn build_request_body(
  model: String,
  messages: List(Message),
  max_tokens: Int,
) -> String {
  let conversation =
    list.filter(messages, fn(m) {
      case m.role {
        User | Assistant -> True
        System -> False
      }
    })

  let system_text =
    messages
    |> list.filter(fn(m) { m.role == System })
    |> list.map(fn(m) { m.content })
    |> string.join("\n\n")

  let messages_json =
    json.array(conversation, fn(m) {
      json.object([
        #("role", json.string(role_to_string(m.role))),
        #("content", json.string(m.content)),
      ])
    })

  let base = [
    #("model", json.string(model)),
    #("max_tokens", json.int(max_tokens)),
    #("messages", messages_json),
  ]

  let entries = case system_text {
    "" -> base
    _ -> [#("system", json.string(system_text)), ..base]
  }

  json.to_string(json.object(entries))
}

fn role_to_string(role: Role) -> String {
  case role {
    User -> "user"
    Assistant -> "assistant"
    System -> "system"
  }
}

/// Parses a 200-OK Messages response body into a Completion. Concatenates all
/// text-typed content blocks; non-text blocks (e.g. tool_use) are ignored
/// for now.
@internal
pub fn parse_response(body: String) -> Result(Completion, Error) {
  json.parse(body, completion_decoder())
  |> result.map_error(fn(_) {
    DecodeError(reason: "could not decode Anthropic response body")
  })
}

fn completion_decoder() -> decode.Decoder(Completion) {
  use content_blocks <- decode.field(
    "content",
    decode.list(content_block_decoder()),
  )
  use stop_reason <- decode.field("stop_reason", decode.string)
  use input_tokens <- decode.subfield(["usage", "input_tokens"], decode.int)
  use output_tokens <- decode.subfield(["usage", "output_tokens"], decode.int)

  let text =
    content_blocks
    |> list.filter_map(fn(b) { b })
    |> string.join("")

  decode.success(Completion(
    text: text,
    input_tokens: input_tokens,
    output_tokens: output_tokens,
    stop_reason: stop_reason,
  ))
}

/// Decodes a single content block. Returns `Ok(text)` for a text block and
/// `Error(Nil)` for any other block type (filtered out by the caller).
fn content_block_decoder() -> decode.Decoder(Result(String, Nil)) {
  use block_type <- decode.field("type", decode.string)
  case block_type {
    "text" -> {
      use text <- decode.field("text", decode.string)
      decode.success(Ok(text))
    }
    _ -> decode.success(Error(Nil))
  }
}
