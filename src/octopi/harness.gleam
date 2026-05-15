/// What a harness receives as the prompt-side of a run.
pub type Input {
  Input(prompt: String)
}

/// What kicked off a run. Will grow as we model schedulers, webhooks, and
/// fuzz-driven triggers.
pub type Trigger {
  Manual
}

/// A single tool invocation captured during a run.
pub type ToolCall {
  ToolCall(name: String, args: String, result: String)
}

/// Everything observable after a oneshot run completes.
pub type Output {
  Output(message: String, tool_calls: List(ToolCall))
}

/// The contract every concrete harness implements.
pub type Harness =
  fn(Input, Trigger) -> Output
