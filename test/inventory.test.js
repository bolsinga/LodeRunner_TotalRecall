"use strict";

/**
 * Characterization: root script inventory / wiring.
 */

const { describe, it } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { ROOT, loadScripts } = require("./helpers/loadScripts.js");

const LAZY_ONLY = new Set([
	"lodeRunner.v.professional.js",
	"lodeRunner.v.championship.js",
	"lodeRunner.v.revenge.js",
	"lodeRunner.v.fanBookMod.js",
	"lodeRunner.wData.1.js",
	"lodeRunner.wData.2.js",
	"lodeRunner.wData.3.js",
	"lodeRunner.wData.4.js",
	"lodeRunner.wData.5.js",
]);

describe("script inventory (characterization)", () => {
	it("every root lodeRunner*.js is in HTML or the known lazy set", () => {
		const html = fs.readFileSync(path.join(ROOT, "lodeRunner.html"), "utf8");
		const rootFiles = fs
			.readdirSync(ROOT)
			.filter((f) => /^lodeRunner.*\.js$/.test(f));
		const missing = [];
		for (const file of rootFiles) {
			const inHtml = html.includes(`src="${file}"`) || html.includes(`src='${file}'`);
			if (!inHtml && !LAZY_ONLY.has(file)) missing.push(file);
		}
		assert.deepEqual(missing, [], `unwired scripts: ${missing.join(", ")}`);
	});

	it("registry levelCount matches actual pack lengths", () => {
		const registry = fs.readFileSync(path.join(ROOT, "lodeRunner.playVersion.js"), "utf8");
		const ctx = loadScripts([
			"lodeRunner.v.classic.js",
			"lodeRunner.v.professional.js",
			"lodeRunner.v.revenge.js",
			"lodeRunner.v.fanBookMod.js",
			"lodeRunner.v.championship.js",
		]);
		const re = /globalName:\s*"(\w+)",[^}]*levelCount:\s*(\d+)/g;
		let m, entries = 0;
		while ((m = re.exec(registry))) {
			assert.equal(ctx[m[1]].length, Number(m[2]), m[1]);
			entries++;
		}
		assert.equal(entries, 5);
	});

	it("orphan demoData2 is gone", () => {
		assert.equal(fs.existsSync(path.join(ROOT, "lodeRunner.demoData2.js")), false);
	});

	it("dead UID surface is gone from sources", () => {
		const files = [
			"lodeRunner.main.js",
			"lodeRunner.storage.js",
			"lodeRunner.def.js",
		];
		for (const file of files) {
			const text = fs.readFileSync(path.join(ROOT, file), "utf8");
			assert.doesNotMatch(text, /\bplayerUId\b/);
			assert.doesNotMatch(text, /\bplayerUid\b/);
			assert.doesNotMatch(text, /\bgetUid\b/);
			assert.doesNotMatch(text, /\bsetUid\b/);
			assert.doesNotMatch(text, /\bSTORAGE_UID\b/);
		}
	});
});
