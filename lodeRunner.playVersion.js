//=============================================================================
// Play-version registry: level/demo pack metadata + lazy ensure helpers.
// Menu UI init stays in lodeRunner.menu.js.
//=============================================================================

var playVersionInfo = [
	// classic is in lodeRunner.html; others lazy-loaded via ensurePlayVersionLoaded()
	{ id:1, globalName: "classicData",  script: null,                           demoScript: "lodeRunner.wData.1.js", demoGlobal: "wfastDemoData1", levelCount: 150, name: " Classic Lode Runner ",        info: classicInfo },
	{ id:3, globalName: "proData",      script: "lodeRunner.v.professional.js", demoScript: "lodeRunner.wData.3.js", demoGlobal: "wfastDemoData3", levelCount: 150, name: " Professional Lode Runner ",  info: proInfo },
	{ id:4, globalName: "revengeData",  script: "lodeRunner.v.revenge.js",      demoScript: "lodeRunner.wData.4.js", demoGlobal: "wfastDemoData4", levelCount: 17,  name: " Revenge of Lode Runner ",    info: revengeInfo },
	{ id:5, globalName: "fanBookData",  script: "lodeRunner.v.fanBookMod.js",   demoScript: "lodeRunner.wData.5.js", demoGlobal: "wfastDemoData5", levelCount: 66,  name: " Lode Runner Fan Book ",      info: fanBookInfo },
	{ id:2, globalName: "championData", script: "lodeRunner.v.championship.js", demoScript: "lodeRunner.wData.2.js", demoGlobal: "wfastDemoData2", levelCount: 51,  name: " Championship Lode Runner ", info: championInfo }
];

function findPlayVersionInfo(id)
{
	for (var i = 0; i < playVersionInfo.length; i++) {
		if (playVersionInfo[i].id == id) return playVersionInfo[i];
	}
	return null;
}

function isGlobalDefined(name)
{
	return (typeof window[name] !== "undefined");
}

/**
 * Ensure level pack + demo pack for playData id are loaded, then callback.
 * Classic level pack is already in the HTML critical path.
 */
function ensurePlayVersionLoaded(id, callback)
{
	if (id == PLAY_DATA_USERDEF || id < 1) {
		if (callback) callback();
		return;
	}
	var info = findPlayVersionInfo(id);
	if (!info) {
		error("ensurePlayVersionLoaded: unknown playData id=" + id);
		if (callback) callback();
		return;
	}
	var need = [];
	if (info.script && !isGlobalDefined(info.globalName)) need.push(info.script);
	if (info.demoScript && !isGlobalDefined(info.demoGlobal)) need.push(info.demoScript);
	loadScriptsParallel(need, callback);
}

/** Are this version's level and demo packs already in memory? */
function isPlayVersionLoaded(id)
{
	if (id == PLAY_DATA_USERDEF || id < 1) return true;   // custom levels are local
	var info = findPlayVersionInfo(id);
	if (!info) return false;
	if (info.script && !isGlobalDefined(info.globalName)) return false;
	if (info.demoScript && !isGlobalDefined(info.demoGlobal)) return false;
	return true;
}

function getPlayVerData(id) 
{
	if(id == PLAY_DATA_USERDEF) return editLevelData || [];

	var info = findPlayVersionInfo(id);
	if (info && isGlobalDefined(info.globalName)) {
		return window[info.globalName];
	}
	
	error("Error: versionData not loaded, id = " + id );
	return classicData;
}

function defaultLevelData()
{
	return classicData;
}

var playDataNameUserDef = "Custom Levels";

// "(1 Level)" / "(150 Levels)". Custom levels report whatever exists right now,
// so a count of 0 gets nothing rather than "(0 Levels)".
function playVersionCountText(count)
{
	if(!count) return "";
	return "(" + count + (count === 1 ? " Level)" : " Levels)");
}


// Level count for a playData id: shipped versions declare it, custom levels are
// however many the user has built.
function playVersionLevelCount(id)
{
	if(id == PLAY_DATA_USERDEF) return (typeof editLevels === "number" && editLevels > 0) ? editLevels : 0;
	var v = findPlayVersionInfo(id);
	return v ? v.levelCount : 0;
}

// The per-version record (release year, platform, publisher, ...) as
// [key, value, url] triples. The source arrays are display rows for the old
// canvas info dialog -- "Release year : 1983, 1984" -- so split each on its
// first colon. TEXT_LINK rows carry a real url, kept so the value can be a
// link rather than dead text.
function playVersionFacts(id)
{
	var v = findPlayVersionInfo(id);
	if(!v || !v.info) return [];

	var facts = [];
	for(var i = 0; i < v.info.length; i++) {
		var row = v.info[i];
		if(row.type == 'TITLE') continue;

		if(row.type == 'TEXT_LINK') {
			facts.push([row.text.replace(/\s*:\s*$/, "").trim(), row.textLink, row.url]);
			continue;
		}
		var text = row.contain;
		var at = text.indexOf(':');
		if(at < 0) facts.push(["", text.trim()]);
		else facts.push([text.slice(0, at).trim(), text.slice(at + 1).trim()]);
	}
	return facts;
}
function playDataToTitleName(verId)
{
	if(verId == PLAY_DATA_USERDEF) return playDataNameUserDef;
	
	for(var i = 0; i < playVersionInfo.length; i++) {
		if(playVersionInfo[i].id == verId) return playVersionInfo[i].name;
	}
	
	error("design error, id =" + verId );
	return "Unknown";
}
