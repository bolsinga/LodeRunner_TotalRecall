"use strict";

/**
 * Characterization: version pack metadata in info.js (settings About cards).
 */

const { describe, it } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { ROOT } = require("./helpers/loadScripts.js");

describe("version info metadata (characterization)", () => {
	it("info.js keeps pack fact arrays and drops the canvas overlay", () => {
		const text = fs.readFileSync(path.join(ROOT, "lodeRunner.info.js"), "utf8");
		assert.match(text, /var classicInfo\s*=/);
		assert.match(text, /var championInfo\s*=/);
		assert.doesNotMatch(text, /function infoMenu/);
		assert.doesNotMatch(text, /function infoMenuClass/);
		assert.doesNotMatch(text, /info_overlay/);
		assert.doesNotMatch(text, /createjs\./);
	});

	it("edit pointer input stays event-driven (no editTick / setFPS(60))", () => {
		const text = fs.readFileSync(path.join(ROOT, "lodeRunner.edit.js"), "utf8");
		assert.doesNotMatch(text, /Ticker\.setFPS\(60\)/);
		assert.doesNotMatch(text, /addEventListener\(["']tick["'],\s*editTick\)/);
		assert.doesNotMatch(text, /gameTicker\s*=\s*editTick/);
		assert.match(text, /function startEditInput/);
		assert.match(text, /function stopEditInput/);
		assert.match(text, /function editPointerAt/);
		assert.match(text, /pointerdown/);
		assert.match(text, /pointermove/);
	});

	it("editor Load defaults to Custom Levels (browseOnly)", () => {
		const text = fs.readFileSync(path.join(ROOT, "lodeRunner.edit.js"), "utf8");
		assert.match(text, /function openLevelPicker[\s\S]*startPlayData:\s*PLAY_DATA_USERDEF/);
		assert.match(text, /function openLevelPicker[\s\S]*browseOnly:\s*true/);
	});

	it("level-select grid CSS does not flex-collapse inside max-height dialog", () => {
		const css = fs.readFileSync(path.join(ROOT, "lodeRunner.levelSelect.css"), "utf8");
		// Regression: flex:1 + min-height:0 with dialog max-height-only clipped all cells.
		assert.doesNotMatch(css, /\.lv-grid\s*\{[^}]*min-height:\s*0/);
		assert.match(css, /\.lv-grid\s*\{[^}]*max-height:\s*calc/);
	});
});
