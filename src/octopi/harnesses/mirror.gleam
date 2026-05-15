import octopi/harness.{type Input, type Output, type Trigger}

/// Echoes the prompt back as the message with no tool calls or verdicts. The
/// trivial harness used to exercise the runner, mutator, and scorer end-to-end
/// before any real agent is wired in.
pub fn run(input: Input, _trigger: Trigger) -> Output {
  harness.Output(message: input.prompt, tool_calls: [], verdicts: [])
}
