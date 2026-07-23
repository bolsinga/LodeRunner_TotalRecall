"use strict";

/**
 * Characterization: setStorage / getStorage / clearStorage with a mock localStorage.
 */

const { describe, it } = require("node:test");
const assert = require("node:assert/strict");
const {
	makeMemoryLocalStorage,
	loadStorageCore,
} = require("./helpers/loadScripts.js");

describe("storageCore (characterization)", () => {
	it("set/get/clear round-trip JSON strings", () => {
		const ls = makeMemoryLocalStorage();
		const ctx = loadStorageCore(ls);

		ctx.setStorage("loderunner_player", JSON.stringify({ n: "Test" }));
		assert.equal(ctx.getStorage("loderunner_player"), '{"n":"Test"}');
		assert.deepEqual(JSON.parse(ctx.getStorage("loderunner_player")), { n: "Test" });

		ctx.clearStorage("loderunner_player");
		assert.equal(ctx.getStorage("loderunner_player"), null);
	});

	it("getStorage returns null for missing keys", () => {
		const ls = makeMemoryLocalStorage();
		const ctx = loadStorageCore(ls);
		assert.equal(ctx.getStorage("nope"), null);
	});

	it("propagates QuotaExceededError from setItem (characterization)", () => {
		const ls = makeMemoryLocalStorage();
		ls._throwQuota = true;
		const ctx = loadStorageCore(ls);
		assert.throws(() => ctx.setStorage("k", "v"), { name: "QuotaExceededError" });
	});

	it("no-ops when localStorage is undefined", () => {
		const ctx = loadStorageCore(undefined);
		// typeof undefined == 'undefined' → skip; get returns null
		assert.doesNotThrow(() => ctx.setStorage("k", "v"));
		assert.equal(ctx.getStorage("k"), null);
		assert.doesNotThrow(() => ctx.clearStorage("k"));
	});
});
