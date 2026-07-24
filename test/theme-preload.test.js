"use strict";

/**
 * Characterization: active-theme-only asset manifests.
 */

const { describe, it } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { ROOT, loadScripts } = require("./helpers/loadScripts.js");

describe("theme asset manifests (characterization)", () => {
	const ctx = loadScripts(["lodeRunner.def.js", "lodeRunner.themeAssets.js"]);

	it("APPLE2 manifest is 17 images + 8 sounds, no C64 assets", () => {
		const list = ctx.buildThemeAssetManifest(
			ctx.THEME_APPLE2,
			"image/Theme/",
			"sound/Theme/",
			"?v"
		);
		assert.equal(list.length, 25);
		assert.ok(list.every((e) => !String(e.id).includes("C64")));
		assert.ok(list.every((e) => !String(e.src).includes("/C64/")));
		assert.ok(list.some((e) => e.id === "runnerAPPLE2"));
		assert.ok(list.some((e) => e.id === "fallAPPLE2"));
		assert.equal(list.some((e) => e.id === "goldFinish1"), false);
	});

	it("C64 manifest adds goldFinish1-6", () => {
		const list = ctx.buildThemeAssetManifest(
			ctx.THEME_C64,
			"image/Theme/",
			"sound/Theme/",
			"?v"
		);
		assert.equal(list.length, 31);
		assert.ok(list.every((e) => !String(e.src).includes("/APPLE2/")));
		for (let i = 1; i <= 6; i++) {
			assert.ok(list.some((e) => e.id === "goldFinish" + i));
		}
	});

	it("otherThemeName flips between APPLE2 and C64", () => {
		assert.equal(ctx.otherThemeName(ctx.THEME_APPLE2), ctx.THEME_C64);
		assert.equal(ctx.otherThemeName(ctx.THEME_C64), ctx.THEME_APPLE2);
	});

	it("preload.js wires ensureThemeLoaded; html includes themeAssets.js", () => {
		const preload = fs.readFileSync(path.join(ROOT, "lodeRunner.preload.js"), "utf8");
		const html = fs.readFileSync(path.join(ROOT, "lodeRunner.html"), "utf8");
		assert.match(preload, /function ensureThemeLoaded/);
		assert.match(preload, /buildThemeAssetManifest\(curTheme/);
		assert.match(html, /lodeRunner\.themeAssets\.js/);
		assert.doesNotMatch(
			preload,
			/themeImagePath \+ THEME_APPLE2[\s\S]*themeImagePath \+ THEME_C64/
		);
	});
});
