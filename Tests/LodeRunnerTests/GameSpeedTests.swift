import Testing

@testable import LodeRunner

@Suite
struct GameSpeedTests {
    @Test("framesPerSecond matches the JS speedMode table verbatim")
    func fpsMatchesJSTable() {
        // `main.js:73`: `var speedMode = [14, 18, 23, 29, 35]`
        #expect(GameSpeed.framesPerSecond == [14, 18, 23, 29, 35])
        #expect(GameSpeed.stepCount == 5)
    }

    @Test("labels match the JS speedText table verbatim")
    func labelsMatchJSTable() {
        // `main.js:75`: `speedText = ["VERY SLOW", "SLOW", "NORMAL", "FAST", "VERY FAST"]`
        #expect(GameSpeed.labels == ["VERY SLOW", "SLOW", "NORMAL", "FAST", "VERY FAST"])
    }

    @Test("defaultIndex sits at FAST — the closest table entry to the port's pre-settings 30 FPS")
    func defaultIndexIsFast() {
        #expect(GameSpeed.defaultIndex == 3)
        #expect(GameSpeed.framesPerSecond[GameSpeed.defaultIndex] == 29)
        #expect(GameSpeed.label(for: GameSpeed.defaultIndex) == "FAST")
    }

    @Test("tickPeriod(for:) inverts fps and clamps out-of-range")
    func tickPeriodClamps() {
        // 23 FPS → ~43_478 microseconds per tick.
        #expect(GameSpeed.tickPeriod(for: 2) == .microseconds(1_000_000 / 23))
        // Clamped: negative index falls back to step 0 (14 FPS).
        #expect(GameSpeed.tickPeriod(for: -5) == .microseconds(1_000_000 / 14))
        // Clamped: over-max index falls back to the last step (35 FPS).
        #expect(GameSpeed.tickPeriod(for: 999) == .microseconds(1_000_000 / 35))
    }

    @Test("label(for:) clamps out-of-range indices to the default label")
    func labelClamps() {
        #expect(GameSpeed.label(for: 999) == GameSpeed.labels[GameSpeed.defaultIndex])
        #expect(GameSpeed.label(for: -1) == GameSpeed.labels[GameSpeed.defaultIndex])
    }
}
