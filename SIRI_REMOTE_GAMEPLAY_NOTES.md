# Siri Remote Gameplay Input — Status & Notes

Work-in-progress notes for resuming this later. Goal: make the Siri Remote
actually drive live gameplay on tvOS (movement + digging), not just menu
navigation. This picks up from PR #88, which added `GCMicroGamepad`
bindings but couldn't make them fire in practice — tvOS's focus engine was
consuming all Siri Remote input before it ever reached `GamepadInput`.

## What's implemented and confirmed working (on a real Apple TV + Siri Remote)

- **`GameControllerEventHost` / `GCEventViewController` exclusivity**
  (`Sources/LodeRunner/GameControllerEventHost.swift`). Wraps `GameView`'s
  own content (not the app's root view controller) in a `GCEventViewController`
  subclass, toggling `controllerUserInteractionEnabled` — `false` during real
  gameplay routes D-pad/button input to `GamepadInput` instead of the focus
  engine; `true` otherwise restores normal focus navigation. Scoped to just
  `GameView`'s subtree because `PackChooserView` renders `gameLayer` and any
  open `overlay` as ZStack siblings, so overlay/menu focus is never affected.
  **Confirmed on hardware**: this is the piece that actually got gameplay
  input flowing at all.
- **Demo/attract-mode exclusion**: the exclusivity condition is
  `isPaused || demoRecord != nil`, not just `isPaused`. Attract-mode demo
  playback isn't controller-driven, so without this exclusion its own
  exitBar (Stop-demo/Menu buttons) became unreachable the same way live
  gameplay's does — this broke "get from demo mode to Settings" until fixed.
- **Physical Menu button fallback** (`GamepadInput.onMenuButtonPressed`,
  bound to `GCExtendedGamepad.buttonMenu` / `GCMicroGamepad.buttonMenu`).
  Once gameplay claims exclusive input, the on-screen exitBar Menu button
  is no longer focus-reachable, so this is the only way back to the pause
  menu. Wired to `GameView.triggerExit()`.
- **`Selection` nonce fix** (`PackChooserView.swift`) — `Selection` gained a
  `let attempt = UUID()` field (defaulted, so every construction gets a
  fresh value). Without it, picking "New Game" for the same pack/theme/level
  after a game-over left the old `.gameOver`-phase `GameSessionDriver`
  mounted, since SwiftUI's `.id(currentGame)` saw an equal value and didn't
  rebuild. This is a general bug, not tvOS-specific — it was just newly
  reachable via the Menu-button fallback above.
## Input model (rewritten to use Apple's directional-gamepad support)

Gameplay now targets the **2nd-gen+ Siri Remote only**, via
`GCDirectionalGamepad` (opted in with `GCSupportedGameControllers` →
`DirectionalGamepad` and `GCSupportsMultipleMicroGamepads`, supplied by
`LodeRunnerApp-Info.plist`). The earlier analog touch-surface handling
(`reportsAbsoluteDpadValues`, deadzone, dominant axis, vertical bias, ring-click
dig logic) was removed.

- Outer-ring **clicks** (`GCInputDirectionalCardinalDpad`) = up/down/left/right.
  Digital and holdable, so no thresholding.
- **Center button** (`GCInputDirectionalCenterButton`, inner-ring click) = dig
  (facing direction, or dig-left in split mode); Play/Pause = dig-right in split mode.
- **Back/Menu** button = pause menu.
- **Not yet verified on hardware**: that ring clicks walk comfortably, and that the
  center button doesn't also fire a direction. exitBar `.focusable(false)` during
  live play is also still unverified.

## Key lessons for whoever (or whatever) picks this back up

1. **The tvOS Simulator cannot verify any of this.** Its synthesized
   remote-press commands (both the `device-interaction` skill's
   `DeviceInteractionSynthesize` and the Simulator's own on-screen remote)
   route through tvOS's `UIFocus` system directly, not through a real
   `GCController`/`GCMicroGamepad` HID path. `GCEventViewController`'s
   `controllerUserInteractionEnabled` only affects the latter, so the
   Simulator's select/D-pad presses reach on-screen buttons regardless of
   that flag's value — confirmed empirically (added a temporary debug print
   confirming the flag really was `false`, and select still worked in the
   Simulator). **All real verification of this feature requires a physical
   Apple TV + Siri Remote** (a physical MFi/extended controller paired to
   the Mac might be a viable partial stand-in for `GCExtendedGamepad`
   testing, since those are passed through to the Simulator as real HID —
   not yet tried).
2. **Console logging on the real device via `GetConsoleOutput` was the
   only way to actually diagnose hardware behavior.** Guessing from Apple's
   docs alone led to two wrong turns (the ring/dig suppression logic, and
   initially not realizing `GCControllerDirectionPad`'s four directions
   aren't mutually exclusive). Add a temporary `print()`, rebuild, deploy
   with `RunProject`, ask the user to do one specific isolated action, pull
   the trace with `GetConsoleOutput`, remove the print once diagnosed.
3. **Two regressions happened by touching tvOS focus behavior too broadly**
   before landing on the current scoped approach: (a) an early attempt
   applied `.focusable()` + `@FocusState` to `GameView`'s entire root
   VStack, which hijacked focus onto random sprites and was worse than the
   original bug; (b) the first `GameControllerEventHost` attempt didn't
   exclude demo/attract mode from exclusivity, breaking demo-mode
   navigation. Both were fully reverted before retrying narrower fixes.
   Any future change in this area should stay scoped to `GameView`'s own
   subtree and explicitly account for demo mode.
4. **Real hardware surprises to expect on a 2nd-gen Siri Remote**: the
   outer ring of directional click-zones shares one physical click switch
   with the center touch area (`buttonA`), so a ring click always reports a
   dpad direction *and* a button press together — design for that
   intentionally rather than treating it as event-ordering noise.

## Suggested next steps when resuming

1. On a physical Apple TV with a 2nd-gen remote, verify ring-click walking, center-click digging, and Back-to-menu.
2. Re-run "start game → play → die → New Game" and "attract mode → Settings".
