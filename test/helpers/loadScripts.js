"use strict";

const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const ROOT = path.resolve(__dirname, "../..");

function readRepo(relPath) {
	return fs.readFileSync(path.join(ROOT, relPath), "utf8");
}

/**
 * Load classic global scripts into a sandbox (characterization / Node harness).
 * @param {string[]} relPaths files relative to repo root, in dependency order
 * @param {object} [extra] extra globals merged into the sandbox
 */
function loadScripts(relPaths, extra = {}) {
	const sandbox = {
		console,
		Array,
		String,
		Object,
		Math,
		Number,
		JSON,
		parseInt,
		parseFloat,
		isNaN,
		undefined,
		...extra,
	};
	sandbox.window = extra.window || sandbox;
	sandbox.globalThis = sandbox;
	const context = vm.createContext(sandbox);
	for (const rel of relPaths) {
		const code = readRepo(rel);
		vm.runInContext(code, context, { filename: rel });
	}
	return context;
}

function loadDefsAndParse() {
	return loadScripts([
		"lodeRunner.def.js",
		"lodeRunner.misc.js",
		"lodeRunner.levelParse.js",
	]);
}

function loadShareCodec() {
	const ctx = loadScripts([
		"lodeRunner.def.js",
		"lodeRunner.misc.js",
		"lodeRunner.shareCodec.js",
	]);
	// Negative unzip paths call error() → console.log; silence so npm test stays clean.
	// Return value ("") is what the characterization tests assert.
	ctx.error = function silentShareError() {};
	return ctx;
}

function loadLevelPack(relPath, varName) {
	const ctx = loadScripts([relPath]);
	const data = ctx[varName];
	if (!Array.isArray(data)) {
		throw new Error(`Expected array global ${varName} from ${relPath}`);
	}
	return data;
}

function makeMemoryLocalStorage() {
	const store = new Map();
	return {
		getItem(key) {
			return store.has(key) ? store.get(key) : null;
		},
		setItem(key, value) {
			const s = String(value);
			// Simulate quota exceeded when asked (tests set this flag).
			if (this._throwQuota) {
				const err = new Error("QuotaExceededError");
				err.name = "QuotaExceededError";
				throw err;
			}
			store.set(String(key), s);
		},
		removeItem(key) {
			store.delete(String(key));
		},
		clear() {
			store.clear();
		},
		get length() {
			return store.size;
		},
		_store: store,
		_throwQuota: false,
	};
}

function loadStorageCore(localStorage) {
	return loadScripts(["lodeRunner.storageCore.js"], {
		window: { localStorage },
	});
}

module.exports = {
	ROOT,
	readRepo,
	loadScripts,
	loadDefsAndParse,
	loadShareCodec,
	loadLevelPack,
	makeMemoryLocalStorage,
	loadStorageCore,
};
