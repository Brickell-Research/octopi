import gleam/erlang/process
import gleam/list
import gleam/string
import octopi/harness.{type Harness, type Input, type Output, type Trigger}

/// Result of a single harness invocation under the runner.
pub type RunResult {
  /// Harness completed within the timeout.
  Completed(output: Output)
  /// Harness did not produce a result within the timeout.
  TimedOut
  /// Harness process exited abnormally; the captured reason is for diagnostics
  /// only.
  Crashed(reason: String)
}

/// Runs `harness` against every input concurrently, capturing each result
/// independently. One slow or crashing run does not affect the others. Results
/// are returned in the same order as `inputs`.
pub fn run_all(
  harness harness: Harness,
  inputs inputs: List(Input),
  trigger trigger: Trigger,
  timeout_ms timeout_ms: Int,
) -> List(RunResult) {
  inputs
  |> list.map(fn(input) { spawn_run(harness, input, trigger) })
  |> list.map(fn(handle) { await_run(handle, timeout_ms) })
}

type RunHandle {
  RunHandle(subject: process.Subject(Output), monitor: process.Monitor)
}

type Event {
  ResultEvent(Output)
  DownEvent(process.ExitReason)
}

fn spawn_run(harness: Harness, input: Input, trigger: Trigger) -> RunHandle {
  let subject = process.new_subject()
  let pid =
    process.spawn(fn() {
      let output = harness(input, trigger)
      process.send(subject, output)
    })
  let monitor = process.monitor(pid)
  RunHandle(subject: subject, monitor: monitor)
}

fn await_run(handle: RunHandle, timeout_ms: Int) -> RunResult {
  let selector =
    process.new_selector()
    |> process.select_map(for: handle.subject, mapping: ResultEvent)
    |> process.select_specific_monitor(handle.monitor, fn(down) {
      case down {
        process.ProcessDown(reason: reason, ..) -> DownEvent(reason)
        process.PortDown(reason: reason, ..) -> DownEvent(reason)
      }
    })

  case process.selector_receive(selector, timeout_ms) {
    Ok(ResultEvent(output)) -> Completed(output)
    Ok(DownEvent(process.Normal)) -> Crashed("normal exit before result")
    Ok(DownEvent(process.Killed)) -> Crashed("killed")
    Ok(DownEvent(process.Abnormal(reason))) -> Crashed(string.inspect(reason))
    Error(Nil) -> TimedOut
  }
}
