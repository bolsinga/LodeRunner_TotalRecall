"use strict";

/**
 * Characterization: image asset cache (CreateJS PreloadJS replacement).
 */

const { describe, it, beforeEach } = require("node:test");
const assert = require("node:assert/strict");
const { loadScripts } = require("./helpers/loadScripts.js");

function installFakeImageLoader(ctx) {
	const loads = [];
	ctx.Image = function FakeImage() {
		this.src = "";
		this.complete = false;
		this.decode = async () => {};
		Object.defineProperty(this, "src", {
			get() {
				return this._src;
			},
			set(v) {
				this._src = v;
				loads.push(this);
				queueMicrotask(() => {
					this.complete = true;
					if (typeof this.onload === "function") this.onload();
				});
			},
		});
		this._src = "";
	};
	ctx.fetch = async (url) => {
		if (String(url).includes("missing")) return { ok: false, status: 404 };
		return { ok: true, status: 200 };
	};
	return { loads };
}

describe("assetLoadManifest", () => {
	let ctx;

	beforeEach(() => {
		ctx = loadScripts(["lodeRunner.assets.js"]);
		installFakeImageLoader(ctx);
	});

	it("stores HTMLImageElement results and exposes them via preload.getResult", async () => {
		const progress = [];
		const files = [];
		await ctx.assetLoadManifest(
			[
				{ id: "signet", src: "image/signet.png" },
				{ id: "eraser", src: "image/eraser.png" },
			],
			{
				onProgress: (loaded, total) => progress.push([loaded, total]),
				onFileLoad: (e) => files.push(e.item.id),
			}
		);
		assert.equal(ctx.preload.getResult("signet")._src, "image/signet.png");
		assert.equal(ctx.assetGetResult("eraser")._src, "image/eraser.png");
		assert.deepEqual(files.sort(), ["eraser", "signet"]);
		assert.deepEqual(progress[0], [0, 2]);
		assert.deepEqual(progress[progress.length - 1], [2, 2]);
	});

	it("warm-caches .cur files without storing an image result", async () => {
		await ctx.assetLoadManifest([{ id: "openHand", src: "cursor/openhand.cur" }]);
		assert.equal(ctx.preload.getResult("openHand"), null);
	});

	it("continues after a failed item (PreloadJS stopOnError=false style)", async () => {
		let errors = 0;
		await ctx.assetLoadManifest(
			[
				{ id: "bad", src: "cursor/missing.cur" },
				{ id: "ok", src: "image/ok.png" },
			],
			{ onError: () => { errors++; } }
		);
		assert.equal(errors, 1);
		assert.ok(ctx.preload.getResult("ok"));
	});
});
