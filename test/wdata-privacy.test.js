"use strict";

/**
 * Correctness / privacy: shipped demo packs must not contain player PII.
 * Packs are split per version (lodeRunner.wData.N.js) for lazy loading.
 */

const { describe, it } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { loadScripts, ROOT } = require("./helpers/loadScripts.js");

const PACKS = [
	{ file: "lodeRunner.wData.1.js", globalName: "wfastDemoData1" },
	{ file: "lodeRunner.wData.2.js", globalName: "wfastDemoData2" },
	{ file: "lodeRunner.wData.3.js", globalName: "wfastDemoData3" },
	{ file: "lodeRunner.wData.4.js", globalName: "wfastDemoData4" },
	{ file: "lodeRunner.wData.5.js", globalName: "wfastDemoData5" },
];

describe("wData packs privacy (correctness)", () => {
	it("monolithic lodeRunner.wData.js is gone (lazy split)", () => {
		assert.equal(fs.existsSync(path.join(ROOT, "lodeRunner.wData.js")), false);
	});

	for (const pack of PACKS) {
		it(`${pack.file}: UTF-8, no uId/cId globals, no PII in records`, () => {
			const source = fs.readFileSync(path.join(ROOT, pack.file));
			assert.notEqual(source[0], 0xff, "must not start with UTF-16 LE BOM");
			const text = source.toString("utf8");
			assert.match(text, /redacted for privacy|PII redacted/);
			assert.equal(/\b(?:\d{1,3}\.){3}\d{1,3}\b/.test(text), false, "no IPv4");

			const ctx = loadScripts([pack.file]);
			assert.equal(typeof ctx.uId, "undefined");
			assert.equal(typeof ctx.cId, "undefined");
			const data = ctx[pack.globalName];
			assert.ok(Array.isArray(data) && data.length > 0, pack.globalName);
			for (let i = 0; i < data.length; i++) {
				const rec = data[i];
				assert.equal("ip" in rec, false, `${pack.globalName}[${i}] has ip`);
				assert.equal(rec.player, "", `${pack.globalName}[${i}].player`);
				assert.equal(rec.location, "", `${pack.globalName}[${i}].location`);
				assert.equal(rec.cId, "", `${pack.globalName}[${i}].cId`);
				assert.ok(Array.isArray(rec.action));
				assert.equal(typeof rec.level, "number");
			}
		});
	}
});
