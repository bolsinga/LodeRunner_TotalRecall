//=================================================================================
// For share custom level to other players
// --------------------------------------------------------------------------------
// Version 1 url parameter format:
//
// ?shareLevel=[LEVEL DATA].[s]([v][m][t][r][creator][pading])
//
// [LEVEL DATA] : ZIP level data
// [s]: checksum ([v]..[pading])
// [v]: version = 1 [0]
// [m]: share mode (1:Fackbook, 2:twitter, 3:weibo, 4:link) [1] 
// [t]: theme mode (1:apple2, 2:c64) [2]
// [r]: reserved 3 bytes [3..5]
// [creator]: creator name [6-]
// [pading]: pading "@" let length([v]+[m]+[t]+[creator]+[pading]) multiplier of 3
//=================================================================================

var SHARE_DATA_VERSION = 1; 
var shareLevelData = [""];
var shareInfo = null; // { ver:1, mode:1-4 [m], theme:1-2 [t], creator: }
var shareFirstTime = 1;

function getQueryStringParameterValue(queryString, parameterName)
{
	var ParameterValue = "";
	var valueLength = 0
	queryString = decodeURIComponent(queryString); //url decode
	var beginIdxOfParameter = queryString.indexOf(parameterName + "="); 
	if (beginIdxOfParameter >= 0) {
		var startIdx = beginIdxOfParameter + parameterName.length + 1; // skip "parameterName=" 
		for (var endIdx=startIdx; 
			 queryString.charAt(endIdx) !='&' && endIdx < queryString.length; endIdx++) valueLength++;
		ParameterValue = queryString.substr(startIdx, valueLength);
	}
	return ParameterValue;
}

// getShareChecksum, value2OutValue, zip/unzip: lodeRunner.shareCodec.js

function getShareVerInfo(encUrlVerData)
{
	var verInfo = null;
	var infoChecksum = encUrlVerData.charAt(0); 
	var urlVerData = atob(encUrlVerData.substr(1,)); //base64 decode
	var strChecksum = getShareChecksum(urlVerData);
	var version = urlVerData.charAt(0);
	
	if(infoChecksum == strChecksum && (urlVerData.length % 3) == 0 && urlVerData.length >= 9 && version == '1') {
		var shareMode = urlVerData.charCodeAt(1)-'0'.charCodeAt(0);  //[m]
		var theme = urlVerData.charCodeAt(2)-'0'.charCodeAt(0);  //[t]
		var creator = urlVerData.substr(6,); //[creator]
		var creatorLength = creator.length;

		// remove last '@' chars
		while(creatorLength > 0) {
			if (creator.charAt(creatorLength-1) == '@') creatorLength--;
			else break;
		}
		if (creator.length != creatorLength) 
			creator = creator.substr(0, creatorLength);
		
		if(shareMode > 0 && shareMode <= 4 && theme > 0 && theme <=2 && creatorLength > 0 && vaildPlayerName(creator)) {
			verInfo = {};
			verInfo.ver = 1;
			verInfo.mode = shareMode;
			verInfo.theme = theme;
			verInfo.creator = creator;
		}
	}
	
	if(!verInfo) error("wrong verInfo");

	return verInfo;
}

function getShareUrlInfo() 
{
	if (!shareFirstTime) return;
	shareFirstTime = 0;
	
	var shareUrlData = getQueryStringParameterValue(location.search, "shareLevel");

	if (shareUrlData) {
		var dotPos = shareUrlData.indexOf(".");
		if (dotPos > 0) {
			var unzipLevel = unzipLevelMap(shareUrlData.substr(0, dotPos));
			
			if(unzipLevel && shareUrlData.length > dotPos) {
				shareInfo = getShareVerInfo(shareUrlData.substr(dotPos+1,));
			}							 
										 
			if (shareInfo) {
				shareLevelData[0] = unzipLevel;
				copyShareLevelForEditing();

				playMode = PLAY_MODERN; 
				playData = PLAY_DATA_SHARE;
				
				/////////////////////////////////////////////////

				sendShareLevel2Server(unzipLevel, shareInfo, null); //new or update share count

				/////////////////////////////////////////////////			
			}
			
			// remove "share.html"
			var removeString = "/share.html";
			var removeLength = removeString.length;
			var newPathName = location.pathname;
			if(newPathName.substr(-removeLength) == removeString) 
				newPathName = newPathName.substr(0, newPathName.length-removeLength+1);
			//console.log(newPathName);
			
			// change URL to normal path (adds an entry to the browser's session history stack)
			history.pushState({}, "Lode Runner Web Game", newPathName);
		}
	}
}

function converLevel2ShareUrl(level, shareMode, creator)
{
	var theme =(curTheme == THEME_APPLE2)?1:2;
	var padingTimes = (3-creator.length%3) % 3;
	var zipLevel = zipLevelMap(level);
	var verInfo = `1${shareMode}${theme}   ${creator}${'@'.repeat(padingTimes)}`;
	var checksum = getShareChecksum(verInfo);
	
	var leftSlash = location.pathname.lastIndexOf("/");
	var pathName = leftSlash < 0 ? "/": location.pathname.substr(0,leftSlash+1);
	var host = location.host;
	
	//host = "loderunnerwebgame.com/game";
	
	return location.protocol + "//" + host + pathName + "share.html?shareLevel=" + zipLevel + "." + checksum + encodeURIComponent(btoa(verInfo));
}

// zipIdToMap, mapToZipId, value2OutValue, appendZipTile, zipLevelMap, unzipLevelMap:
// see lodeRunner.shareCodec.js

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
// (3) level map data: 
//     ------------------------------
//     v1:
//         +----- startLevelPos
//         V
//          \n tile * NO_OF_TILES_X 
//          \n tile * NO_OF_TILES_X
//            ....
//          \n tile * NO_OF_TILES_X
//          \n checksum
//     ------------------------------
//     v2:
//         \n zipLevelData
//         \n zipLevelData
//         .......
//         \n zipLevelData
//         \n
//     ------------------------------
// ==============================================================================================
function backupCustomLevelData(date)
{
	var curTimeInfo = getLocalTimeZone(date);
	var headerInfo = LRWG_FILE_START_INFO + curTimeInfo + "." + playerName + "."; 
	var levelSize = ("0" + editLevels.toString(16)).slice(-2); 
	var fileSize = encodeURI(headerInfo).replace(/%../g,'.').length + 20; //20 : length of zipInfo
	var zipLevelData = "";
	var zipChecksum = 0; 
	
	/* version 1
	var verInfo = '1';
	for(var i = 0; i < editLevels; i++) {
		var curLevel = editLevelData[i];
		for(var startPos = 0; startPos < curLevel.length; startPos += NO_OF_TILES_X) {
			zipLevelData += '\n' + curLevel.substr(startPos, NO_OF_TILES_X);
		}
		zipLevelData += '\n' + getShareChecksum(curLevel);
	}
	*/
	
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
