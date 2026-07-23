"use strict";

/**
 * Characterization: def.js constants must not drift silently.
 */

const { describe, it } = require("node:test");
const assert = require("node:assert/strict");
const { loadScripts } = require("./helpers/loadScripts.js");

describe("def.js constants (characterization)", () => {
	const ctx = loadScripts(["lodeRunner.def.js"]);

	it("tile grid and score / game-state enums", () => {
		assert.equal(ctx.NO_OF_TILES_X, 28);
		assert.equal(ctx.NO_OF_TILES_Y, 16);
		assert.equal(ctx.EMPTY_T, 0x00);
		assert.equal(ctx.BLOCK_T, 0x01);
		assert.equal(ctx.SOLID_T, 0x02);
		assert.equal(ctx.LADDR_T, 0x03);
		assert.equal(ctx.BAR_T, 0x04);
		assert.equal(ctx.TRAP_T, 0x05);
		assert.equal(ctx.HLADR_T, 0x06);
		assert.equal(ctx.GOLD_T, 0x07);
		assert.equal(ctx.GUARD_T, 0x08);
		assert.equal(ctx.RUNNER_T, 0x09);

		assert.equal(ctx.SCORE_COMPLETE_LEVEL, 1500);
		assert.equal(ctx.SCORE_GET_GOLD, 250);
		assert.equal(ctx.SCORE_IN_HOLE, 75);
		assert.equal(ctx.SCORE_GUARD_DEAD, 75);

		assert.equal(ctx.GAME_START, 0);
		assert.equal(ctx.GAME_RUNNING, 1);
		assert.equal(ctx.GAME_FINISH, 2);
		assert.equal(ctx.GAME_NEW_LEVEL, 6);
		assert.equal(ctx.GAME_RUNNER_DEAD, 7);
		assert.equal(ctx.GAME_OVER, 9);
		assert.equal(ctx.GAME_WIN, 14);

		assert.equal(ctx.PLAY_CLASSIC, 1);
		assert.equal(ctx.PLAY_MODERN, 2);
		assert.equal(ctx.PLAY_DEMO, 3);
		assert.equal(ctx.PLAY_EDIT, 4);
	});
});
