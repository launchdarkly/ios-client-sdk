# LaunchDarkly Apple SDK test app

This app is an internal quality harness, the counterpart of the Android SDK's `test-app`. It is not an integration
example.

It builds the SDK from this repository as a local Swift package, so every target runs the code checked out here. One
folder of SwiftUI sources is shared by four targets, each with a scheme of the same name:

| Scheme | Runs on |
| --- | --- |
| `TestApp_iOS` | iPhone and iPad, simulator or device, and the Mac through Mac Catalyst |
| `TestApp_macOS` | the Mac, natively |
| `TestApp_tvOS` | Apple TV, simulator or device |
| `TestApp_watchOS` | Apple Watch, simulator or device, as a watch-only app |

The project needs Xcode 16 or later.

## Setup

Copy `Config/Secrets.xcconfig.example` to `Config/Secrets.xcconfig`, which git ignores, and fill in the mobile key:

```
LAUNCHDARKLY_MOBILE_KEY = mob-...
LAUNCHDARKLY_ENVIRONMENT = production
```

Set `LAUNCHDARKLY_ENVIRONMENT = staging` to use LaunchDarkly's staging endpoints. Either value can also be overridden at
launch, without a rebuild, with `-LDMobileKey mob-...` or `-LDEnvironment staging`.

Running on a device needs a development team, set in the target's Signing & Capabilities. The simulators and the Mac
need none.

## Event-loss scenarios

Create a boolean flag named `kill-flag`, or enter another flag key under **Event loss**. Each scenario evaluates the
flag and tracks `$ld:telemetry:error`, standing in for the error an application reports just before it dies, and then
ends the process:

- **Eval+Track+Flush, kill in 5 s** asks for a flush and sends `SIGKILL` five seconds later. The control: the events
  should arrive on this launch.
- **Eval+Kill now** sends `SIGKILL` at once. No handler or SDK code runs before the process ends.
- **Eval+Fatal now** calls `fatalError` at once. Unlike an uncaught exception on Android, a Swift trap leaves no safe
  place to flush from, so this behaves like the kill.

The event persistence picker is saved across launches, and defaults to `immediate`. With that setting, the events from
**Eval+Kill now** and **Eval+Fatal now** should be recovered and delivered on the next launch, though no process code
ran on exit. Under `disabled` they are lost.

**Event storage** shows what the SDK has on disk for this app and mobile key: `pending-` logs that processes append to,
and `ready-` batches waiting for delivery, with the number of events each holds. It reads names and sizes only, so
looking never changes what is there.

## Several instances on a Mac

Every instance of the Mac app, native or Catalyst, uses the same event directory, which is what Tier 3 has to get right
on a Mac: each instance keeps its own open log, any instance can deliver a batch another closed, and the log of an
instance that was killed is recovered by the next client to start.

Start instances with **Launch another instance**, or from a terminal:

```sh
TestApp/scripts/launch-instances.sh 3          # three native instances
TestApp/scripts/launch-instances.sh -c 2       # two Mac Catalyst instances
TestApp/scripts/launch-instances.sh 2 -- -LDEnvironment staging
```

The window title shows each instance's process ID. A typical run: go offline in instance A, track a few events, kill A
with **Eval+Kill now**, then press **Restart client** in instance B. B's storage view shows A's log turn into a batch,
and B delivers it. Native and Catalyst apps have different bundle identifiers, so they do not share a directory with
each other.

## Over-refresh scenario

Create a boolean flag named `trackevents-test` with event tracking enabled. **Over-refresh eval** compares the average
evaluation cost while filling the event capacity and after it is full. The loop runs on the main thread on purpose: it
stands in for a UI that re-evaluates a flag far more often than anything changed.

## Fill 3 batches

**Fill 3 batches** tracks twenty 256 KiB events, which take three 2 MiB batches. A flush then sends three requests, and
offline, or followed by a kill, it leaves three `ready-` files for the next launch. Each event's index is in its data,
so the dashboard shows whether all of them arrived and none twice.

## Benchmark

**Benchmark**, under the status text, runs the event persistence benchmark in the app's own process and shows its
tables in a sheet, with **Copy** on iOS and the Mac. It is the Android test app's benchmark, section for section:
building and serializing a feature event across context shapes and privacy settings, what an evaluation and a commit
point cost, the tail of a commit point over 100, 1,000 and 10,000 calls, comparing contexts, and summary events. It
measures stores of its own in a temporary directory, so it needs no client and leaves the event storage view alone.

It is in Debug builds only, since it reaches the SDK's internals through `@testable import`. The tables are also
printed to the console and appended to `Library/Caches/event-bench.txt` in the app's container. A run on a watch makes a
tenth of the iterations. Read the figures as ratios between rows: a Debug build is unoptimized, and a live client shares
the process.
