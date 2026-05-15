import octopi/harness.{type Input}

/// Transforms a corpus input into a (potentially) different input. The fuzz
/// loop applies a mutator to seed inputs to generate new test cases.
pub type Mutator =
  fn(Input) -> Input
