import Observation

/// Playback-mode `RunnerInput` — replaces `KeyboardInput` during a demo
/// session. Feeds the scripted `[tick, action]` stream from a `DemoRecord`
/// to the driver via `currentAction`, advancing its internal tick count in
/// lockstep with the driver's own tick loop.
///
/// Ports JS `playDemo` at `lodeRunner.demo.js:85-95`:
///
///     function playDemo() {
///         if (demoRecordIdx < demoRecord.length) {
///             if (demoRecord[demoRecordIdx*2] == demoTickCount) {
///                 pressKey(demoRecord[demoRecordIdx*2+1]);
///                 demoRecordIdx++;
///             }
///         }
///         demoTickCount++;
///     }
///
/// The JS `pressKey` fans into `keyAction`, which is what `moveRunner` reads
/// on the same tick. The Swift equivalent is: `advanceTickIfNeeded()` updates
/// `currentAction`, and the driver then reads it on the same tick — same
/// order, same one-tick lag as the JS.
///
/// Kept `@Observable` so a view that wants to reflect playback progress
/// (e.g. a debug HUD) can bind to `tickCount` / `isComplete`, though the
/// currently shipping UI doesn't yet.
@Observable @MainActor
public final class DemoInput: RunnerInput {
    /// The record being played back. Immutable — the sim consumes its
    /// `goldDrops` / `bornPositions` through the sim's `DemoScript`.
    public let record: DemoRecord

    /// Latched action delivered to the driver. Sticky between events —
    /// matches the JS's `keyAction` global, which also holds until a new
    /// `pressKey` overwrites it (`key.js:322`).
    public private(set) var currentAction: RunnerAction = .stop

    /// Ticks since playback started. Compared against `record.actions[i].tick`
    /// on each `advanceTickIfNeeded()`. Matches JS `demoTickCount`.
    public private(set) var tickCount: Int = 0

    /// True once the last scripted action has fired *and* the recorded
    /// duration has fully elapsed. Composition layer checks this alongside
    /// `session.simulation.phase` to decide when a passed/died demo can
    /// unwind — the runner may still be mid-fall past the last input.
    public private(set) var isComplete: Bool = false

    private var actionIndex: Int = 0

    public init(record: DemoRecord) {
        self.record = record
    }

    public func advanceTickIfNeeded() {
        // Fire every scripted press whose tick has arrived — usually one per
        // call, but the loop covers a hypothetical run of same-tick events
        // (the bundled data doesn't have any, but the JS's `if` guard trivially
        // allows one-at-a-time so the semantics match either way).
        while actionIndex < record.actions.count {
            let event = record.actions[actionIndex]
            guard event.tick == tickCount else { break }
            currentAction = event.action
            actionIndex += 1
        }
        tickCount += 1
        if actionIndex >= record.actions.count && tickCount >= record.ticks {
            isComplete = true
        }
    }

    public func resetAction() {
        currentAction = .stop
    }
}
