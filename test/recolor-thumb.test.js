"use strict";

/**
 * Characterization: colorTheme recolor off CreateJS Stage + level thumbnail flatten.
 */

const { describe, it } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { ROOT } = require("./helpers/loadScripts.js");

describe("colorTheme Stage peel (characterization)", () => {
	it("colorTheme.js is createjs-free; returns CanvasBitmap", () => {
		const text = fs.readFileSync(path.join(ROOT, "lodeRunner.colorTheme.js"), "utf8");
		assert.doesNotMatch(text, /createjs\./);
		assert.doesNotMatch(text, /\.cache\s*\(/);
		assert.doesNotMatch(text, /\.uncache\s*\(/);
		assert.match(text, /willReadFrequently/);
		assert.match(text, /getImageData/);
		assert.match(text, /putImageData/);
		assert.match(text, /CanvasBitmap/);
		assert.match(text, /function getThemeBitmapImage/);
	});
});

describe("level thumbnail flatten (characterization)", () => {
	it("levelThumb.js provides renderLevelMapToCanvas / levelMapToBitmap", () => {
		const text = fs.readFileSync(path.join(ROOT, "lodeRunner.levelThumb.js"), "utf8");
		assert.match(text, /function renderLevelMapToCanvas/);
		assert.match(text, /function levelMapToBitmap/);
		assert.match(text, /drawSpriteAnimFrame/);
		assert.doesNotMatch(text, /createjs\.Container/);
		assert.doesNotMatch(text, /\.cache\s*\(/);
	});

	it("menu.js no longer flattens thumbs; levelThumb.js is wired in HTML", () => {
		const menu = fs.readFileSync(path.join(ROOT, "lodeRunner.menu.js"), "utf8");
		assert.doesNotMatch(menu, /function level2Bitmap/);
		assert.doesNotMatch(menu, /createjs\.Container/);
		assert.match(
			fs.readFileSync(path.join(ROOT, "lodeRunner.html"), "utf8"),
			/lodeRunner\.levelThumb\.js/
		);
	});
});
