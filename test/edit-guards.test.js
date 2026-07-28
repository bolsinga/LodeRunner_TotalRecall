"use strict";

/**
 * Correctness: edit mode must not enter attract; unsaved edits need unload guard hooks.
 */

const { describe, it } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { ROOT } = require("./helpers/loadScripts.js");

describe("edit attract + unsaved guards", () => {
	it("startEditMode disables auto-demo idle and clears idle timer", () => {
		const text = fs.readFileSync(path.join(ROOT, "lodeRunner.edit.js"), "utf8");
		assert.match(text, /function startEditMode[\s\S]*disableAutoDemoTimer\(\)/);
		assert.match(text, /function startEditMode[\s\S]*clearIdleDemoTimer\(\)/);
		assert.match(text, /function startEditMode[\s\S]*stopPlayTicker\(\)/);
	});

	it("attract paths refuse PLAY_EDIT / PLAY_TEST", () => {
		const demo = fs.readFileSync(path.join(ROOT, "lodeRunner.demo.js"), "utf8");
		const main = fs.readFileSync(path.join(ROOT, "lodeRunner.main.js"), "utf8");
		assert.match(demo, /function countAutoDemoTimer[\s\S]*PLAY_EDIT[\s\S]*PLAY_TEST/);
		assert.match(main, /function checkIdleTime[\s\S]*PLAY_EDIT[\s\S]*PLAY_TEST/);
		assert.match(main, /function showCoverPage[\s\S]*PLAY_EDIT[\s\S]*PLAY_TEST/);
	});

	it("exposes beforeunload guard helpers for dirty edit maps", () => {
		const text = fs.readFileSync(path.join(ROOT, "lodeRunner.edit.js"), "utf8");
		assert.match(text, /function editHasUnsavedChanges/);
		assert.match(text, /beforeunload/);
		assert.match(text, /function installEditUnloadGuard/);
		assert.match(text, /function leaveEditMode/);
	});

	it("edit.js has no createjs (owned Canvas2D editor)", () => {
		const text = fs.readFileSync(path.join(ROOT, "lodeRunner.edit.js"), "utf8");
		assert.doesNotMatch(text, /createjs\./);
		assert.match(text, /canvasOverlay/);
		assert.match(text, /CanvasShape/);
		assert.match(text, /CanvasBitmap/);
		assert.match(text, /makeGlyphText/);
	});
});
