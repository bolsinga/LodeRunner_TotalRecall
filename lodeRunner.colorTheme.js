//=============================================================================
// Theme recolor: sample original solid hue, build tinted bitmaps per color id.
// Pixel work is plain canvas + getImageData/putImageData (no offscreen Stage).
//=============================================================================

var baseBitmapName = [
	"empty", "brick", "solid", "ladder", "rope",
	"trapBrick", "hladder", "gold", "redhat", "guard1", "runner1",
	"runner", "guard", "hole", "ground", "over", "text"
];


var themeColor = {};
themeColor[THEME_APPLE2] = [
	null,      //original image color
	"#60C0A0",
	"#DD8D5D",
	"#BA9F55",
	"#959CA5",
];

themeColor[THEME_C64] = [
	null,     //original image color
	"#DF5050",
	"#F7993E",
	"#4A4AFF",
	"#2E8B57"
];

var maxThemeColor = themeColor[THEME_APPLE2].length;
var themeBaseBitmap = {};
var curColorId = {};
var orgImageColor = {};
var themeNameList = [THEME_APPLE2, THEME_C64];

function createBaseBitmapInstance()
{
	// Active theme only at boot; ensureThemeLoaded builds the other on first toggle.
	ensureThemeBaseBitmaps(curTheme);
	
	//for edit mode only 
	themeBaseBitmap["eraser"] = createBitmap("eraser", null, null);
}

function ensureThemeBaseBitmaps(themeName)
{
	if (!(themeName in orgImageColor)) {
		orgImageColor[themeName] = getOrgImageColor(themeName);
	}
	var id = curColorId[themeName];
	createThemeBaseBitmap(themeName, hexToRGB(themeColor[themeName][id]), id);
}

function createThemeBaseBitmap(themeName, newColor, id)
{
	var oldColor = orgImageColor[themeName]; //get original image color

	for(var i=0; i < baseBitmapName.length; i++){
		var imageName = baseBitmapName[i]+themeName;
		if( (imageName+id) in themeBaseBitmap) 
			return;
		themeBaseBitmap[imageName+id] = createBitmap(imageName, oldColor, newColor);
	}
}

function getThemeBitmap(name)
{
	if(name == "eraser") return themeBaseBitmap[name].clone(); //for edit mode only
	
	return themeBaseBitmap[name+ curTheme+curColorId[curTheme]].clone();
}

/** Image source for the active theme tile (no clone). */
function getThemeBitmapImage(name)
{
	var bmp = (name == "eraser")
		? themeBaseBitmap[name]
		: themeBaseBitmap[name + curTheme + curColorId[curTheme]];
	return bmp ? bmp.image : null;
}

function getThemeImage(name) 
{
	return preload.getResult(name);
}

function getThemeTileColor(id)
{
	var curId = (typeof id != 'undefined')?id:curColorId[curTheme];
	
	if(curId == 0) return rgbToHex(orgImageColor[curTheme]); //original color	
	
	return themeColor[curTheme][curId];
}

function getCurColorId()
{
	return curColorId[curTheme];
}

//2D context that will be read back via getImageData
function themeReadbackContext(canvas)
{
	return canvas.getContext("2d", { willReadFrequently: true });
}

function getOrgImageColor(themeName)
{
	var img = getThemeImage("solid"+themeName); //"solid" as sample image
	var canvas = document.createElement("canvas");
	canvas.width = img.naturalWidth || img.width;
	canvas.height = img.naturalHeight || img.height;
	var ctx = themeReadbackContext(canvas);
	ctx.drawImage(img, 0, 0);

	var imgData = ctx.getImageData(0, 0, canvas.width, canvas.height);
	return [imgData.data[0], imgData.data[1], imgData.data[2]];
}

function createBitmap(imageName, oldColor, newColor)
{
	var img = getThemeImage(imageName);
	var tintedCanvas;

	if (newColor != null && (tintedCanvas = changeImageColor(img, oldColor, newColor)) != null)
		return new CanvasBitmap(tintedCanvas); //color changed
	else
		return new CanvasBitmap(img);
}

//tint matching pixels on a copy of img; returns canvas or null if unchanged
function changeImageColor(img, oldColor, newColor)
{
	var canvas = document.createElement("canvas");
	canvas.width = img.naturalWidth || img.width;
	canvas.height = img.naturalHeight || img.height;
	var ctx = themeReadbackContext(canvas);
	ctx.drawImage(img, 0, 0);

	if (changeColor(canvas, oldColor, newColor)) return canvas;
	return null;
}

function changeColor(canvas, oldColor, newColor)
{
	var ctx = themeReadbackContext(canvas);
	var imgData=ctx.getImageData(0, 0, canvas.width, canvas.height);
	var data = imgData.data;
	var bitChanged = 0;
	
	// add a range compare for fix browser (Brave) color have bit different ?, 6/3/2021
	var oldMin = [oldColor[0]-2, oldColor[1]-2, oldColor[2]-2];
	var oldMax = [oldColor[0]+2, oldColor[1]+2, oldColor[2]+2];
	
	for (var i = 0; i < data.length; i += 4) {
		var red   = data[i + 0];
		var green = data[i + 1];
		var blue  = data[i + 2];
		if(oldMin[0] <= red   && red   <= oldMax[0] && 
		   oldMin[1] <= green && green <= oldMax[1] &&
		   oldMin[2] <= blue  && blue  <= oldMax[2]) 
		{
			data[i+0] = newColor[0];
			data[i+1] = newColor[1];
			data[i+2] = newColor[2];
			bitChanged = 1;
		}
	}
	ctx.putImageData(imgData, 0, 0);
	return bitChanged;
}

function themeColorChange(id)
{
	var newColor;

	if(curColorId[curTheme] == id) return; //don't need change 
	
	newColor = hexToRGB(themeColor[curTheme][id]);
	curColorId[curTheme] = id;
	createThemeBaseBitmap(curTheme, newColor, id)
	themeDataReset(0); //don't need reset sound instance
	
	setThemeColor();
	
	if(playMode == PLAY_EDIT) {
		if(editLevelModified()) saveTestState();
		stopEditInput();
		startEditMode();		
	} else {
		changeThemeScreen(); //real time change theme screen
	}
}

function hexToRGB(hex) 
{
    var result = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(hex);
    return result ? [ 
		parseInt(result[1], 16), 
		parseInt(result[2], 16), 
		parseInt(result[3], 16)
	] : null;
}

function rgbToHex(rgb)
{
	return "#" + 
		("00" + rgb[0].toString(16)).slice(-2)+
		("00" + rgb[1].toString(16)).slice(-2)+
		("00" + rgb[2].toString(16)).slice(-2);
}
