//=============================================================================
// Pure helpers: theme image/sound manifest entries for PreloadJS.
// Used by lodeRunner.preload.js; testable without CreateJS.
//=============================================================================

// id prefix -> image file stem (differs for solid/block and trapBrick/trap)
var THEME_IMAGE_FILES = [
	{ id: "empty", file: "empty" },
	{ id: "brick", file: "brick" },
	{ id: "solid", file: "block" },
	{ id: "ladder", file: "ladder" },
	{ id: "rope", file: "rope" },
	{ id: "trapBrick", file: "trap" },
	{ id: "hladder", file: "hladder" },
	{ id: "gold", file: "gold" },
	{ id: "guard1", file: "guard1" },
	{ id: "runner1", file: "runner1" },
	{ id: "runner", file: "runner" },
	{ id: "guard", file: "guard" },
	{ id: "redhat", file: "redhat" },
	{ id: "hole", file: "hole" },
	{ id: "ground", file: "ground" },
	{ id: "over", file: "over" },
	{ id: "text", file: "text" }
];

var THEME_SOUND_FILES = [
	{ id: "reborn", file: "born" },
	{ id: "dead", file: "dead" },
	{ id: "dig", file: "dig" },
	{ id: "getGold", file: "getGold" },
	{ id: "fall", file: "fall" },
	{ id: "down", file: "down" },
	{ id: "pass", file: "pass" },
	{ id: "trap", file: "trap" }
];

//image + sound LoadQueue items for one theme; C64 adds goldFinish1-6
function buildThemeAssetManifest(themeName, themeImagePath, themeSoundPath, noCache)
{
	var q = noCache || "";
	var list = [];
	var i, entry;

	for (i = 0; i < THEME_IMAGE_FILES.length; i++) {
		entry = THEME_IMAGE_FILES[i];
		list.push({
			src: themeImagePath + themeName + "/" + entry.file + ".png" + q,
			id: entry.id + themeName
		});
	}
	for (i = 0; i < THEME_SOUND_FILES.length; i++) {
		entry = THEME_SOUND_FILES[i];
		list.push({
			src: themeSoundPath + themeName + "/" + entry.file + ".ogg" + q,
			id: entry.id + themeName
		});
	}
	if (themeName === THEME_C64) {
		for (i = 1; i <= 6; i++) {
			list.push({
				src: themeSoundPath + themeName + "/goldFinish" + i + ".ogg" + q,
				id: "goldFinish" + i
			});
		}
	}
	return list;
}

function otherThemeName(themeName)
{
	return (themeName === THEME_C64) ? THEME_APPLE2 : THEME_C64;
}

//true for sound manifest entries (primary extension .ogg)
function isSoundAssetSrc(src)
{
	return /\.ogg(\?|$)/i.test(String(src));
}

//split LoadQueue-style items into images (PreloadJS) vs sounds (Web Audio)
function partitionAssetManifest(list)
{
	var images = [];
	var sounds = [];
	for (var i = 0; i < list.length; i++) {
		if (isSoundAssetSrc(list[i].src)) sounds.push(list[i]);
		else images.push(list[i]);
	}
	return { images: images, sounds: sounds };
}
