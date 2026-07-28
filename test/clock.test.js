"use strict";

/**
 * Behavioral tests for the owned rAF + fixed-step accumulator.
 * Characterization greps alone would pass with wrong arithmetic; drive a fake rAF.
 */

const { describe, it, beforeEach, afterEach } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { ROOT, loadScripts } = require("./helpers/loadScripts.js");

function makeFakeRafEnv() {
	let now = 1000;
	let nextId = 1;
	let pending = [];
	return {
		performance: { now: () => now },
		requestAnimationFrame(cb) {
			const id = nextId++;
			pending.push({ id, cb });
			return id;
		},
		cancelAnimationFrame(id) {
			pending = pending.filter((p) => p.id !== id);
		},
		/** Advance wall time by dt ms and run one scheduled rAF callback (if any). */
		advance(dt) {
			now += dt;
			const batch = pending;
			pending = [];
			for (const p of batch) p.cb(now);
		},
		pendingCount: () => pending.length,
		now: () => now,
	};
}

describe("owned game clock (characterization)", () => {
	it("play/cover/hiscore/key/settings no longer call createjs.Ticker", () => {
		const files = [
			"lodeRunner.main.js",
			"lodeRunner.preload.js",
			"lodeRunner.hiscore.js",
			"lodeRunner.key.js",
			"lodeRunner.settings.js",
		];
		for (const f of files) {
			const text = fs.readFileSync(path.join(ROOT, f), "utf8");
			assert.doesNotMatch(text, /createjs\.Ticker/, f + " still references Ticker");
		}
	});
});

describe("owned game clock (behavior)", () => {
	let env;
	let g;

	beforeEach(() => {
		env = makeFakeRafEnv();
		g = loadScripts(["lodeRunner.clock.js"], {
			performance: env.performance,
			requestAnimationFrame: env.requestAnimationFrame,
			cancelAnimationFrame: env.cancelAnimationFrame,
		});
	});

	afterEach(() => {
		while (g.clockListeners && g.clockListeners.length) {
			g.removeClockListener(g.clockListeners[0]);
		}
	});

	it("steady state: one tick per frame at fps=20 with constant delta", () => {
		g.setClockFps(20); // 50ms step
		const ticks = [];
		g.addClockListener((evt) => ticks.push(evt));
		for (let i = 0; i < 5; i++) env.advance(50);
		assert.equal(ticks.length, 5);
		assert.ok(ticks.every((e) => e.delta === 50));
		assert.equal(ticks[0].time, 50);
		assert.equal(ticks[4].time, 250);
	});

	it("500ms hitch clamps to CLOCK_MAX_STEPS then resumes 1:1", () => {
		g.setClockFps(20);
		const ticks = [];
		g.addClockListener((evt) => ticks.push(evt));
		env.advance(50); // warm-up: 1 tick
		assert.equal(ticks.length, 1);
		env.advance(500); // hitch: clamp to 5
		assert.equal(ticks.length, 1 + g.CLOCK_MAX_STEPS);
		env.advance(50);
		assert.equal(ticks.length, 1 + g.CLOCK_MAX_STEPS + 1);
		assert.equal(ticks[ticks.length - 1].delta, 50);
	});

	it("10s stall does not spiral (one frame → at most MAX_STEPS)", () => {
		g.setClockFps(20);
		const ticks = [];
		g.addClockListener((evt) => ticks.push(evt));
		env.advance(50);
		env.advance(10000);
		assert.equal(ticks.length, 1 + g.CLOCK_MAX_STEPS);
	});

	it("setClockFps takes effect immediately; 0/negative ignored", () => {
		g.setClockFps(20);
		assert.equal(g.clockFps, 20);
		g.setClockFps(0);
		assert.equal(g.clockFps, 20);
		g.setClockFps(-5);
		assert.equal(g.clockFps, 20);
		g.setClockFps(10); // 100ms step
		assert.equal(g.clockFps, 10);
		const ticks = [];
		g.addClockListener((evt) => ticks.push(evt));
		env.advance(100);
		assert.equal(ticks.length, 1);
		assert.equal(ticks[0].delta, 100);
	});

	it("listener removing itself mid-step fires once then drains", () => {
		g.setClockFps(20);
		let fires = 0;
		function selfRemove() {
			fires++;
			g.removeClockListener(selfRemove);
		}
		g.addClockListener(selfRemove);
		env.advance(50);
		assert.equal(fires, 1);
		assert.equal(g.clockListeners.length, 0);
		assert.equal(env.pendingCount(), 0); // rAF stopped
		env.advance(50);
		assert.equal(fires, 1);
	});

	it("listener added during a step does not fire in that same step", () => {
		g.setClockFps(20);
		const order = [];
		function late() {
			order.push("late");
		}
		function early() {
			order.push("early");
			g.addClockListener(late);
		}
		g.addClockListener(early);
		env.advance(50);
		assert.deepEqual(order, ["early"]);
		env.advance(50);
		assert.deepEqual(order, ["early", "early", "late"]);
	});

	it("empty→add restart drops prior fractional acc (no catch-up burst)", () => {
		g.setClockFps(20);
		const ticks = [];
		function count(evt) {
			ticks.push(evt);
		}
		g.addClockListener(count);
		env.advance(50);
		g.removeClockListener(count);
		assert.equal(g.clockAcc, 0);
		// Wall time continues while clock is stopped; restart must not owe that debt.
		env.advance(500);
		g.addClockListener(count);
		env.advance(50);
		assert.equal(ticks.length, 2); // only warm-up + one post-restart tick
		assert.equal(ticks[1].delta, 50);
	});
});
