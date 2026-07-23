"use strict";

/**
 * Characterization: buildLevelMap guard culling + multi-runner demotion.
 *
 * These paths used to live only in main.js (mapGuardCount / maxGuard / first-&).
 * They are now in resolveLevelMap(); buildLevelMap consumes that result for spawns.
 * Stage 2 will touch guard loading - this file is the regression net for that.
 */

const { describe, it } = require("node:test");
const assert = require("node:assert/strict");
const {
	loadDefsAndParse,
	loadLevelPack,
} = require("./helpers/loadScripts.js");

const TILES_X = 28;
const TILES_Y = 16;
const LEVEL_LEN = TILES_X * TILES_Y;

/** Plain-clone values born inside vm contexts (deepStrictEqual is realm-sensitive). */
function plain(v) {
	return JSON.parse(JSON.stringify(v));
}

/** Build a blank 28×16 level, then stamp entities at [x,y] positions. */
function makeLevel(stamps) {
	const cells = Array(LEVEL_LEN).fill(" ");
	for (const { x, y, ch } of stamps) {
		cells[y * TILES_X + x] = ch;
	}
	// Always need a floor of bricks on the bottom row so the string is valid-looking;
	// culling logic does not care about geometry.
	for (let x = 0; x < TILES_X; x++) {
		if (cells[(TILES_Y - 1) * TILES_X + x] === " ") {
			cells[(TILES_Y - 1) * TILES_X + x] = "#";
		}
	}
	return cells.join("");
}

