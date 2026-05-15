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

/// Pass or fail outcome of a single focused judgement, with a diagnostic
/// reason on failure.
pub type Outcome {
  Pass
  Fail(reason: String)
}

/// A focused judgement on a run. Scorer harnesses produce one or many of
/// these; agent harnesses leave the list empty. `focus` is a free-form
/// dimension name (e.g. "tone", "factuality"); it may tighten into a custom
/// type once the dimension set stabilises.
pub type Verdict {
  Verdict(focus: String, outcome: Outcome)
}

/// Everything observable after a oneshot run completes.
pub type Output {
  Output(message: String, tool_calls: List(ToolCall), verdicts: List(Verdict))
}

/// The contract every concrete harness implements.
pub type Harness =
  fn(Input, Trigger) -> Output
