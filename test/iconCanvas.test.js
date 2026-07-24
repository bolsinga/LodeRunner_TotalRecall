"use strict";

/**
 * Characterization: side-chrome IconCanvas (CreateJS Stage replacement for icons).
 */

const { describe, it, beforeEach } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { ROOT, loadScripts } = require("./helpers/loadScripts.js");

function installFakeDom(ctx) {
	const appended = [];
	ctx.mouseOverBGColor = "#fefef1";
	ctx.document = {
		createElement(tag) {
			assert.equal(tag, "canvas");
			const listeners = Object.create(null);
			const canvas = {
				id: "",
				width: 0,
				height: 0,
				style: {},
				addEventListener(type, fn) {
					(listeners[type] || (listeners[type] = [])).push(fn);
				},
				removeEventListener(type, fn) {
					const list = listeners[type] || [];
					const i = list.indexOf(fn);
					if (i >= 0) list.splice(i, 1);
				},
				getContext() {
					return {
						clearRect() {},
						fillRect() {},
						drawImage() {},
						fillStyle: "",
						globalAlpha: 1,
					};
				},
				_fire(type) {
					for (const fn of listeners[type] || []) fn();
				},
			};
			return canvas;
		},
		body: {
			appendChild(el) {
				appended.push(el);
			},
		},
	};
	return { appended };
}

function fakeBitmap(w, h) {
	return {
		image: { naturalWidth: w, naturalHeight: h, width: w, height: h },
		getBounds() {
			return { width: w, height: h };
		},
	};
}

describe("createIconCanvas", () => {
	let ctx;
	let dom;

	beforeEach(() => {
		ctx = loadScripts(["lodeRunner.iconCanvas.js"]);
		dom = installFakeDom(ctx);
	});

	it("appends a positioned canvas and draws via setBitmap/setAlpha", () => {
		const icon = ctx.createIconCanvas({
			id: "test_icon",
			width: 40,
			height: 40,
			left: 10,
			top: 20,
			border: 4,
			scale: 2,
		});
		assert.equal(dom.appended.length, 1);
		assert.equal(icon.canvas.id, "test_icon");
		assert.equal(icon.canvas.style.left, "10px");
		assert.equal(icon.canvas.style.top, "20px");
		icon.setBitmap(fakeBitmap(16, 16));
		icon.setAlpha(1);
		icon.setHovered(true);
		assert.equal(icon.canvas.style.cursor, undefined);
		icon.setCursor("pointer");
		assert.equal(icon.canvas.style.cursor, "pointer");
	});

	it("enablePointer routes mouseover/out/click; disablePointer removes them", () => {
		const icon = ctx.createIconCanvas({
			id: "hit",
			width: 20,
			height: 20,
			left: 0,
			top: 0,
			border: 2,
			scale: 1,
		});
		const counts = { over: 0, out: 0, click: 0 };
		icon.enablePointer({
			over: () => counts.over++,
			out: () => counts.out++,
			click: () => counts.click++,
		});
		icon.canvas._fire("mouseover");
		icon.canvas._fire("mouseout");
		icon.canvas._fire("click");
		assert.deepEqual(counts, { over: 1, out: 1, click: 1 });
		icon.disablePointer();
		icon.canvas._fire("click");
		assert.equal(counts.click, 1);
		assert.equal(icon.canvas.style.cursor, "default");
	});

	it("iconBitmapNaturalSize reads createjs.Bitmap getBounds", () => {
		const size = ctx.iconBitmapNaturalSize(fakeBitmap(32, 24));
		assert.equal(size.width, 32);
		assert.equal(size.height, 24);
	});
});

describe("iconClass CreateJS peel (characterization)", () => {
	it("iconClass.js has no Stage/Container/Shape/enableMouseOver", () => {
		const text = fs.readFileSync(path.join(ROOT, "lodeRunner.iconClass.js"), "utf8");
		assert.doesNotMatch(text, /createjs\.Stage/);
		assert.doesNotMatch(text, /createjs\.Container/);
		assert.doesNotMatch(text, /createjs\.Shape/);
		assert.doesNotMatch(text, /enableMouseOver/);
	});

	it("HTML loads iconCanvas.js before iconClass.js", () => {
		const html = fs.readFileSync(path.join(ROOT, "lodeRunner.html"), "utf8");
		const canvasIdx = html.indexOf("lodeRunner.iconCanvas.js");
		const classIdx = html.indexOf("lodeRunner.iconClass.js");
		assert.ok(canvasIdx >= 0 && classIdx > canvasIdx);
	});
});
