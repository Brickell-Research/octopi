import gleam/list
import octopi/harness.{type Harness, type Input, type Output, type Trigger}

/// Compose an agent harness with a single scorer harness into a "harness
/// tester" that `fuzz.run` can call as one unit.
///
/// The agent runs first and produces an Output. `scorer_input` builds the
/// scorer's Input from the original Input and the agent's Output. The scorer
/// then runs and contributes verdicts.
///
/// The combined Output keeps the agent's `message` and `tool_calls` — the
/// real system response — and merges verdicts from agent and scorer in
/// order (agent first, then scorer). Agents conventionally produce no
/// verdicts, but we still append rather than replace so a future
/// self-reporting agent isn't silently dropped.
///
/// If the agent or scorer panics, the panic propagates to the caller; the
/// runner wrapping this combined harness catches it as `Crashed`.
pub fn compose(
  agent agent: Harness,
  scorer scorer: Harness,
  scorer_input build_scorer_input: fn(Input, Output) -> Input,
) -> Harness {
  fn(input: Input, trigger: Trigger) -> Output {
    let agent_output = agent(input, trigger)
    let scorer_in = build_scorer_input(input, agent_output)
    let scorer_output = scorer(scorer_in, trigger)
    harness.Output(
      message: agent_output.message,
      tool_calls: agent_output.tool_calls,
      verdicts: list.append(agent_output.verdicts, scorer_output.verdicts),
    )
  }
}
