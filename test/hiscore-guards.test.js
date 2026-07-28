"use strict";

/**
 * Name-entry ticker leak guards: abort on teardown; blink must not stagePresent.
 */

const { describe, it } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { ROOT } = require("./helpers/loadScripts.js");

describe("hiscore name-entry leak guards", () => {
	it("exposes abortActiveNameInput and installs cancel from inputString", () => {
		const text = fs.readFileSync(path.join(ROOT, "lodeRunner.hiscore.js"), "utf8");
		assert.match(text, /function abortActiveNameInput/);
		assert.match(text, /cancelActiveNameInput\s*=\s*abortInput/);
		assert.match(text, /function abortInput/);
	});

	it("inputTick uses overlayPresent (no stagePresent / no sprite double-advance)", () => {
		const text = fs.readFileSync(path.join(ROOT, "lodeRunner.hiscore.js"), "utf8");
		const tick = text.match(/function inputTick\(\)\s*\{[^}]+\}/);
		assert.ok(tick, "inputTick present");
		assert.match(tick[0], /overlayPresent/);
		assert.doesNotMatch(tick[0], /stagePresent/);
		const main = fs.readFileSync(path.join(ROOT, "lodeRunner.main.js"), "utf8");
		assert.match(main, /function overlayPresent/);
	});

	it("showCoverPage and startGame abort active name input", () => {
		const main = fs.readFileSync(path.join(ROOT, "lodeRunner.main.js"), "utf8");
		assert.match(main, /function showCoverPage[\s\S]*?abortActiveNameInput\(\)/);
		assert.match(main, /function startGame[\s\S]*?abortActiveNameInput\(\)/);
		assert.match(main, /function overlayPresent/);
	});
});
