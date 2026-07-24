"use strict";

/**
 * Characterization: info DOM overlay + event-driven edit input (no CreateJS).
 */

const { describe, it } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { ROOT } = require("./helpers/loadScripts.js");

describe("info overlay CreateJS peel (characterization)", () => {
	it("info.js has no createjs / enableMouseOver", () => {
		const text = fs.readFileSync(path.join(ROOT, "lodeRunner.info.js"), "utf8");
		assert.doesNotMatch(text, /createjs\./);
		assert.doesNotMatch(text, /enableMouseOver/);
		assert.match(text, /info_overlay/);
		assert.match(text, /function infoMenuClass/);
	});
});

describe("edit pointer input (characterization)", () => {
	it("edit.js does not force setFPS(60) or register editTick on Ticker", () => {
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

	it("call sites use startEditInput / stopEditInput", () => {
		for (const file of ["lodeRunner.iconClass.js", "lodeRunner.colorTheme.js", "lodeRunner.edit.js"]) {
			const text = fs.readFileSync(path.join(ROOT, file), "utf8");
			assert.doesNotMatch(text, /startEditTicker|stopEditTicker/);
		}
	});
});
