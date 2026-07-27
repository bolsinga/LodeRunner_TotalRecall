# Tests

Characterization / regression suite for Lode Runner Total Recall.

## Requirements

- Node.js **≥ 18** (local machine confirmed on v26.5.0). Uses built-in `node:test` / `node:assert` - no npm install needed.

## Run

```bash
npm test
```

Or:

```bash
node --test test/*.test.js
```

## What is covered (Stage 1)

| Suite | Kind | Locks |
|-------|------|--------|
| `level-integrity.test.js` | characterization | All classic/pro/revenge/fan/championship levels: 28×16, legal tiles, one `&` |
| `level-integrity.test.js` | characterization | `parseLevelChar` / `parseLevelMap` tile mapping + classic L1 snapshot |
| `level-map-culling.test.js` | characterization | `resolveLevelMap` maxGuard culling + first-`&`-wins (the buildLevelMap path Stage 2 will risk) |
| `input-logic.test.js` | correctness | Sticky stop-on-release works without capture; `RECORD_KEY` pushes are optional |
| `wdata-privacy.test.js` | correctness | Shipped `wData.N.js` packs have no IPs / names / locations / uId |
| `lazy-load.test.js` | characterization | HTML critical path is classic-only; lazy pack wiring in `playVersionInfo` |
| `theme-preload.test.js` | characterization | Theme asset manifests: active theme only at boot, other on first toggle |
| `inventory.test.js` | characterization | Every root script is wired in HTML or known-lazy; registry `levelCount` matches packs |
| `html-shell.test.js` | characterization | HTML shell meta: lang/charset/viewport, no obsolete IE meta |
| `tween.test.js` | correctness | `tweenGet` chains: interpolation, completion-once, override cancel |
| `sound.test.js` | correctness | Web Audio layer: ogg/mp3 fallback, instance stop/restart, pause offset |
| `assets.test.js` | correctness | Image asset cache: getResult ids, cursor warm-cache, continue-on-error |
| `info-overlay.test.js` | characterization | version `*Info` arrays remain; canvas info overlay / flags gone; edit input is pointer-driven |
| `edit-guards.test.js` | correctness | Edit mode blocks attract-demo; unsaved-map unload/leave guards exist |
| `recolor-thumb.test.js` | characterization | colorTheme recolor uses plain-canvas readback (no Stage); level thumbs flatten via `levelThumb.js` |
| `share-codec.test.js` | characterization | `zipLevelMap` ↔ `unzipLevelMap` round-trip; bad checksum → `""` |
| `constants.test.js` | characterization | `def.js` grid / tile / score / `GAME_*` values |
| `storage.test.js` | characterization | `setStorage` / `getStorage` / `clearStorage` with mock `localStorage` |
| `demo-data.test.js` | characterization | `demoData1` record schema |

## Conventions

- **Behavior change ⇒ update or add tests in the same commit.**
- Prefer labeling tests as **characterization** (current output) vs **correctness** (intended output). Known-buggy chrome/iris behavior may be locked as characterization until Stage 2 fixes it.
- Pure helpers live in `lodeRunner.levelParse.js` (`parseLevelChar`, `resolveLevelMap`), `lodeRunner.inputLogic.js`, `lodeRunner.shareCodec.js`, `lodeRunner.storageCore.js` and are loaded in the browser via `lodeRunner.html`.
- `buildLevelMap` in `main.js` calls `resolveLevelMap(levelMap, maxGuard)` for base/act (including culling), then only attaches CreateJS sprites. Do not re-introduce inline culling in `main.js`.
- Default `recordMode` is `RECORD_NONE`. Stop-on-release input runs via `processInputKeyState()`; demo capture requires setting `RECORD_KEY` in `lodeRunner.demo.js`.

## CI

No CI configured. Run `npm test` locally before every commit. Revisit if a shared remote workflow is added.
