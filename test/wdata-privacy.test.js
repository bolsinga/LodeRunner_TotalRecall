"use strict";

/**
 * Correctness / privacy: shipped demo packs must not contain player PII.
 */

const { describe, it } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { loadScripts, ROOT } = require("./helpers/loadScripts.js");

const PACKS = [
	"wfastDemoData1",
	"wfastDemoData2",
	"wfastDemoData3",
	"wfastDemoData4",
	"wfastDemoData5",
];

describe("wData.js privacy (correctness)", () => {
	const source = fs.readFileSync(path.join(ROOT, "lodeRunner.wData.js"));
	const ctx = loadScripts(["lodeRunner.wData.js"]);

	it("is UTF-8 (no UTF-16 BOM) and does not declare shipped uId/cId globals", () => {
		assert.notEqual(source[0], 0xff, "must not start with UTF-16 LE BOM");
		assert.equal(typeof ctx.uId, "undefined");
		assert.equal(typeof ctx.cId, "undefined");
		assert.match(source.toString("utf8"), /redacted for privacy/);
	});

	it("demo packs load and contain no ip / non-empty player|location|cId", () => {
		const ipv4 = /\b(?:\d{1,3}\.){3}\d{1,3}\b/;
		for (const name of PACKS) {
			const pack = ctx[name];
			assert.ok(Array.isArray(pack) && pack.length > 0, name);
			for (let i = 0; i < pack.length; i++) {
				const rec = pack[i];
				assert.equal("ip" in rec, false, `${name}[${i}] has ip`);
				assert.equal(rec.player, "", `${name}[${i}].player`);
				assert.equal(rec.location, "", `${name}[${i}].location`);
				assert.equal(rec.cId, "", `${name}[${i}].cId`);
				assert.ok(Array.isArray(rec.action), `${name}[${i}].action`);
				assert.equal(typeof rec.level, "number");
			}
		}
		assert.equal(ipv4.test(source.toString("utf8")), false, "no IPv4 literals in source");
	});
});
