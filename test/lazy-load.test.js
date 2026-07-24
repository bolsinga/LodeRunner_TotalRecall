"use strict";

/**
 * Characterization: lazy-load wiring for level/demo packs.
 */

const { describe, it } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { ROOT } = require("./helpers/loadScripts.js");

describe("lazy pack wiring (characterization)", () => {
	it("HTML critical path includes classic + CreateJS, not wData or non-classic packs", () => {
		const html = fs.readFileSync(path.join(ROOT, "lodeRunner.html"), "utf8");
		assert.match(html, /easeljs/);
		assert.match(html, /lodeRunner\.v\.classic\.js/);
		assert.match(html, /lodeRunner\.lazyLoad\.js/);
		assert.doesNotMatch(html, /lodeRunner\.wData\.js/);
		assert.doesNotMatch(html, /lodeRunner\.v\.professional\.js/);
		assert.doesNotMatch(html, /lodeRunner\.v\.revenge\.js/);
		assert.doesNotMatch(html, /lodeRunner\.v\.fanBookMod\.js/);
		assert.doesNotMatch(html, /lodeRunner\.v\.championship\.js/);
		assert.doesNotMatch(html, /lodeRunner\.wData\.[1-5]\.js/);
	});

	it("split demo packs and lazy level packs exist on disk", () => {
		for (let i = 1; i <= 5; i++) {
			assert.ok(fs.existsSync(path.join(ROOT, `lodeRunner.wData.${i}.js`)));
		}
		assert.ok(fs.existsSync(path.join(ROOT, "lodeRunner.v.professional.js")));
		assert.ok(fs.existsSync(path.join(ROOT, "lodeRunner.v.championship.js")));
		assert.ok(fs.existsSync(path.join(ROOT, "lodeRunner.v.revenge.js")));
		assert.ok(fs.existsSync(path.join(ROOT, "lodeRunner.v.fanBookMod.js")));
		assert.ok(fs.existsSync(path.join(ROOT, "lodeRunner.lazyLoad.js")));
		assert.equal(fs.existsSync(path.join(ROOT, "lodeRunner.wData.js")), false);
	});

	it("playVersionInfo in menu.js wires scripts + levelCount (no verData)", () => {
		const menu = fs.readFileSync(path.join(ROOT, "lodeRunner.menu.js"), "utf8");
		assert.match(menu, /function ensurePlayVersionLoaded/);
		assert.match(menu, /levelCount:\s*150/);
		assert.match(menu, /script:\s*"lodeRunner\.v\.professional\.js"/);
		assert.match(menu, /demoScript:\s*"lodeRunner\.wData\.3\.js"/);
		assert.doesNotMatch(menu, /\.verData\b/);
	});
});
