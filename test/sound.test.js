"use strict";

/**
 * Characterization: Web Audio sound helpers (CreateJS SoundJS replacement).
 */

const { describe, it, beforeEach } = require("node:test");
const assert = require("node:assert/strict");
const { loadScripts } = require("./helpers/loadScripts.js");

function installFakeAudio(ctx) {
	let currentTime = 0;
	const sources = [];
	ctx.window = ctx;

	function fakeDecode(_arrayBuffer, success) {
		success({ duration: 2 });
	}

	ctx.OfflineAudioContext = function FakeOfflineAudioContext() {
		this.decodeAudioData = fakeDecode;
	};
	ctx.webkitOfflineAudioContext = ctx.OfflineAudioContext;

	ctx.AudioContext = function FakeAudioContext() {
		this.state = "running";
		this.sampleRate = 44100;
		this.destination = {};
		Object.defineProperty(this, "currentTime", {
			get() {
				return currentTime;
			},
		});
		this.resume = async () => {
			this.state = "running";
		};
		this.createBuffer = () => ({ duration: 0 });
		this.createBufferSource = () => {
			const source = {
				buffer: null,
				onended: null,
				started: false,
				stopped: false,
				startOffset: 0,
				connect() {},
				start(_when, offset) {
					this.started = true;
					this.startOffset = offset || 0;
					sources.push(this);
				},
				stop() {
					this.stopped = true;
					if (typeof this.onended === "function") this.onended();
				},
			};
			return source;
		};
	};
	ctx.webkitAudioContext = ctx.AudioContext;
	ctx.fetch = async (url) => {
		if (String(url).includes("missing")) {
			return { ok: false, status: 404 };
		}
		return {
			ok: true,
			status: 200,
			arrayBuffer: async () => new ArrayBuffer(8),
		};
	};
	return {
		advance(sec) {
			currentTime += sec;
		},
		sources,
	};
}

describe("soundAlternateUrl / partitionAssetManifest", () => {
	it("maps ogg to mp3 and preserves query string", () => {
		const ctx = loadScripts(["lodeRunner.sound.js"]);
		assert.equal(ctx.soundAlternateUrl("sound/beep.ogg"), "sound/beep.mp3");
		assert.equal(ctx.soundAlternateUrl("sound/beep.ogg?v=1"), "sound/beep.mp3?v=1");
		assert.equal(ctx.soundAlternateUrl("sound/beep.mp3"), "sound/beep.mp3");
	});

	it("partitions theme manifest into images vs sounds", () => {
		const ctx = loadScripts(["lodeRunner.def.js", "lodeRunner.themeAssets.js"]);
		const list = ctx.buildThemeAssetManifest("APPLE2", "image/Theme/", "sound/Theme/", "");
		const parts = ctx.partitionAssetManifest(list);
		assert.equal(parts.images.length, 17);
		assert.equal(parts.sounds.length, 8);
		assert.ok(parts.sounds.every((e) => ctx.isSoundAssetSrc(e.src)));
		assert.ok(parts.images.every((e) => !ctx.isSoundAssetSrc(e.src)));
	});
});

describe("SoundInstance", () => {
	let ctx;
	let clock;

	beforeEach(() => {
		ctx = loadScripts(["lodeRunner.sound.js"]);
		clock = installFakeAudio(ctx);
	});

	it("play/stop restarts; getDuration is ms; pause/resume keeps offset", async () => {
		await ctx.soundLoadManifest([{ id: "digAPPLE2", src: "sound/Theme/APPLE2/dig.ogg" }]);
		const inst = ctx.soundCreateInstance("digAPPLE2");
		assert.equal(inst.getDuration(), 2000);

		inst.play();
		assert.equal(clock.sources.length, 1);
		assert.equal(clock.sources[0].started, true);

		clock.advance(0.4);
		inst.pause();
		assert.equal(inst.paused, true);
		assert.equal(clock.sources[0].stopped, true);

		inst.resume();
		assert.equal(inst.paused, false);
		const resumed = clock.sources[clock.sources.length - 1];
		assert.ok(Math.abs(resumed.startOffset - 0.4) < 1e-9);

		inst.stop();
		inst.play();
		const restarted = clock.sources[clock.sources.length - 1];
		assert.equal(restarted.startOffset, 0);
	});

	it("soundStopById stops one-shots for that id", async () => {
		await ctx.soundLoadManifest([{ id: "beep", src: "sound/beep.ogg" }]);
		ctx.soundPlayById("beep");
		ctx.soundPlayById("beep");
		assert.equal(clock.sources.length, 2);
		ctx.soundStopById("beep");
		assert.ok(clock.sources.every((s) => s.stopped));
	});
});
