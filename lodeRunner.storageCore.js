//=============================================================================
// Thin localStorage wrappers (DOM-free enough to mock in Node).
// Extracted from lodeRunner.storage.js for characterization tests.
//=============================================================================

function setStorage(key, value)
{
	if (typeof (window.localStorage) != 'undefined') {
		window.localStorage.setItem(key, value);
	}
}

function getStorage(key)
{
	var value = null;
	if (typeof (window.localStorage) != 'undefined') {
		value = window.localStorage.getItem(key);
	}
	return value;
}

function clearStorage(key)
{
	if (typeof (window.localStorage) != 'undefined') {
		window.localStorage.removeItem(key);
	}
}

// Every key this game owns starts with this; anything else on the origin is
// not ours to delete.
var STORAGE_PREFIX = "loderunner_";

// What lives in storage, grouped the way a person would think about losing it.
// Matched by key prefix because several keys carry a runtime suffix (per-theme
// color, per-version progress, per-level custom maps) -- listing exact names
// would go stale and quietly leave state behind.
//
// Order matters: first match wins, so a longer prefix must precede any key it
// starts with -- "modernScore" would otherwise be swallowed by "modernInfo".
var STORAGE_GROUPS = [
	{
		id: "settings",
		name: "Settings",
		note: "Theme, color, sound, speed, accent, player name",
		keys: ["theme", "color_", "actRepeat", "gamepadMode", "accent", "player", "firstRun", "lastplay"]
	},
	{
		id: "scores",
		name: "High scores",
		note: "Score tables, every version",
		keys: ["hiScore", "modernScore"]
	},
	{
		id: "progress",
		name: "Progress",
		note: "Levels reached and cleared, per version",
		keys: ["classicInfo", "modernInfo", "demoInfo"]
	},
	{
		id: "levels",
		name: "Custom levels",
		note: "Levels you built in the editor",
		keys: ["userLevel", "testlevel", "editInfo"]
	}
];

/** Which group a key belongs to, or null if it is not ours. */
function storageGroupOf(key)
{
	if (!key || key.indexOf(STORAGE_PREFIX) !== 0) return null;
	var rest = key.slice(STORAGE_PREFIX.length);

	for (var g = 0; g < STORAGE_GROUPS.length; g++) {
		var keys = STORAGE_GROUPS[g].keys;
		for (var k = 0; k < keys.length; k++) {
			if (rest.indexOf(keys[k]) === 0) return STORAGE_GROUPS[g].id;
		}
	}
	return null;
}

/** How many stored keys each group currently holds, as {groupId: count}. */
function storageGroupCounts()
{
	var counts = {};
	for (var g = 0; g < STORAGE_GROUPS.length; g++) counts[STORAGE_GROUPS[g].id] = 0;
	if (typeof (window.localStorage) == 'undefined') return counts;

	for (var i = 0; i < window.localStorage.length; i++) {
		var id = storageGroupOf(window.localStorage.key(i));
		if (id) counts[id]++;
	}
	return counts;
}

/**
 * Remove the named groups.
 * @param {string[]} groupIds ids from STORAGE_GROUPS
 * @returns {number} how many keys were removed
 */
function clearStorageGroups(groupIds)
{
	if (typeof (window.localStorage) == 'undefined' || !groupIds || !groupIds.length) return 0;

	var wanted = {};
	for (var w = 0; w < groupIds.length; w++) wanted[groupIds[w]] = 1;

	var doomed = [];
	for (var i = 0; i < window.localStorage.length; i++) {
		var key = window.localStorage.key(i);
		var id = storageGroupOf(key);
		if (id && wanted[id]) doomed.push(key);
	}
	//collect first, then delete: removing during the scan reindexes the store
	for (var d = 0; d < doomed.length; d++) window.localStorage.removeItem(doomed[d]);

	return doomed.length;
}
