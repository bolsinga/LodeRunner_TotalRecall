//=============================================================================
// Custom-level backup / restore (zip codec lives in lodeRunner.shareCodec.js)
//=============================================================================

// ==============================================================================================
// Generate custom level backup data
//
// (1) HeaderInfo: "LODE RUNNER WEB GAME.2021-06-08 12:09:08 GMT+0800 (台北標準時間).player."
// (2) zipInfo: [v][l][s][c]
//
//     [v]: version  [0]     ==> 1 or 2
//     [l]: levels   [1:2]   ==> [01-FF]
//     [s]: size     [3:8]   ==> [000000-FFFFFF]
//     [c]: checksum [9:12]  ==> [0000-FFFF]
//     [r]: reserved [13:14] ==> "LR"
//
// (3) level map data (v2):
//         \n zipLevelData
//         \n zipLevelData
//         .......
//         \n zipLevelData
//         \n
//==============================================================================================
function backupCustomLevelData(date)
{
	var curTimeInfo = getLocalTimeZone(date);
	var headerInfo = LRWG_FILE_START_INFO + curTimeInfo + "." + playerName + ".";
	var levelSize = ("0" + editLevels.toString(16)).slice(-2);
	var fileSize = encodeURI(headerInfo).replace(/%../g,'.').length + 20; //20 : length of zipInfo
	var zipLevelData = "";
	var zipChecksum = 0;

	var verInfo = '2';
	for(var i = 0; i < editLevels; i++) {
		zipLevelData += '\n' + zipLevelMap(editLevelData[i]); // \nzipLevel \nzipLevel.... \nzipLevel
	}
	zipLevelData += '\n'; // \nzipLevel \nzipLevel.... \nzipLevel \n

	for(var i = 0; i < zipLevelData.length; i++) {
		zipChecksum += zipLevelData.charCodeAt(i);
	}

	zipChecksum = ("000" + (zipChecksum & 0xFFFF).toString(16)).slice(-4);
	fileSize = ("00000" + (fileSize + zipLevelData.length).toString(16)).slice(-6);
	var zipInfo = btoa(verInfo + levelSize + fileSize + zipChecksum + "LR");
	return headerInfo + zipInfo + zipLevelData;
}

// Parse a .lrwg custom-level file. byteSize is File.size (must match the header).
// Returns { ok:true, levels:string[] } or { ok:false, error:string }.
function parseLrwgFile(fileData, byteSize)
{
	var maxFileSize = 150 + NO_OF_TILES_X * NO_OF_TILES_Y * 256;
	var newLinePos = fileData.indexOf('\n');
	if(newLinePos < 0) return { ok: false, error: "wrong header" };

	var headerLine = fileData.substr(0, newLinePos);
	var lastDotPos = headerLine.lastIndexOf('.');
	if(lastDotPos < 0 || newLinePos - lastDotPos != 21)
		return { ok: false, error: "wrong fileInfo" };

	var fileInfo;
	try {
		fileInfo = atob(headerLine.substr(lastDotPos + 1));
	} catch(e) {
		return { ok: false, error: "wrong base64" };
	}

	var verInfo = fileInfo.charAt(0);
	if(verInfo != '1' && verInfo != '2')
		return { ok: false, error: "wrong fileInfo.version (" + verInfo + ")" };
	if(fileData.indexOf(LRWG_FILE_START_INFO) != 0)
		return { ok: false, error: "wrong startInfo" };

	var totalLevels = parseInt(fileInfo.substr(1, 2), 16);
	var fileSize = parseInt(fileInfo.substr(3, 6), 16);
	var fileChecksum = parseInt(fileInfo.substr(9, 4), 16);

	if(totalLevels > MAX_EDIT_LEVEL || totalLevels <= 0)
		return { ok: false, error: "wrong edit levels (" + totalLevels + ")" };
	if(byteSize > maxFileSize)
		return { ok: false, error: "file size too large (" + byteSize + ")" };
	if(fileSize != byteSize)
		return { ok: false, error: "wrong file size" };

	var levelData = fileData.substr(newLinePos);
	var dataChecksum = 0;
	for(var i = 0; i < levelData.length; i++)
		dataChecksum += levelData.charCodeAt(i);
	if(fileChecksum != (dataChecksum & 0xFFFF))
		return { ok: false, error: "wrong file checksum" };

	var levels = [];
	if(verInfo == '1') {
		var oneLevelSize = (NO_OF_TILES_X + 1) * NO_OF_TILES_Y + 2;
		if(levelData.length != totalLevels * oneLevelSize)
			return { ok: false, error: "wrong levels data size (1)" };

		for(var curLevel = 0; curLevel < totalLevels; curLevel++) {
			var startLevelPos = curLevel * oneLevelSize + 1;
			var curLevelMap = '';
			for(var tileY = 0; tileY < NO_OF_TILES_Y; tileY++)
				curLevelMap += levelData.substr(startLevelPos + tileY * (NO_OF_TILES_X + 1), NO_OF_TILES_X);
			var checksum = levelData.charAt(startLevelPos + oneLevelSize - 2);
			if(checksum != getShareChecksum(curLevelMap))
				return { ok: false, error: "wrong level checksum (" + (curLevel + 1) + ")" };
			levels.push(curLevelMap);
		}
	} else {
		var startPos = 1, nextNewLinePos, curMap;
		for(var lv = 0; lv < totalLevels; lv++) {
			nextNewLinePos = levelData.indexOf('\n', startPos);
			if(nextNewLinePos < 0)
				return { ok: false, error: "wrong level data @" + (lv + 1) };
			curMap = unzipLevelMap(levelData.substr(startPos, nextNewLinePos - startPos));
			if(!curMap)
				return { ok: false, error: "wrong ziplevel data @" + (lv + 1) };
			levels.push(curMap);
			startPos = nextNewLinePos + 1;
		}
		if(levelData.length != startPos)
			return { ok: false, error: "wrong levels data size (2)" };
	}

	return { ok: true, levels: levels };
}