describe("resolveLevelMap culling (characterization of buildLevelMap)", () => {
	const ctx = loadDefsAndParse();

	it("keeps all guards when raw count == maxGuard (MAX_NEW_GUARD=5)", () => {
		const stamps = [];
		for (let i = 0; i < 5; i++) stamps.push({ x: i, y: 0, ch: "0" });
		stamps.push({ x: 10, y: 0, ch: "&" });
		const level = makeLevel(stamps);
		const r = ctx.resolveLevelMap(level, ctx.MAX_NEW_GUARD);
		assert.equal(r.rawGuardCount, 5);
		assert.equal(r.guardCount, 5);
		assert.equal(r.culledGuardCount, 0);
		assert.equal(r.guards.length, 5);
		for (const g of r.guards) {
			assert.equal(r.map[g.x][g.y].act, ctx.GUARD_T);
		}
	});

	it("culls the first excess guard in row-major order (6 guards, max=5)", () => {
		// Six guards at (0..5, y=0); first in scan order is (0,0).
		const stamps = [];
		for (let i = 0; i < 6; i++) stamps.push({ x: i, y: 0, ch: "0" });
		stamps.push({ x: 10, y: 0, ch: "&" });
		const level = makeLevel(stamps);
		const r = ctx.resolveLevelMap(level, ctx.MAX_NEW_GUARD);

		assert.equal(r.rawGuardCount, 6);
		assert.equal(r.culledGuardCount, 1);
		assert.equal(r.guardCount, 5);

		// First guard demoted
		assert.equal(r.map[0][0].char, "0");
		assert.equal(r.map[0][0].base, ctx.EMPTY_T);
		assert.equal(r.map[0][0].act, ctx.EMPTY_T);
		assert.equal(r.map[0][0].kind, "empty");

		// Remaining five kept at (1..5, 0)
		assert.deepEqual(
			plain(r.guards),
			[
				{ x: 1, y: 0 },
				{ x: 2, y: 0 },
				{ x: 3, y: 0 },
				{ x: 4, y: 0 },
				{ x: 5, y: 0 },
			]
		);
		for (const g of r.guards) {
			assert.equal(r.map[g.x][g.y].act, ctx.GUARD_T);
		}
	});

	it("MAX_OLD_GUARD=6 keeps all six; MAX_NEW_GUARD=5 culls one (same level)", () => {
		const stamps = [];
		for (let i = 0; i < 6; i++) stamps.push({ x: i, y: 1, ch: "0" });
		stamps.push({ x: 0, y: 0, ch: "&" });
		const level = makeLevel(stamps);

		const oldAi = ctx.resolveLevelMap(level, ctx.MAX_OLD_GUARD);
		assert.equal(oldAi.guardCount, 6);
		assert.equal(oldAi.culledGuardCount, 0);

		const newAi = ctx.resolveLevelMap(level, ctx.MAX_NEW_GUARD);
		assert.equal(newAi.guardCount, 5);
		assert.equal(newAi.culledGuardCount, 1);
	});

	it("first '&' wins; later '&' demoted to EMPTY_T act", () => {
		const level = makeLevel([
			{ x: 3, y: 2, ch: "&" },
			{ x: 7, y: 5, ch: "&" },
			{ x: 1, y: 0, ch: "0" },
		]);
		const r = ctx.resolveLevelMap(level, ctx.MAX_NEW_GUARD);

		assert.equal(r.runnerCount, 1);
		assert.equal(r.culledRunnerCount, 1);
		assert.deepEqual(plain(r.runner), { x: 3, y: 2 });
		assert.equal(r.map[3][2].act, ctx.RUNNER_T);
		assert.equal(r.map[7][5].char, "&");
		assert.equal(r.map[7][5].act, ctx.EMPTY_T);
		assert.equal(r.map[7][5].kind, "empty");
	});

	it("culling order follows row-major (earlier row culled before later)", () => {
		// 6 guards: five on row 0, one on row 1 - with max=5, only (0,0) culled.
		const stamps = [];
		for (let i = 0; i < 5; i++) stamps.push({ x: i, y: 0, ch: "0" });
		stamps.push({ x: 0, y: 1, ch: "0" });
		stamps.push({ x: 10, y: 2, ch: "&" });
		const level = makeLevel(stamps);
		const r = ctx.resolveLevelMap(level, ctx.MAX_NEW_GUARD);

		assert.equal(r.culledGuardCount, 1);
		assert.equal(r.map[0][0].act, ctx.EMPTY_T);
		assert.equal(r.map[0][1].act, ctx.GUARD_T);
		assert.ok(r.guards.some((g) => g.x === 0 && g.y === 1));
	});

	it("shipped classic levels with 6 guards: cull 1 under MAX_NEW_GUARD", () => {
		// Confirmed inventory: classic 8, 80, 113 each have rawGuardCount 6.
		const classic = loadLevelPack("lodeRunner.v.classic.js", "classicData");
		const indices = [7, 79, 112]; // 0-based
		for (const idx of indices) {
			const r = ctx.resolveLevelMap(classic[idx], ctx.MAX_NEW_GUARD);
			assert.equal(r.rawGuardCount, 6, `classic ${idx + 1} raw`);
			assert.equal(r.guardCount, 5, `classic ${idx + 1} active`);
			assert.equal(r.culledGuardCount, 1, `classic ${idx + 1} culled`);
			assert.equal(r.runnerCount, 1, `classic ${idx + 1} runner`);
		}
	});

	it("shipped classic level 8: first culled guard position is stable", () => {
		const classic = loadLevelPack("lodeRunner.v.classic.js", "classicData");
		const r = ctx.resolveLevelMap(classic[7], ctx.MAX_NEW_GUARD);
		// Find first '0' in row-major that was demoted - characterization lock.
		let firstCulled = null;
		for (let y = 0; y < TILES_Y && !firstCulled; y++) {
			for (let x = 0; x < TILES_X; x++) {
				const cell = r.map[x][y];
				if (cell.char === "0" && cell.act === ctx.EMPTY_T) {
					firstCulled = { x, y };
					break;
				}
			}
		}
		assert.ok(firstCulled, "expected one culled guard");
		// Snapshot - update only if intentional culling-order change.
		assert.deepEqual(plain(firstCulled), { x: 5, y: 2 });
	});

	it("under MAX_NEW_GUARD no shipped pack keeps more than 5 active guards", () => {
		const packs = [
			["lodeRunner.v.classic.js", "classicData"],
			["lodeRunner.v.professional.js", "proData"],
			["lodeRunner.v.revenge.js", "revengeData"],
			["lodeRunner.v.fanBookMod.js", "fanBookData"],
			["lodeRunner.v.championship.js", "championData"],
		];
		for (const [file, varName] of packs) {
			const levels = loadLevelPack(file, varName);
			for (let i = 0; i < levels.length; i++) {
				const r = ctx.resolveLevelMap(levels[i], ctx.MAX_NEW_GUARD);
				assert.ok(
					r.guardCount <= ctx.MAX_NEW_GUARD,
					`${varName}[${i}] guardCount=${r.guardCount}`
				);
				assert.ok(r.runnerCount <= 1, `${varName}[${i}] runners`);
				assert.equal(
					r.rawGuardCount,
					r.guardCount + r.culledGuardCount,
					`${varName}[${i}] raw = active + culled`
				);
			}
		}
	});
});
