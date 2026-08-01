"use strict";

/**
 * Phase 2: owned SpriteSheet / GameSprite (EaselJS 0.7.1-compatible tables).
 */

const { describe, it } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { ROOT, loadScripts } = require("./helpers/loadScripts.js");

describe("sprite migration (characterization)", () => {
	it("preload/main/runner/guard no longer construct createjs.Sprite(Sheet)", () => {
		for (const file of [
			"lodeRunner.preload.js",
			"lodeRunner.main.js",
			"lodeRunner.runner.js",
			"lodeRunner.guard.js"
		]) {
			const text = fs.readFileSync(path.join(ROOT, file), "utf8");
			assert.doesNotMatch(text, /new createjs\.SpriteSheet/, file);
			assert.doesNotMatch(text, /new createjs\.Sprite\b/, file);
		}
	});

	it("sprite.js is createjs-free CanvasObject and wired into the HTML shell", () => {
		const text = fs.readFileSync(path.join(ROOT, "lodeRunner.sprite.js"), "utf8");
		assert.match(text, /function makeSpriteSheet/);
		assert.match(text, /function GameSprite/);
		assert.match(text, /CanvasObject\.call/);
		assert.doesNotMatch(text, /createjs\./);
		const html = fs.readFileSync(path.join(ROOT, "lodeRunner.html"), "utf8");
		assert.match(html, /src="lodeRunner\.sprite\.js"/);
	});
});

describe("makeSpriteSheet / GameSprite (behavior)", () => {
	const ctx = loadScripts(["lodeRunner.canvasObj.js", "lodeRunner.sprite.js"]);

	it("parses range + object animations like CreateJS 0.7.1", () => {
		const img = { width: 120, height: 44 }; // 3 frames of 40x44
		const sheet = ctx.makeSpriteSheet({
			images: [img],
			frames: { width: 40, height: 44, regX: 0, regY: 0 },
			animations: {
				run: [0, 2, "run", 0.65],
				hold: 1,
				shake: { frames: [0, 1, 2], next: null, speed: 0.3 },
				dig: [0, 2, false, 0.68]
			}
		});
		assert.equal(sheet.getNumFrames(), 3);
		assert.equal(sheet.getAnimation("run").frames.join(","), "0,1,2");
		assert.equal(sheet.getAnimation("run").next, "run");
		assert.equal(sheet.getAnimation("run").speed, 0.65);
		assert.equal(sheet.getAnimation("hold").next, null);
		assert.equal(sheet.getAnimation("shake").next, null);
		assert.equal(sheet.getAnimation("dig").next, null);
		const f = sheet.getFrame(1);
		assert.equal(f.rect.x, 40);
		assert.equal(f.rect.width, 40);
	});

	it("constructor matches 0.7.1: starts playing without an extra play()", () => {
		const img = { width: 120, height: 44 };
		const sheet = ctx.makeSpriteSheet({
			images: [img],
			frames: { width: 40, height: 44 },
			animations: { run: [0, 2, "run", 0.65] }
		});
		const spr = new ctx.GameSprite(sheet, "run");
		assert.equal(spr.paused, false);
		assert.equal(spr.currentAnimation, "run");
		spr.advance(null);
		assert.equal(spr.currentAnimationFrame, 0.65);
	});

	it("constructor != null seeks frame 0 (stock truthiness would skip it)", () => {
		const img = { width: 120, height: 44 };
		const sheet = ctx.makeSpriteSheet({
			images: [img],
			frames: { width: 40, height: 44 },
			animations: { run: [0, 2, "run", 0.65] }
		});
		const spr = new ctx.GameSprite(sheet, 0);
		assert.equal(spr.paused, false);
		assert.equal(spr.currentFrame, 0);
		assert.equal(spr.currentAnimation, null);
	});

	it("advances speed frames per tick when framerate is 0", () => {
		const img = { width: 120, height: 44 };
		const sheet = ctx.makeSpriteSheet({
			images: [img],
			frames: { width: 40, height: 44 },
			animations: { run: [0, 2, "run", 0.65] }
		});
		const spr = new ctx.GameSprite(sheet, "run");
		assert.equal(spr.currentFrame, 0);
		spr.advance(null); // one tick, +0.65
		assert.equal(spr.currentAnimationFrame, 0.65);
		assert.equal(spr.currentFrame, 0);
		spr.advance(null);
		assert.ok(spr.currentAnimationFrame >= 1.3 - 1e-9);
		assert.equal(spr.currentFrame, 1);
	});

	it("fires animationend then pauses when next is null", () => {
		const img = { width: 80, height: 44 };
		const sheet = ctx.makeSpriteSheet({
			images: [img],
			frames: { width: 40, height: 44 },
			animations: { once: { frames: [0, 1], next: null, speed: 1 } }
		});
		const spr = new ctx.GameSprite(sheet, "once");
		let ended = 0;
		spr.addEventListener("animationend", function () { ended++; });
		spr.advance(null); // frame 1
		spr.advance(null); // past end
		assert.equal(ended, 1);
		assert.equal(spr.paused, true);
		assert.equal(spr.currentFrame, 1);
	});
});
