//=============================================================================
// Pure share-level zip/unzip codec (CreateJS/DOM-free).
// Extracted from lodeRunner.share.js for characterization tests.
// Depends on: NO_OF_TILES_X, NO_OF_TILES_Y, assert, error (globals).
//=============================================================================

var zipIdToMap = [' ', '#', '@', 'H', '-', 'X', 'S', '$', '0', '&'];
var mapToZipId = { ' ': 0, '#': 1, '@': 2, 'H': 3, '-': 4, 'X': 5, 'S': 6, '$': 7, '0': 8, '&': 9 };

// value range [1..52] ==> A..Z + a..z
// (01-26) ==> 'A'-'Z' (0x41 - 0x5A)
// (27-52) ==> 'a'-'z' (0x61 - 0x7A)
function value2OutValue(value)
{
	assert(value >= 1 && value <= 52, "Error: value not in range 1..52");

	if (value <= 26) {
		var outValue = String.fromCharCode(value - 1 + 'A'.charCodeAt(0)); //'A' ==> 1 , 'B' ==> 2 ...
	} else {
		var outValue = String.fromCharCode(value - 27 + 'a'.charCodeAt(0)); //'a' ==> 27 , 'b' ==> 28 ...
	}
	return outValue;
}

function getShareChecksum(strData)
{
	var checksum = 0;
	for (var i = 0; i < strData.length; i++) {
		checksum += strData.charCodeAt(i);
	}
	return value2OutValue((checksum & 0x1F) + 1); //1..32
}

function appendZipTile(tileType, tileCount)
{
	var rcTile = '';

	var outTile = String.fromCharCode(mapToZipId[tileType] + '0'.charCodeAt(0)); //0 ==> '0' , 1 ==> '1'
	switch (tileCount) {
		case 0:
			error("design error, tileType = None");
			break;
		case 1:
			rcTile = outTile;
			break
		case 2:
			rcTile = outTile + outTile;
			break;
		default:
			outCount = value2OutValue(tileCount);
			rcTile = outCount + outTile
			break;
	}
	return rcTile;
}

function zipLevelMap(level)
{
	var zipLevel = "";

	assert(level.length == (NO_OF_TILES_X * NO_OF_TILES_Y), "Error: zipShareLevel tiles != totalTiles");

	var lastTile = '';   // begin with a fake tile
	var tileCount = 0;
	var checksum = 0;  // checksum

	for (var tileIdx = 0; tileIdx < level.length; tileIdx++) {
		curTile = level.charAt(tileIdx);
		checksum += mapToZipId[curTile]; //XOR
		if (lastTile == curTile) {
			tileCount += 1;
			if (tileCount < 52) continue; // the maximun compress count = 52 (a-z + A-Z)
			else curTile = ''; //fake tile
		}

		if (tileCount > 0) zipLevel += appendZipTile(lastTile, tileCount);

		lastTile = curTile;
		if (lastTile == '') tileCount = 0; // compress count > max compress count (append a fake tile)
		else tileCount = 1;
	}

	if (tileCount > 0) zipLevel += appendZipTile(lastTile, tileCount);
	zipLevel += value2OutValue((checksum & 0x1F) + 1); // checksum 1..32

	return zipLevel;

}

function unzipLevelMap(zipLevel)
{
	var dupNum = 1;
	var unzipLevel = '';
	var checksum = 0;
	var caseType = 1;

	for (var curIdx = 0; curIdx < zipLevel.length && caseType > 0; curIdx++) {
		curChar = zipLevel.charAt(curIdx);
		switch (true) {
			case curChar >= '0' && curChar <= '9': // tileType
				caseType = 1;
				tileIdx = curChar.charCodeAt(0) - '0'.charCodeAt(0);
				unzipLevel += Array(dupNum + 1).join(zipIdToMap[tileIdx]); // char * dupNum
				checksum += (tileIdx * dupNum);
				dupNum = 1
				break;
			case curChar >= 'A' && curChar <= 'Z': // dup number 1-26
				if (dupNum > 1) {
					caseType = -1; //error
					error("Error: before A-Z still a dupNumber");
				} else {
					caseType = 2;
					dupNum = curChar.charCodeAt(0) - 'A'.charCodeAt(0) + 1;
				}
				break;
			case curChar >= 'a' && curChar <= 'z': // dup number 27-52
				if (dupNum > 1) {
					caseType = -1; //error
					error("Error: before a-z still a dupNumber");
				} else {
					caseType = 2;
					dupNum = curChar.charCodeAt(0) - 'a'.charCodeAt(0) + 27;
				}
				break;
			default:
				caseType = -1; //error
				error("Error: wrong tileType = '" + curChar + "'");
				break;
		}
	}

	if (caseType < 0) return ''; // Error

	checksum = (checksum & 0x1F) + 1;  // 1..32

	if (caseType != 2 || checksum != dupNum) {
		error("Error: wrong checksum !");
		return '';
	} else if (unzipLevel.length != (NO_OF_TILES_X * NO_OF_TILES_Y)) {
		error("Error: wrong tile size (" + unzipLevel.length + ") !");
		return '';
	}

	return unzipLevel;
}
