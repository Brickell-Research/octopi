import octopi/harness
import octopi/mutators/append
import test_helpers

// ==== with ====
// * ✅ appends a single character suffix
// * ✅ appends a multi-character suffix
// * ✅ empty suffix is identity
// * ✅ preserves an empty starting prompt
pub fn with_test() {
  [
    #("single char", #("hello", "!"), "hello!"),
    #("multi char", #("hello", " world"), "hello world"),
    #("empty suffix", #("hello", ""), "hello"),
    #("empty prompt", #("", "seed"), "seed"),
  ]
  |> test_helpers.table_test_1(fn(pair) {
    let #(prompt, suffix) = pair
    let mutator = append.with(suffix)
    let mutated = mutator(harness.Input(prompt: prompt))
    mutated.prompt
  })
}
