//=============================================================================
// Play-version registry: level/demo pack metadata + lazy ensure helpers.
// Menu UI init stays in lodeRunner.menu.js.
//=============================================================================

var playVersionInfo = [
	// classic is in lodeRunner.html; others lazy-loaded via ensurePlayVersionLoaded()
	{ id:1, globalName: "classicData",  script: null,                           demoScript: "lodeRunner.wData.1.js", demoGlobal: "wfastDemoData1", levelCount: 150, name: gameVersionName[0], info: classicInfo },
	{ id:3, globalName: "proData",      script: "lodeRunner.v.professional.js", demoScript: "lodeRunner.wData.3.js", demoGlobal: "wfastDemoData3", levelCount: 150, name: gameVersionName[2], info: proInfo },
	{ id:4, globalName: "revengeData",  script: "lodeRunner.v.revenge.js",      demoScript: "lodeRunner.wData.4.js", demoGlobal: "wfastDemoData4", levelCount: 17,  name: gameVersionName[3], info: revengeInfo },
	{ id:5, globalName: "fanBookData",  script: "lodeRunner.v.fanBookMod.js",   demoScript: "lodeRunner.wData.5.js", demoGlobal: "wfastDemoData5", levelCount: 66,  name: gameVersionName[4], info: fanBookInfo },
	{ id:2, globalName: "championData", script: "lodeRunner.v.championship.js", demoScript: "lodeRunner.wData.2.js", demoGlobal: "wfastDemoData2", levelCount: 51,  name: gameVersionName[1], info: championInfo }
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
	var info = findPlayVersionInfo(id);
	if (info && isGlobalDefined(info.globalName)) {
		return window[info.globalName];
	}
	
	error("Error: versionData not loaded, id = " + id );
	return classicData;
}

function getPlayVerInfo(id) 
{
	var info = findPlayVersionInfo(id);
	if (info) return info.info;
	
	error("Error: version info can not find, id = " + id );
	return playVersionInfo[0].info;
}

function defaultLevelData()
{
	return classicData;
}

function menuIdToPlayData(menuId)
{
	if(menuId == playVersionInfo.length) return PLAY_DATA_USERDEF; //user created
	else if (menuId < playVersionInfo.length) return playVersionInfo[menuId].id;
	
	error("design error, menuId =" + menuId );
	
	return playVersionInfo[0].id;
}

var playDataNameUserDef = "Custom Levels";
function playDataToTitleName(verId)
{
	if(verId == PLAY_DATA_USERDEF) return playDataNameUserDef;
	
	for(var i = 0; i < playVersionInfo.length; i++) {
		if(playVersionInfo[i].id == verId) return playVersionInfo[i].name;
	}
	
	error("design error, id =" + verId );
	return "Unknown";
}
