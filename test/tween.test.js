"use strict";

/**
 * Characterization: rAF tween helper (CreateJS TweenJS replacement).
 */

const { describe, it, beforeEach, afterEach } = require("node:test");
const assert = require("node:assert/strict");
const { loadScripts } = require("./helpers/loadScripts.js");

function installFakeRaf(ctx) {
	let now = 0;
	const queue = [];
	let nextId = 1;
	ctx.performance = { now: () => now };
	ctx.requestAnimationFrame = (fn) => {
		const id = nextId++;
		queue.push({ id, fn });
		return id;
	};
	ctx.cancelAnimationFrame = (id) => {
		const i = queue.findIndex((q) => q.id === id);
		if (i >= 0) queue.splice(i, 1);
	};
	return {
		advance(ms) {
			now += ms;
			const batch = queue.splice(0, queue.length);
			for (const item of batch) item.fn(now);
		},
		flushMicrotasks() {
			return Promise.resolve();
		},
	};
}

describe("tweenGet", () => {
	let ctx;
	let clock;

	beforeEach(() => {
		ctx = loadScripts(["lodeRunner.tween.js"]);
		clock = installFakeRaf(ctx);
	});

	afterEach(() => {
		ctx = null;
		clock = null;
	});

	it("interpolates props then fires call once after the last frame", async () => {
		const target = { alpha: 0 };
		let calls = 0;
		ctx.tweenGet(target).set({ alpha: 0.6 }).to({ alpha: 1 }, 800).call(() => {
			calls++;
		});
		await clock.flushMicrotasks();
		assert.equal(target.alpha, 0.6);
		assert.equal(calls, 0);

		clock.advance(400);
		assert.ok(target.alpha > 0.6 && target.alpha < 1);
		assert.equal(calls, 0);

		clock.advance(400);
		assert.equal(target.alpha, 1);
		assert.equal(calls, 1);

		clock.advance(100);
		assert.equal(calls, 1);
	});

	it("override cancels prior tween so its call does not fire", async () => {
		const target = { alpha: 1 };
		let first = 0;
		let second = 0;
		ctx.tweenGet(target).to({ alpha: 0 }, 1000).call(() => {
			first++;
		});
		await clock.flushMicrotasks();
		clock.advance(100);

		ctx.tweenGet(target, { override: true }).set({ alpha: 0.8 }).to({ alpha: 0 }, 200).call(() => {
			second++;
		});
		await clock.flushMicrotasks();
		clock.advance(200);

		assert.equal(first, 0);
		assert.equal(second, 1);
		assert.equal(target.alpha, 0);
	});

	it("runs chained to/wait/call in order (game-over style)", async () => {
		const target = { scaleY: 1 };
		const seen = [];
		ctx
			.tweenGet(target)
			.to({ scaleY: -1 }, 80)
			.to({ scaleY: 1 }, 80)
			.wait(50)
			.call(() => {
				seen.push(target.scaleY);
			});
		await clock.flushMicrotasks();
		clock.advance(80);
		assert.equal(target.scaleY, -1);
		clock.advance(80);
		assert.equal(target.scaleY, 1);
		assert.deepEqual(seen, []);
		clock.advance(50);
		assert.deepEqual(seen, [1]);
	});
});
