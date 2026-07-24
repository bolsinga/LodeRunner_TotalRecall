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
	it("colorTheme.js has no Stage / cache; still returns createjs.Bitmap", () => {
		const text = fs.readFileSync(path.join(ROOT, "lodeRunner.colorTheme.js"), "utf8");
		assert.doesNotMatch(text, /createjs\.Stage/);
		assert.doesNotMatch(text, /\.cache\s*\(/);
		assert.doesNotMatch(text, /\.uncache\s*\(/);
		assert.match(text, /willReadFrequently/);
		assert.match(text, /getImageData/);
		assert.match(text, /putImageData/);
		assert.match(text, /createjs\.Bitmap/);
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

	it("menu.js level2Bitmap delegates to levelMapToBitmap; no Container.cache flatten", () => {
		const text = fs.readFileSync(path.join(ROOT, "lodeRunner.menu.js"), "utf8");
		const level2Bodies = [...text.matchAll(/function level2Bitmap\([^)]*\)\s*\{([\s\S]*?)\n\t\t\}/g)]
			.map((m) => m[1]);
		// Fallback for restoreDialog's indent (one tab less on closing brace)
		if (level2Bodies.length < 2) {
			level2Bodies.push(
				...[...text.matchAll(/function level2Bitmap\([^)]*\)\s*\{([\s\S]*?)\n\t\}/g)].map((m) => m[1])
			);
		}
		assert.ok(level2Bodies.length >= 2, `expected 2 level2Bitmap bodies, got ${level2Bodies.length}`);
		for (const body of level2Bodies) {
			assert.match(body, /levelMapToBitmap/);
			assert.doesNotMatch(body, /createjs\.Container/);
			assert.doesNotMatch(body, /\.cache\s*\(/);
		}
		assert.match(
			fs.readFileSync(path.join(ROOT, "lodeRunner.html"), "utf8"),
			/lodeRunner\.levelThumb\.js/
		);
	});
});
