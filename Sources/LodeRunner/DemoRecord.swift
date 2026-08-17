/// A canned run of a specific level, replayed as scripted keystrokes plus
/// deterministic overrides for the guard randomness the sim would otherwise
/// roll on the fly. Ports the per-entry shape of JS `demoData1` at
/// `lodeRunner.demoData1.js:2-137` — same fields, same semantics.
///
/// The playback engine is split into three pieces so each seam is testable:
///
/// - `DemoInput` feeds `actions` as `RunnerAction` values on the right tick
///   (JS `playDemo` at `demo.js:85-95`).
/// - `DemoScript` (attached to `RunnerSimulation`) feeds `goldDrops` at each
///   guard gold pickup and `bornPositions` at each guard reborn (JS
///   `getDemoGold` / `getDemoBornPos` at `demo.js:97-110`).
/// - `DemoData` bundles the 14 shipped records.
public struct DemoRecord: Equatable, Sendable {
    /// 1-based level number in the pack. Kept 1-based to match JS and the
    /// bundled data literally; callers doing array indexing use `.levelIndex`.
    public let levelNumber: Int
    /// AI version the demo was recorded against — always `4` in the bundled
    /// set (JS `demoData1.js` has `ai: 4` on every entry). The port targets
    /// AI 4 only, so this is informational.
    public let ai: Int
    /// Total tick count of the recorded run — used to know when the scripted
    /// stream has fully played out. JS `demoData1.js`'s `time` field.
    public let ticks: Int
    /// Recorded outcome: `1` = level passed, `0` = runner died. Not currently
    /// consumed at playback, kept for parity with the JS record shape.
    public let state: Int
    /// Whether god-mode was on during recording. Same as `state` — parity
    /// only, no live effect on playback (`godMode` isn't ported).
    public let godMode: Bool
    /// The scripted keystrokes. Each event fires on `tick == event.tick`
    /// (JS `demoRecord[i*2] == demoTickCount` at `demo.js:88`).
    public let actions: [ActionEvent]
    /// Per-guard-gold-pickup `hasGold` values. Consumed in order by the sim's
    /// `DemoScript` at each guard gold pickup — JS `demoGoldDrop[demoGoldIdx++]`
    /// at `demo.js:99`.
    public let goldDrops: [Int]
    /// JS-format `bornPos` array: `[0]` is the offset (`1` = X only, Y defaults
    /// to 1; `2` = X/Y pairs), rest is the flat positions stream. Consumed in
    /// order at each guard reborn — JS `demoBornPos` at `demo.js:102-110`.
    public let bornPositions: [Int]

    /// 0-based level index for the pack's `levels` array.
    public var levelIndex: Int { levelNumber - 1 }

    public struct ActionEvent: Equatable, Sendable {
        public let tick: Int
        public let action: RunnerAction

        public init(tick: Int, action: RunnerAction) {
            self.tick = tick
            self.action = action
        }
    }

    public init(
        levelNumber: Int, ai: Int, ticks: Int, state: Int, godMode: Bool,
        actions: [ActionEvent], goldDrops: [Int], bornPositions: [Int]
    ) {
        self.levelNumber = levelNumber
        self.ai = ai
        self.ticks = ticks
        self.state = state
        self.godMode = godMode
        self.actions = actions
        self.goldDrops = goldDrops
        self.bornPositions = bornPositions
    }

    /// Convenience for the bundled data: keycodes match JS `key.js` (37 =
    /// LEFT, 38 = UP, 39 = RIGHT, 40 = DOWN, 90 = Z / dig-left, 88 = X /
    /// dig-right, 32 = SPACE / stop). Any unrecognized keycode maps to `.stop`
    /// so a malformed record still plays without crashing.
    public static func action(forKeyCode code: Int) -> RunnerAction {
        switch code {
        case 37: return .left
        case 38: return .up
        case 39: return .right
        case 40: return .down
        case 90: return .digLeft
        case 88: return .digRight
        default: return .stop
        }
    }

    /// Build from the JS-format flat pairs: `[tick, keycode, tick, keycode, ...]`.
    /// Silently drops a trailing unpaired tick if the array length is odd —
    /// the bundled data is always even, but defensive.
    public static func actions(fromPairs pairs: [Int]) -> [ActionEvent] {
        var out: [ActionEvent] = []
        out.reserveCapacity(pairs.count / 2)
        var i = 0
        while i + 1 < pairs.count {
            out.append(ActionEvent(tick: pairs[i], action: action(forKeyCode: pairs[i + 1])))
            i += 2
        }
        return out
    }
}
