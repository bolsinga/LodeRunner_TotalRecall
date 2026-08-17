/// Deterministic per-guard overrides supplied to a `RunnerSimulation` during
/// demo playback. Consumed in order as the sim runs, matching the JS
/// per-tick reads at `demo.js:97-110` (`getDemoGold` / `getDemoBornPos`).
///
/// Value semantics: the sim owns this as `var demoScript: DemoScript?`. Each
/// mutating call to `nextGuardGold()` / `nextBornPosition()` advances the
/// script's internal indices in-place with the surrounding `mutating` sim
/// call. Because Codable/Sendable RunnerSimulation copies would each own
/// their own indices, callers keep exactly one live sim in flight during
/// demo playback (`GameSession` swaps sims per level; this port ships
/// single-level demos, so the sim is created once and never copied).
public struct DemoScript: Equatable, Codable, Sendable {
    /// `hasGold` values fed in order to each guard gold pickup — port of
    /// JS `demoGoldDrop`.
    public let goldDrops: [Int]
    /// JS-format `bornPos` array. `[0]` is the offset (`1` = X only with
    /// Y forced to 1, `2` = interleaved X/Y). Rest is the flat stream.
    /// Empty (`[]`) means the record had no reborns during recording — any
    /// on-the-fly respawn falls back to the sim's random `columnPicker`.
    public let bornPositions: [Int]

    private var goldIndex: Int
    /// Matches JS `demoBornIdx` at `demo.js:5` — starts at 0. The `2`-format
    /// path pre-increments by 2 (`demoBornIdx += 2`); the `1`-format path
    /// pre-increments by 1 (`++demoBornIdx`). Both read the just-set index,
    /// so the initial 0 acts as a "one before the first" sentinel.
    private var bornIndex: Int

    public init(goldDrops: [Int], bornPositions: [Int]) {
        self.goldDrops = goldDrops
        self.bornPositions = bornPositions
        self.goldIndex = 0
        self.bornIndex = 0
    }

    public init(record: DemoRecord) {
        self.init(goldDrops: record.goldDrops, bornPositions: record.bornPositions)
    }

    /// Advance and return the next scripted `hasGold`, or `nil` if the
    /// script ran out (fall back to the sim's random). JS analog:
    /// `guard.hasGold = demoGoldDrop[demoGoldIdx++]`.
    public mutating func nextGuardGold() -> Int? {
        guard goldIndex < goldDrops.count else { return nil }
        let v = goldDrops[goldIndex]
        goldIndex += 1
        return v
    }

    /// Advance and return the next scripted reborn tile, or `nil` if the
    /// script ran out. JS `getDemoBornPos` at `demo.js:102-110`:
    ///
    ///     if (demoBornPos[0] == 2) {
    ///         demoBornIdx += 2;
    ///         return { x: demoBornPos[demoBornIdx-1], y: demoBornPos[demoBornIdx] };
    ///     } else {
    ///         return { x: demoBornPos[++demoBornIdx], y: 1 };
    ///     }
    ///
    /// Ported literally, including the "start at 0, pre-increment to read"
    /// indexing convention.
    public mutating func nextBornPosition() -> GridPoint? {
        guard !bornPositions.isEmpty else { return nil }
        let format = bornPositions[0]
        if format == 2 {
            bornIndex += 2
            guard bornIndex < bornPositions.count else { return nil }
            let x = bornPositions[bornIndex - 1]
            let y = bornPositions[bornIndex]
            return GridPoint(x: x, y: y)
        } else {
            bornIndex += 1
            guard bornIndex < bornPositions.count else { return nil }
            return GridPoint(x: bornPositions[bornIndex], y: 1)
        }
    }
}
