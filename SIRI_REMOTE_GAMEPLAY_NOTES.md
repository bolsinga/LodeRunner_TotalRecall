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
- **`microGamepad.reportsAbsoluteDpadValues = true`** — default (`false`)
  reports the touch surface relative to wherever the finger *first* touched
  down, so a static press-and-hold doesn't reliably sustain a direction.
  `true` reports relative to the pad's physical center, so holding a finger
  off-center keeps reporting that direction — required for "hold to walk."
- **Dominant-axis resolution** (`handleMicroDpadValueChanged`) — replaced
  four independent `bind(micro.dpad.up/down/left/right, to:)` calls (each
  thresholding independently off raw x/y) with a single handler that picks
  whichever axis has the larger magnitude. The four-independent-bindings
  approach caused a real bug: any diagonal touch (nearly unavoidable with a
  thumb) fired *two* directions at once (e.g. `.left` and `.up`
  simultaneously), which produced flickering movement and made "is a
  direction held" checks nearly always true.
- **Ring click digs in its own direction, not movement** — `handleMicroButtonA`
  has *no* suppression logic. This was a real back-and-forth: an earlier
  attempt suppressed `buttonA` whenever a direction was concurrently held,
  reasoning that the ring's shared click sensor firing alongside a
  directional click-zone shouldn't be treated as a deliberate dig. That was
  backwards — confirmed via device console logs that the ring's click zones
  *always* report a nonzero direction and fire `buttonA` together, and the
  user's actual desired behavior is "ring click = dig in that direction."
  Removing the suppression fixed it: `handleMicroDpadValueChanged` always
  updates `facingDigAction` a moment before `buttonA` fires, so a ring
  click naturally digs in the clicked direction, and a plain center click
  (no concurrent direction) digs in whichever direction was last faced.
- **`microDpadDeadzone = 0.3`** — below this magnitude on both axes, the
  touch surface reports as centered/released. Chosen from observed hardware
  jitter (~0.2 on a single axis while resting a thumb near center).

## Implemented but NOT yet re-verified on hardware

- **`microDpadVerticalBias = 1.3`** — scales the y-axis up before comparing
  dominance against x, to compensate for a reported feel that climbing
  ladders (up/down) was "harder" than running left/right. Hypothesis: the
  touch surface is circular and a thumb resting near center sweeps
  side-to-side more easily than it reaches fully toward the top/bottom
  edge, so the same felt effort produces a smaller y magnitude. **The
  physical Apple TV device disconnected from the network before this could
  be tested** — the factor of `1.3` is an untested guess and may need
  tuning (or a different approach entirely) once hardware is available
  again.
- **exitBar `.focusable(false)` during live gameplay** (`GameView.swift`,
  gated on `isLiveGameplay = !isPaused && demoRecord == nil`) — makes the
  exitBar's buttons (Menu, level-picker, demo) non-focusable during real
  gameplay, so a stray hard press on the touch surface can't accidentally
  select the on-screen Menu button and pause the game. Implemented in
  response to a real reported annoyance, but not explicitly re-confirmed
  after the later dpad/dig fixes landed on top of it.

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

1. Reconnect to a physical Apple TV, redeploy, and specifically test the
   vertical bias (climbing ladders vs. running) and the exitBar
   non-focusable fix (does a stray touch-surface click still pause the
   game?).
2. Consider whether `microDpadVerticalBias` should be tunable from
   Settings rather than a fixed constant, given it's an ergonomics guess.
3. Re-run the full "start game → play → die → New Game" and
   "attract mode → Settings" flows end-to-end on hardware one more time
   before considering this done.
