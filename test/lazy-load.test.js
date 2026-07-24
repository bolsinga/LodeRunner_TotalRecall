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

	it("playVersionInfo in playVersion.js wires scripts + levelCount (no verData)", () => {
		const registry = fs.readFileSync(path.join(ROOT, "lodeRunner.playVersion.js"), "utf8");
		const menu = fs.readFileSync(path.join(ROOT, "lodeRunner.menu.js"), "utf8");
		const html = fs.readFileSync(path.join(ROOT, "lodeRunner.html"), "utf8");
		assert.match(html, /lodeRunner\.playVersion\.js/);
		assert.match(registry, /function ensurePlayVersionLoaded/);
		assert.match(registry, /levelCount:\s*150/);
		assert.match(registry, /script:\s*"lodeRunner\.v\.professional\.js"/);
		assert.match(registry, /demoScript:\s*"lodeRunner\.wData\.3\.js"/);
		assert.doesNotMatch(registry, /\.verData\b/);
		assert.doesNotMatch(menu, /function ensurePlayVersionLoaded/);
		assert.doesNotMatch(menu, /var playVersionInfo\s*=/);
		assert.match(menu, /function initMenuVariable/);
		assert.match(menu, /var gameVersionMenuList\s*=/);
	});
});
