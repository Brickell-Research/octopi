import octopi/harness
import octopi/mutator.{type Mutator}

/// Builds a mutator that appends `suffix` to the input prompt. Deterministic;
/// useful as a sanity-check mutation while wiring the fuzz loop.
pub fn with(suffix: String) -> Mutator {
  fn(input: harness.Input) { harness.Input(prompt: input.prompt <> suffix) }
}
