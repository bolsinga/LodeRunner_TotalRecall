"use strict";

/**
 * Characterization: HTML shell meta tags.
 */

const { describe, it } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { ROOT } = require("./helpers/loadScripts.js");

describe("html shell (characterization)", () => {
	const html = fs.readFileSync(path.join(ROOT, "lodeRunner.html"), "utf8");

	it("has lang, charset, viewport; no obsolete IE/chrome Frame meta", () => {
		assert.match(html, /<html\s+lang="en">/);
		assert.match(html, /<meta\s+charset="utf-8">/);
		assert.match(html, /<meta\s+name="viewport"\s+content="width=device-width,\s*initial-scale=1">/);
		assert.doesNotMatch(html, /X-UA-Compatible/);
		assert.doesNotMatch(html, /chrome=1/);
		assert.doesNotMatch(html, /http-equiv="Content-Type"/);
	});
});
