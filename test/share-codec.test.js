"use strict";

/**
 * Characterization: share zip/unzip codec round-trip and invalid checksum handling.
 */

const { describe, it } = require("node:test");
const assert = require("node:assert/strict");
const {
	loadShareCodec,
	loadLevelPack,
} = require("./helpers/loadScripts.js");

describe("share zip/unzip (characterization)", () => {
	const ctx = loadShareCodec();

	it("round-trips classic levels 1–5", () => {
		const classic = loadLevelPack("lodeRunner.v.classic.js", "classicData");
		for (let i = 0; i < 5; i++) {
			const level = classic[i];
			const zipped = ctx.zipLevelMap(level);
			assert.ok(typeof zipped === "string" && zipped.length > 0);
			const unzipped = ctx.unzipLevelMap(zipped);
			assert.equal(unzipped, level, `classic level ${i + 1}`);
		}
	});

	it("round-trips one level from each pack", () => {
		const samples = [
			["lodeRunner.v.classic.js", "classicData", 0],
			["lodeRunner.v.professional.js", "proData", 0],
			["lodeRunner.v.revenge.js", "revengeData", 0],
			["lodeRunner.v.fanBookMod.js", "fanBookData", 0],
			["lodeRunner.v.championship.js", "championData", 0],
		];
		for (const [file, varName, idx] of samples) {
			const level = loadLevelPack(file, varName)[idx];
			assert.equal(ctx.unzipLevelMap(ctx.zipLevelMap(level)), level, varName);
		}
	});

	it("rejects corrupted checksum (returns empty string)", () => {
		const classic = loadLevelPack("lodeRunner.v.classic.js", "classicData");
		const zipped = ctx.zipLevelMap(classic[0]);
		// Last char is the checksum token (A–Z / a–z). Flip it to a different letter.
		const last = zipped.charAt(zipped.length - 1);
		const badLast = last === "A" ? "B" : "A";
		const corrupted = zipped.slice(0, -1) + badLast;
		assert.equal(ctx.unzipLevelMap(corrupted), "");
	});

	it("rejects invalid tile characters in zip stream", () => {
		assert.equal(ctx.unzipLevelMap("!@#"), "");
	});

	it("getShareChecksum is stable for a fixed string", () => {
		// Characterization snapshot of current checksum encoding.
		assert.equal(ctx.getShareChecksum(""), "A"); // 0 → 1 → 'A'
		assert.equal(ctx.getShareChecksum("1"), "R"); // 49 → (49&0x1F)+1 = 18 → 'R'
		assert.equal(
			ctx.getShareChecksum("abc"),
			ctx.value2OutValue(((97 + 98 + 99) & 0x1f) + 1)
		);
	});
});
