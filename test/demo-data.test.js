"use strict";

/**
 * Characterization: demo record schema (no CreateJS).
 */

const { describe, it } = require("node:test");
const assert = require("node:assert/strict");
const { loadScripts } = require("./helpers/loadScripts.js");

const REQUIRED_KEYS = ["level", "ai", "time", "state", "godMode", "action", "goldDrop", "bornPos"];

describe("demoData1 schema (characterization)", () => {
	const ctx = loadScripts(["lodeRunner.demoData1.js"]);
	const demoData1 = ctx.demoData1;

	it("is a non-empty array of records with required fields", () => {
		assert.ok(Array.isArray(demoData1) && demoData1.length > 0);
		for (let i = 0; i < demoData1.length; i++) {
			const rec = demoData1[i];
			for (const key of REQUIRED_KEYS) {
				assert.ok(key in rec, `demoData1[${i}] missing ${key}`);
			}
			assert.equal(typeof rec.level, "number");
			assert.equal(typeof rec.ai, "number");
			assert.equal(typeof rec.time, "number");
			assert.equal(typeof rec.state, "number");
			assert.equal(typeof rec.godMode, "number");
			assert.ok(Array.isArray(rec.action));
			assert.ok(Array.isArray(rec.goldDrop));
			assert.ok(Array.isArray(rec.bornPos));
			// action is [tick, key, tick, key, ...]
			assert.equal(rec.action.length % 2, 0, `demoData1[${i}].action length even`);
		}
	});
});
