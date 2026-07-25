"use strict";

/**
 * Characterization + behavior: owned Canvas2D display objects
 * (lodeRunner.canvasObj.js) and the misc.js CreateJS peel.
 */

const { describe, it } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { ROOT, loadScripts } = require("./helpers/loadScripts.js");

describe("misc.js CreateJS peel (characterization)", () => {
	it("misc.js has no createjs", () => {
		const text = fs.readFileSync(path.join(ROOT, "lodeRunner.misc.js"), "utf8");
		assert.doesNotMatch(text, /createjs\./);
		assert.match(text, /CanvasText/);
		assert.match(text, /canvasOverlay/);
	});

	it("canvasObj.js has no createjs and is wired into both HTML shells", () => {
		const text = fs.readFileSync(path.join(ROOT, "lodeRunner.canvasObj.js"), "utf8");
		assert.doesNotMatch(text, /createjs\./);
		for (const shell of ["lodeRunner.html", "test/golden-browser.html"]) {
			const html = fs.readFileSync(path.join(ROOT, shell), "utf8");
			assert.match(html, /src="lodeRunner\.canvasObj\.js"/, shell);
		}
	});

	it("glyphFont.js is createjs-free and wired into both HTML shells", () => {
		const text = fs.readFileSync(path.join(ROOT, "lodeRunner.glyphFont.js"), "utf8");
		assert.doesNotMatch(text, /createjs\./);
		assert.match(text, /function makeGlyphAtlas/);
		assert.match(text, /function charToGlyphName/);
		for (const shell of ["lodeRunner.html", "test/golden-browser.html"]) {
			const html = fs.readFileSync(path.join(ROOT, shell), "utf8");
			assert.match(html, /src="lodeRunner\.glyphFont\.js"/, shell);
		}
	});

	it("hiscore.js dropped its createjs Stage/Sprite/Shape (Ticker facade stays)", () => {
		const text = fs.readFileSync(path.join(ROOT, "lodeRunner.hiscore.js"), "utf8");
		assert.doesNotMatch(text, /createjs\.Stage/);
		assert.doesNotMatch(text, /createjs\.Sprite/);
		assert.doesNotMatch(text, /createjs\.Shape/);
		assert.doesNotMatch(text, /createjs\.Shadow/);
		// the only createjs left is the Ticker facade
		const refs = text.match(/createjs\.\w+/g) || [];
		assert.ok(refs.every((r) => r === "createjs.Ticker"), `unexpected createjs refs: ${refs}`);
		// no scoreStage / canvas2 / drawText render coupling remains
		assert.doesNotMatch(text, /scoreStage/);
		assert.doesNotMatch(text, /canvas2/);
		assert.match(text, /ScoreSurface/);
		assert.match(text, /CanvasGlyph/);
	});

	it("all repaints funnel through the stagePresent seam", () => {
		// the one mainStage.update() left in source is inside stagePresent()
		const files = fs
			.readdirSync(ROOT)
			.filter((f) => /^lodeRunner.*\.js$/.test(f));
		let updates = 0;
		for (const file of files) {
			const text = fs.readFileSync(path.join(ROOT, file), "utf8");
			updates += (text.match(/mainStage\.update\(\)/g) || []).length;
		}
		assert.equal(updates, 1, "expected the only mainStage.update() to live in stagePresent()");
		const main = fs.readFileSync(path.join(ROOT, "lodeRunner.main.js"), "utf8");
		assert.match(main, /function stagePresent\(\)\s*\{\s*mainStage\.update\(\);\s*canvasOverlay\.paint/);
	});
});

// fake 2D context that records calls, enough for paint()/draw()
function makeRecordingCtx() {
	const calls = [];
	const ctx = {
		font: "",
		fillStyle: "",
		textAlign: "",
		textBaseline: "",
		globalAlpha: 1,
		shadowColor: "",
		shadowOffsetX: 0,
		shadowOffsetY: 0,
		shadowBlur: 0,
		save: () => calls.push(["save"]),
		restore: () => calls.push(["restore"]),
		setTransform: (a, b, c, d, e, f) => calls.push(["setTransform", a, b, c, d, e, f]),
		translate: (x, y) => calls.push(["translate", x, y]),
		scale: (sx, sy) => calls.push(["scale", sx, sy]),
		fillText: (t, x, y) => calls.push(["fillText", t, x, y]),
		measureText: (t) => ({
			width: t.length * 10,
			fontBoundingBoxAscent: 40,
			fontBoundingBoxDescent: 10,
		}),
	};
	return { ctx, calls };
}

function loadCanvasObj() {
	const ctx = loadScripts(["lodeRunner.canvasObj.js"]);
	// no DOM in Node: inject the measurement context directly
	ctx.CanvasText._measureCtx = makeRecordingCtx().ctx;
	return ctx;
}

describe("CanvasObject behavior", () => {
	it("CanvasText bounds honor textAlign", () => {
		const g = loadCanvasObj();
		const t = new g.CanvasText("HELLO", "bold 48px Helvetica", "#FF2020"); // width 50
		// field compare: vm-realm object literals fail deepStrictEqual on prototype
		const b = t.getBounds();
		assert.equal(b.x, 0);
		assert.equal(b.y, 0);
		assert.equal(b.width, 50);
		assert.equal(b.height, 50);
		t.textAlign = "center";
		assert.equal(t.getBounds().x, -25);
		t.textAlign = "right";
		assert.equal(t.getBounds().x, -50);
	});

	it("contains() hit-tests in parent space through position and scale", () => {
		const g = loadCanvasObj();
		const t = new g.CanvasText("HELLO", "48px Helvetica", "#fff"); // local bounds 50x50 at origin
		t.x = 100;
		t.y = 200;
		assert.equal(t.contains(100, 200), true);
		assert.equal(t.contains(149, 249), true);
		assert.equal(t.contains(150, 200), false);
		assert.equal(t.contains(99, 200), false);
		t.scaleX = t.scaleY = 2;
		assert.equal(t.contains(199, 299), true);
		assert.equal(t.contains(201, 200), false);
	});

	it("paint() applies transform + alpha and skips hidden objects", () => {
		const g = loadCanvasObj();
		const { ctx, calls } = makeRecordingCtx();
		const t = new g.CanvasText("HI", "48px Helvetica", "#fff");
		t.x = 10;
		t.y = 20;
		t.scaleX = t.scaleY = 1.2;
		t.alpha = 0.5;
		t.paint(ctx);
		assert.deepEqual(calls, [
			["save"],
			["translate", 10, 20],
			["scale", 1.2, 1.2],
			["fillText", "HI", 0, 0],
			["restore"],
		]);
		assert.equal(ctx.globalAlpha, 0.5);

		calls.length = 0;
		t.alpha = 0;
		t.paint(ctx);
		t.alpha = 1;
		t.visible = false;
		t.paint(ctx);
		assert.deepEqual(calls, []);
	});

	it("canvasOverlay add/remove/clear/paint", () => {
		const g = loadCanvasObj();
		const { ctx, calls } = makeRecordingCtx();
		const a = new g.CanvasText("A", "48px Helvetica", "#fff");
		const b = new g.CanvasText("B", "48px Helvetica", "#fff");
		g.canvasOverlay.add(a);
		g.canvasOverlay.add(b);
		g.canvasOverlay.add(a); // re-add moves, no duplicate
		g.canvasOverlay.paint(ctx);
		const drawn = calls.filter((c) => c[0] === "fillText").map((c) => c[1]);
		assert.deepEqual(drawn, ["B", "A"]);
		// paint anchors to identity so objects never inherit a stray transform
		assert.deepEqual(calls[1], ["setTransform", 1, 0, 0, 1, 0, 0]);

		// empty overlay paints nothing (no save/setTransform churn)
		g.canvasOverlay.clear();
		const before = calls.length;
		g.canvasOverlay.paint(ctx);
		assert.equal(calls.length, before);
		g.canvasOverlay.add(a);
		g.canvasOverlay.add(b);

		g.canvasOverlay.remove(b);
		assert.equal(g.canvasOverlay.objs.length, 1);
		assert.equal(g.canvasOverlay.objs[0], a);
		g.canvasOverlay.remove(b); // absent remove is a no-op
		assert.equal(g.canvasOverlay.objs.length, 1);
		g.canvasOverlay.clear();
		assert.equal(g.canvasOverlay.objs.length, 0);
	});
});
