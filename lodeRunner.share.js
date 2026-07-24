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
