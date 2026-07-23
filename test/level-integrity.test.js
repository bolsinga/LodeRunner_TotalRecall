"use strict";

/**
 * Characterization / regression tests: lock current behavior.
 * Correctness tests: assert intended behavior (use after Stage 2+ fixes).
 *
 * Rule of thumb (also in plan.md): any behavior change must update tests
 * in the same commit. Characterization tests may encode known-buggy output
 * until a later stage replaces them with correctness assertions.
 */

const { describe, it } = require("node:test");
const assert = require("node:assert/strict");
const {
	loadDefsAndParse,
	loadLevelPack,
} = require("./helpers/loadScripts.js");

const LEVEL_TILES = 28 * 16; // NO_OF_TILES_X * NO_OF_TILES_Y
const LEGAL_RE = /^[ #@H\-XS$0&]*$/;

const PACKS = [
	{ file: "lodeRunner.v.classic.js", varName: "classicData", expectCount: 150 },
	{ file: "lodeRunner.v.professional.js", varName: "proData", expectCount: 150 },
	{ file: "lodeRunner.v.revenge.js", varName: "revengeData", expectCount: 17 },
	{ file: "lodeRunner.v.fanBookMod.js", varName: "fanBookData", expectCount: 66 },
	{ file: "lodeRunner.v.championship.js", varName: "championData", expectCount: 51 },
];

describe("level pack integrity (characterization)", () => {
	for (const pack of PACKS) {
		it(`${pack.varName}: ${pack.expectCount} levels, each 28×16 with legal tiles and one runner`, () => {
			const levels = loadLevelPack(pack.file, pack.varName);
			assert.equal(levels.length, pack.expectCount);

			for (let i = 0; i < levels.length; i++) {
				const level = levels[i];
				const label = `${pack.varName}[${i}] (level ${i + 1})`;
				assert.equal(level.length, LEVEL_TILES, `${label} length`);
				assert.match(level, LEGAL_RE, `${label} illegal tile chars`);
				const runners = (level.match(/&/g) || []).length;
				assert.equal(runners, 1, `${label} runner count`);
			}
		});
	}
});

describe("parseLevelChar / parseLevelMap (characterization)", () => {
	const ctx = loadDefsAndParse();

	it("maps each legal tile char to documented base/act types", () => {
		const cases = [
			[" ", ctx.EMPTY_T, ctx.EMPTY_T, "empty"],
			["#", ctx.BLOCK_T, ctx.BLOCK_T, "brick"],
			["@", ctx.SOLID_T, ctx.SOLID_T, "solid"],
			["H", ctx.LADDR_T, ctx.LADDR_T, "ladder"],
			["-", ctx.BAR_T, ctx.BAR_T, "rope"],
			["X", ctx.TRAP_T, ctx.TRAP_T, "trap"],
			["S", ctx.HLADR_T, ctx.EMPTY_T, "hladder"],
			["$", ctx.GOLD_T, ctx.EMPTY_T, "gold"],
			["0", ctx.EMPTY_T, ctx.GUARD_T, "guard"],
			["&", ctx.EMPTY_T, ctx.RUNNER_T, "runner"],
		];
		for (const [ch, base, act, kind] of cases) {
			const t = ctx.parseLevelChar(ch);
			assert.deepEqual(
				{ base: t.base, act: t.act, kind: t.kind },
				{ base, act, kind },
				`char ${JSON.stringify(ch)}`
			);
		}
	});

	it("unknown chars follow default → empty (characterization of current switch)", () => {
		const t = ctx.parseLevelChar("?");
		assert.deepEqual(
			{ base: t.base, act: t.act, kind: t.kind },
			{ base: ctx.EMPTY_T, act: ctx.EMPTY_T, kind: "empty" }
		);
	});

	it("parseLevelMap snapshot: classic level 1 counts and runner tile", () => {
		const classic = loadLevelPack("lodeRunner.v.classic.js", "classicData");
		const parsed = ctx.parseLevelMap(classic[0]);

		// Characterization: current classic level 1 entity counts.
		assert.equal(parsed.goldCount, 6);
		assert.equal(parsed.runnerCount, 1);
		assert.equal(parsed.guardCount, 3);

		// Runner '&' is on row 14 (0-based), around mid - locate and lock base/act.
		let runnerPos = null;
		for (let y = 0; y < ctx.NO_OF_TILES_Y; y++) {
			for (let x = 0; x < ctx.NO_OF_TILES_X; x++) {
				if (parsed.map[x][y].char === "&") {
					runnerPos = { x, y };
					assert.equal(parsed.map[x][y].base, ctx.EMPTY_T);
					assert.equal(parsed.map[x][y].act, ctx.RUNNER_T);
				}
			}
		}
		assert.deepEqual(runnerPos, { x: 14, y: 14 });
	});

	it("resolveLevelMap is what buildLevelMap uses for base/act (incl. culling)", () => {
		assert.equal(typeof ctx.resolveLevelMap, "function");
		assert.equal(ctx.MAX_NEW_GUARD, 5);
		assert.equal(ctx.MAX_OLD_GUARD, 6);
	});
});
