"use strict";

/**
 * Correctness: sticky stop-on-release works without RECORD_KEY capture;
 * capture pushes are optional.
 */

const { describe, it } = require("node:test");
const assert = require("node:assert/strict");
const { loadScripts } = require("./helpers/loadScripts.js");

const KEYCODE_SPACE = 32;
const KEYCODE_LEFT = 37;
const ACT_STOP = 0;
const ACT_LEFT = 1;

function baseState(over = {}) {
	return {
		keyPressed: 0,
		recordKeyCode: 0,
		lastKeyCode: -1,
		keyAction: ACT_LEFT,
		alwaysRecord: 0,
		...over,
	};
}

describe("advanceStickyKeyState (correctness)", () => {
	const ctx = loadScripts(["lodeRunner.inputLogic.js"]);

	it("release sets ACT_STOP without capturing when capture=false", () => {
		const record = [];
		const next = ctx.advanceStickyKeyState(
			baseState({ keyPressed: 0, recordKeyCode: KEYCODE_LEFT, lastKeyCode: KEYCODE_LEFT }),
			false,
			10,
			record,
			KEYCODE_SPACE,
			ACT_STOP
		);
		assert.equal(next.keyAction, ACT_STOP);
		assert.equal(next.recordKeyCode, KEYCODE_SPACE);
		assert.deepEqual(record, []);
	});

	it("release captures SPACE into playRecord when capture=true", () => {
		const record = [];
		const next = ctx.advanceStickyKeyState(
			baseState({ keyPressed: 0, recordKeyCode: KEYCODE_LEFT, lastKeyCode: KEYCODE_LEFT }),
			true,
			10,
			record,
			KEYCODE_SPACE,
			ACT_STOP
		);
		assert.equal(next.keyAction, ACT_STOP);
		assert.deepEqual(record, [10, KEYCODE_SPACE]);
	});

	it("press captures key only when capture=true", () => {
		const captured = [];
		const silent = [];
		const pressed = baseState({
			keyPressed: 1,
			recordKeyCode: KEYCODE_LEFT,
			lastKeyCode: -1,
			keyAction: ACT_LEFT,
		});
		ctx.advanceStickyKeyState(pressed, true, 5, captured, KEYCODE_SPACE, ACT_STOP);
		ctx.advanceStickyKeyState(pressed, false, 5, silent, KEYCODE_SPACE, ACT_STOP);
		assert.deepEqual(captured, [5, KEYCODE_LEFT]);
		assert.deepEqual(silent, []);
	});

	it("dig alwaysRecord floats (keyPressed=-1) so release is ignored", () => {
		const record = [];
		const afterPress = ctx.advanceStickyKeyState(
			baseState({
				keyPressed: 1,
				recordKeyCode: 90, // Z dig left
				lastKeyCode: -1,
				alwaysRecord: 1,
				keyAction: 7,
			}),
			false,
			1,
			record,
			KEYCODE_SPACE,
			ACT_STOP
		);
		assert.equal(afterPress.keyPressed, -1);
		assert.deepEqual(record, []);
	});
});

describe("advanceRepeatKeyState (correctness)", () => {
	const ctx = loadScripts(["lodeRunner.inputLogic.js"]);

	it("clears keyPressed and does not set ACT_STOP", () => {
		const record = [];
		const next = ctx.advanceRepeatKeyState(
			baseState({ keyPressed: 1, recordKeyCode: KEYCODE_LEFT, lastKeyCode: -1 }),
			false,
			3,
			record
		);
		assert.equal(next.keyPressed, 0);
		assert.equal(next.keyAction, ACT_LEFT);
		assert.deepEqual(record, []);
	});
});
