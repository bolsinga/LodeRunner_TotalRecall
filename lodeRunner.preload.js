var RUNNER_SPEED = 0.65;  
var DIG_SPEED = 0.68;    //for support champLevel, change DIG_SPEED and FILL_SPEED, 2014/04/12
var FILL_SPEED = 0.24;
var GUARD_SPEED = 0.3;

var FLASH_SPEED = 0.25; //for flash cursor (hi-score input mode)

var COVER_PROGRESS_BAR_H = 32;
var COVER_PROGRESS_UNDER_Y = 90;
var COVER_RUNNER_UNDER_Y = 136;
var COVER_SIDE_X = 56;		

var SIGNET_UNDER_X = 30;
var SIGNET_UNDER_Y = 30;

// Cover load clock: Stage used to be the Ticker listener; owned clock presents instead.
function coverPresentTick()
{
	worldDisplay.advance(null);
	stagePresent();
}

//*********************
// preload cover page
//*********************
var coverBitmap, titleBackground, remakeBitmap, signetBitmap;
var noCache = "?" + VERSION+ ".1051230";

function showLoadingPage() 
{
	var coverPageImages = [
		{ src: "image/cover.png"+noCache,  id: "cover" },
		{ src: themeImagePath + THEME_APPLE2 + "/runner.png"+noCache,  id: "runner" }
	];

	assetLoadManifest(coverPageImages, {
		onFileLoad: handleCoverPageFileLoad,
		onError: function (e) { console.log("error", e); }
	}).then(function () {
		preloadResource();
	});

	function handleCoverPageFileLoad(e)
	{
		switch(e.item.id) {	
		case "cover":	
			addCover2Screen(e.result);
			break;
		case "runner":
			createRunnerSpriteSheet(e.result);
			break;
		} 
	}
		
	function addCover2Screen(image)
	{
		coverBitmap = new CanvasBitmap(image);
		coverBitmap.setTransform(0, 0, tileScale, tileScale); //x,y, scaleX, scaleY 
		
		addTitleBackground(coverBitmap.getBounds().width*tileScale|0,
		                   coverBitmap.getBounds().height*tileScale|0);
		
		worldDisplay.add(coverBitmap);	
		stagePresent();
	}
	
	function addTitleBackground(width, height)
	{
		titleBackground = new TitleBackground(width, height);
		worldDisplay.add(titleBackground);
	}
}

function TitleBackground(width, height)
{
	CanvasObject.call(this);
	this.w = width;
	this.h = height;
	this.rainbow = false;
}
TitleBackground.prototype = Object.create(CanvasObject.prototype);
TitleBackground.prototype.constructor = TitleBackground;
TitleBackground.prototype.getBounds = function()
{
	return { x:0, y:0, width:this.w, height:this.h };
};
TitleBackground.prototype.draw = function(ctx)
{
	if(this.rainbow) {
		var g = ctx.createLinearGradient(0, this.h/5, this.w*6/5, this.h*2/5);
		var colors = ["#FF0000", "#FF7F00", "#FFFF00", "#00FF00", "#0000FF", "#4B0082", "#8B00FF"];
		var stops = [0, .14, .28, .42, .56, .70, .84];
		for(var i = 0; i < colors.length; i++) g.addColorStop(stops[i], colors[i]);
		ctx.fillStyle = g;
	} else {
		ctx.fillStyle = "white";
	}
	ctx.fillRect(0, 0, this.w, this.h);
};

function createRunnerSpriteSheet(runnerImage)
{
	runnerData = makeSpriteSheet({
		images: [runnerImage],
		
		frames: { regX:0, height: BASE_TILE_Y,  regY:0, width: BASE_TILE_X},
		
		animations: { 
			runRight: [0,2, "runRight", RUNNER_SPEED], 
			runLeft : [3,5, "runLeft",  RUNNER_SPEED], 
			runUpDn : [6,7, "runUpDn",  RUNNER_SPEED],

			barRight: {
				frames: [ 18, 19, 19, 20, 20 ],
				next:  "barRight",
				speed: RUNNER_SPEED
			},

			barLeft: {
				frames: [ 21, 22, 22, 23, 23 ],
				next:  "barLeft",
				speed: RUNNER_SPEED
			},
					 
			digRight: 24,
			digLeft : 25,

			fallRight : 8,
			fallLeft: 26
		} 
	});
}

//*****************************************************************************		
//BEGIN of preload		
//*****************************************************************************		
var firstPlay = 0;

var runnerData;
var guardData = {}, redhatData = {};
var holeData, holeObj = {};
var textData;
var textAtlas; //owned glyph atlas (lodeRunner.glyphFont.js) over the text image

var soundFall, soundDig, soundPass, soundEnding;

var themeImagePath = "image/Theme/";
var themeSoundPath = "sound/Theme/";

/** Themes whose image/sound packs are already cached. */
var themeAssetsLoaded = {};
var themeSwitchPending = 0;

function isThemeAssetsLoaded(themeName)
{
	return !!themeAssetsLoaded[themeName];
}

/**
 * Ensure theme sprites/sounds are loaded, then build color bitmaps.
 * callback() always runs (even if already loaded).
 */
function ensureThemeLoaded(themeName, callback)
{
	if (themeAssetsLoaded[themeName]) {
		ensureThemeBaseBitmaps(themeName);
		if (callback) callback();
		return;
	}

	var manifest = buildThemeAssetManifest(themeName, themeImagePath, themeSoundPath, noCache);
	var parts = partitionAssetManifest(manifest);
	var imagesDone = parts.images.length === 0;
	var soundsDone = parts.sounds.length === 0;
	var finished = false;

	function done()
	{
		if (finished || !imagesDone || !soundsDone) return;
		finished = true;
		themeAssetsLoaded[themeName] = 1;
		ensureThemeBaseBitmaps(themeName);
		if (callback) callback();
	}

	if (!imagesDone) {
		assetLoadManifest(parts.images, {
			onError: function (e) { console.log("error", e); }
		}).then(function () {
			imagesDone = true;
			done();
		});
	}
	if (!soundsDone) {
		soundLoadManifest(parts.sounds).then(function () {
			soundsDone = true;
			done();
		}).catch(function (err) {
			console.log("ensureThemeLoaded sound error", err);
			soundsDone = true;
			done();
		});
	}
	if (imagesDone && soundsDone) done();
}

function preloadResource() 
{
	var runnerSprite = new GameSprite(runnerData, "runRight");
	var progress = new CanvasShape();
	var progressBorder = new CanvasShape();
	var percentTxt = new CanvasText("0", (COVER_PROGRESS_BAR_H* tileScale) + "px Arial", "#FF0000");

	// Shared UI / SFX + active theme only (other theme loads on first toggle).
	var resource = [
		{ src: "image/remake.png"+noCache,  id: "remake" },
		{ src: "image/signet.png"+noCache,  id: "signet" },

		{ src: "image/eraser.png"+noCache,  id: "eraser" },
	
		{ src: "sound/goldFinish.ogg"+noCache,  id:"goldFinish"},
		{ src: "sound/ending.ogg"+noCache,      id:"ending"},
		{ src: "sound/scoreBell.ogg"+noCache,   id:"scoreBell"},
		{ src: "sound/scoreCount.ogg"+noCache,  id:"scoreCount"},
		{ src: "sound/scoreEnding.ogg"+noCache, id:"scoreEnding"},
		
		{ src: "sound/beep.ogg"+noCache, id:"beep"},
		
		{ src: "cursor/openhand.cur"+noCache, id:"openHand"}, //preload cursor
		{ src: "cursor/closedhand.cur"+noCache, id:"closeHand"}
		
	].concat(buildThemeAssetManifest(curTheme, themeImagePath, themeSoundPath, noCache));

	var parts = partitionAssetManifest(resource);
	var imgProgress = 0;
	var soundProgress = 0;
	var imagesDone = parts.images.length === 0;
	var soundsDone = parts.sounds.length === 0;
	var loadCompleted = false;

	setClockFps(30);
	addClockListener(coverPresentTick);

	//Set runner sprite size & position
	runnerSprite.setTransform(COVER_SIDE_X* tileScale, 
							  (BASE_SCREEN_Y - COVER_RUNNER_UNDER_Y)* tileScale,
							  tileScale, 
							  tileScale);
	runnerSprite.gotoAndPlay();	

	var width = canvas.width - 2*COVER_SIDE_X* tileScale;
	var height = COVER_PROGRESS_BAR_H * tileScale;

	//Set progress & progressborder size & position
	progressBorder.strokeRect("gold", 1, 0, 0, width, height);
	progress.x = progressBorder.x = COVER_SIDE_X * tileScale;
	progress.y = progressBorder.y = (BASE_SCREEN_Y - COVER_PROGRESS_UNDER_Y) * tileScale;
	
	//Set percentTxt position
	percentTxt.x = (canvas.width - percentTxt.getBounds().width) / 2 | 0;
	percentTxt.y = (BASE_SCREEN_Y - COVER_PROGRESS_UNDER_Y) * tileScale + height/12;  // move percent number Lower
	
	worldDisplay.add(runnerSprite);
	worldDisplay.add(progress);
	worldDisplay.add(progressBorder);
	worldDisplay.add(percentTxt);
	
	function updateCombinedProgress()
	{
		var imgW = parts.images.length;
		var soundW = parts.sounds.length;
		var totalW = imgW + soundW;
		var ratio = totalW ? ((imgProgress * imgW) + (soundProgress * soundW)) / totalW : 1;
		progress.clearOps().fillRect("gold", 0, 0, width*ratio, height);
		percentTxt.text = (100*ratio|0) + "%";
		percentTxt.x = (canvas.width - percentTxt.getBounds().width) / 2 | 0;
	}

	function maybeHandleComplete()
	{
		if (loadCompleted || !imagesDone || !soundsDone) return;
		loadCompleted = true;
		handleComplete();
	}

	// Start loads after progress UI exists (onProgress may fire synchronously).
	if (!imagesDone) {
		assetLoadManifest(parts.images, {
			onProgress: function (loaded, total) {
				imgProgress = total ? (loaded / total) : 1;
				updateCombinedProgress();
			},
			onError: function (e) { console.log("error", e); }
		}).then(function () {
			imagesDone = true;
			imgProgress = 1;
			updateCombinedProgress();
			maybeHandleComplete();
		});
	}
	if (!soundsDone) {
		soundLoadManifest(parts.sounds, function (loaded, total) {
			soundProgress = total ? (loaded / total) : 1;
			updateCombinedProgress();
		}).then(function () {
			soundsDone = true;
			maybeHandleComplete();
		}).catch(function (err) {
			console.log("sound load error", err);
			soundsDone = true;
			maybeHandleComplete();
		});
	} else {
		soundProgress = 1;
	}
	if (imagesDone) {
		imgProgress = 1;
		maybeHandleComplete();
	}

	function handleComplete() 
	{
		themeAssetsLoaded[curTheme] = 1;

		percentTxt.text = "100%";
		stagePresent();

		createSoundInstance();
		createBaseBitmapInstance(); //9/1/2016
		setTimeout(clearLoadingInfo, 500);
	}
	
	function clearLoadingInfo()
	{
		worldDisplay.remove(runnerSprite);
		worldDisplay.remove(progress);
		worldDisplay.remove(progressBorder);
		worldDisplay.remove(percentTxt);
		colorTitleBackground();
		showSignetBitmap();
		worldDisplay.add(signetBitmap);
		showRemakeBitmap();
		worldDisplay.add(remakeBitmap);
		stagePresent();
	}
	
	//change title color to rainbow gradient color
	function colorTitleBackground()
	{
		titleBackground.rainbow = true;
	}
	
	function showSignetBitmap()
	{
		var x, y;
		signetBitmap = new CanvasBitmap(preload.getResult("signet"));
		x = (BASE_SCREEN_X - SIGNET_UNDER_X - signetBitmap.getBounds().width )* tileScale;
		y = (BASE_SCREEN_Y - SIGNET_UNDER_Y - signetBitmap.getBounds().height)* tileScale;
		signetBitmap.setTransform(x, y, tileScale, tileScale); //x,y, scaleX, scaleY 
		signetBitmap.set({alpha:0.8});
		tweenGet(signetBitmap).set({alpha:0.8}).to({alpha:1}, 500);
	}	
	
	//create remake image 
	function showRemakeBitmap()
	{
		var x = 372 * tileScale;
		var y = 130 * tileScale;
		remakeBitmap = new CanvasBitmap(preload.getResult("remake"));
		remakeBitmap.setTransform(x, y, tileScale, tileScale); //x,y, scaleX, scaleY 
		remakeBitmap.rotation = -5;
		remakeBitmap.set({alpha:0.6});
		tweenGet(remakeBitmap).set({alpha:0.6}).to({alpha:1}, 800).call(preloadComplet);
	}
	
	function preloadComplet()
	{
		getFirstPlayInfo();
		removeClockListener(coverPresentTick); //remove ticker of cover page
		waitIdleDemo(4000); //wait user key or show demo level
	}
}

function createSoundInstance()
{
	soundFall = soundCreateInstance("fall" + curTheme); 
	soundDig = soundCreateInstance("dig" + curTheme);
	soundPass = soundCreateInstance("pass" + curTheme);
	
	soundEnding = soundCreateInstance("ending"); //for training mode only 
	
}

//==============================
// support different AI-version 
//==============================

var spriteSpeed = [
	{ runnerSpeed: 0.65, guardSpeed: 0.3,  digSpeed: 0.68, fillSpeed: 0.24, xMoveBase: 8, yMoveBase: 8 }, //ver 1
	{ runnerSpeed: 0.70, guardSpeed: 0.35, digSpeed: 0.68, fillSpeed: 0.27, xMoveBase: 8, yMoveBase: 9 }, //ver 2
	{ runnerSpeed: 0.8,  guardSpeed: 0.4,  digSpeed: 1,    fillSpeed: 1,    xMoveBase: 8, yMoveBase: 9 }  //ver 3 & 4 
];

var curAiVersion = AI_VERSION;
var maxGuard = MAX_NEW_GUARD; 
function setSpeedByAiVersion()
{
	var idx = (curAiVersion > spriteSpeed.length)?(spriteSpeed.length-1):(curAiVersion-1); //array index don't overflow
	var speedObj = spriteSpeed[idx];
	
	RUNNER_SPEED = speedObj.runnerSpeed;
	GUARD_SPEED = speedObj.guardSpeed;
	DIG_SPEED = speedObj.digSpeed;
	FILL_SPEED = speedObj.fillSpeed;
	
	xMove = speedObj.xMoveBase; 
 	yMove = speedObj.yMoveBase;
	
	//------------------------------------------------------------------------------------
	// Change move policy for support LR FAN BOOK with one guard 
	// Original policy for one guard is [0, 1, 1] ==> 2/3 speed of runner 
	// while AI_VERSION >= 3 change policy to [ 0, 1, 0, 1, 0, 1 ] ==> 1/2 speed of runner
	//------------------------------------------------------------------------------------
	if(curAiVersion < 3) {
		movePolicy[1] = [0, 1, 1, 0, 1, 1];
		maxGuard = MAX_OLD_GUARD;
	} else {
		movePolicy[1] = [0, 1, 0, 1, 0, 1]; //slow down the guard when only one guard
		maxGuard = MAX_NEW_GUARD;           //change max guard 
	}
	
	themeDataReset(1); //4/16/2015
	createHoleObj();  //6/27/2016
}

function themeDataReset(resetAll)
{
	if(resetAll) createSoundInstance(); //Base on current theme
	createSpriteSheet();   //Base on theme & Ai Version
}

function createSpriteSheet()
{
	createRunnerSpriteSheet(getThemeBitmap("runner").image);
	createPreloadSpriteSheet();
}

function createPreloadSpriteSheet() 
{
	guardData = createGuardObj("guard");
	redhatData = createGuardObj("redhat");
		
	holeData = makeSpriteSheet( {
		images: [getThemeBitmap("hole").image],
		
		frames: [
			//dig hole Left
			[BASE_TILE_X*0,0,BASE_TILE_X,BASE_TILE_Y*2], //0 [x,y, width, height]
			[BASE_TILE_X*1,0,BASE_TILE_X,BASE_TILE_Y*2], //1
			[BASE_TILE_X*2,0,BASE_TILE_X,BASE_TILE_Y*2], //2
			[BASE_TILE_X*3,0,BASE_TILE_X,BASE_TILE_Y*2], //3
			[BASE_TILE_X*4,0,BASE_TILE_X,BASE_TILE_Y*2], //4
			[BASE_TILE_X*5,0,BASE_TILE_X,BASE_TILE_Y*2], //5
			[BASE_TILE_X*6,0,BASE_TILE_X,BASE_TILE_Y*2], //6
			[BASE_TILE_X*7,0,BASE_TILE_X,BASE_TILE_Y*2], //7
			
			//dig hole right
			[BASE_TILE_X*0,BASE_TILE_Y*2,BASE_TILE_X,BASE_TILE_Y*2], //08
			[BASE_TILE_X*1,BASE_TILE_Y*2,BASE_TILE_X,BASE_TILE_Y*2], //09
			[BASE_TILE_X*2,BASE_TILE_Y*2,BASE_TILE_X,BASE_TILE_Y*2], //10
			[BASE_TILE_X*3,BASE_TILE_Y*2,BASE_TILE_X,BASE_TILE_Y*2], //11
			[BASE_TILE_X*4,BASE_TILE_Y*2,BASE_TILE_X,BASE_TILE_Y*2], //12
			[BASE_TILE_X*5,BASE_TILE_Y*2,BASE_TILE_X,BASE_TILE_Y*2], //13
			[BASE_TILE_X*6,BASE_TILE_Y*2,BASE_TILE_X,BASE_TILE_Y*2], //14
			[BASE_TILE_X*7,BASE_TILE_Y*2,BASE_TILE_X,BASE_TILE_Y*2], //15
			
			//fill hole
			[BASE_TILE_X*7,BASE_TILE_Y*2,BASE_TILE_X,BASE_TILE_Y], //16
			[BASE_TILE_X*8,BASE_TILE_Y,  BASE_TILE_X,BASE_TILE_Y], //17
			[BASE_TILE_X*8,0,            BASE_TILE_X,BASE_TILE_Y], //18
			[BASE_TILE_X*8,BASE_TILE_Y*3,BASE_TILE_X,BASE_TILE_Y]  //19
		],	
		
		animations: { 
			digHoleLeft:  [0, 7, false, DIG_SPEED],
			digHoleRight: [8,15, false, DIG_SPEED],
			fillHole: { 
				frames: [16, 16, 16, 16, 16, 16, 16, 16, 16,
				         16, 16, 16, 16, 16, 16, 16, 16, 16,
				         16, 16, 16, 16, 16, 16, 16, 16, 16,
				         16, 16, 16, 16, 16, 16, 16, 16, 16, 
				         16, 16, 16, 16, 16, 16, 16, 16, 16,
				         17, 17, 18, 18, 19 ], //delay fill time for champLevel, 2014/04/12
				next:  false,
				speed: FILL_SPEED
			}	
		}
	});
	
	textData = makeSpriteSheet({
		images: [getThemeBitmap("text").image],
		
		frames: {regX:0, height: BASE_TILE_Y,  regY: 0, width: BASE_TILE_X},
		
		animations: { 
			"N0": 0, "N1": 1, "N2": 2, "N3": 3, "N4": 4, 
			"N5": 5, "N6": 6, "N7": 7, "N8": 8, "N9": 9,
			"A": 10, "B": 11, "C": 12, "D": 13, "E": 14, "F": 15, "G": 16, "H": 17,
			"I": 18, "J": 19, "K": 20, "L": 21, "M": 22, "N": 23, "O": 24, "P": 25,
			"Q": 26, "R": 27, "S": 28, "T": 29, "U": 30, "V": 31, "W": 32, "X": 33,
			"Y": 34, "Z": 35, 
			"DOT": 36, "LT": 37, "GT": 38, "DASH": 39,
			"@":40,  //gold
			"#":41,  //trap
			"FLASH": { //42 & 43 
				frames: [42, 42, 43, 43],
				next: "FLASH",
				speed: FLASH_SPEED
			},
			"SPACE":43, "COLON":44, "UNDERLINE": 45, 
			"D0": 50, "D1": 51, "D2": 52, "D3": 53, "D4": 54,  //blue digit number for player name, 11/17/2014
 			"D5": 55, "D6": 56, "D7": 57, "D8": 58, "D9": 59
		}
	});

	//owned glyph atlas over the same recolored image (rebuilt with textData on
	//theme/color change); used by CanvasGlyph text on the owned score screen
	textAtlas = makeGlyphAtlas(getThemeBitmap("text").image, BASE_TILE_X, BASE_TILE_Y);
}

function createGuardObj(imageName)
{
	var guard = makeSpriteSheet(
	{
		images: [getThemeBitmap(imageName).image],
		
		frames: {regX:0, height: BASE_TILE_Y,  regY: 0, width: BASE_TILE_X},
		
		animations: { 
			runRight: [0,2,  "runRight", GUARD_SPEED], 
			runLeft : [3,5,  "runLeft",  GUARD_SPEED],
			runUpDn : [6,7,  "runUpDn",  GUARD_SPEED],
					 
			barRight: {
				frames: [ 22, 23, 23, 24, 24 ],
				next:  "barRight",
				speed: GUARD_SPEED
			},
				 
			barLeft: {
				frames: [ 25, 26, 26, 27, 27 ],
				next:  "barLeft",
				speed: GUARD_SPEED
			},

			reborn: {
				frames: [ 28, 28, 29 ], //if change frame idx, don't forgot change "rebornFrame"
				speed: GUARD_SPEED
			},

			fallRight : 8,
			fallLeft: 30,

			shakeRight: {
				frames: [ 8, 8, 8, 8, 8, 8, 8,
				          8, 8, 8, 8, 8, 8,
				          9, 10, 9, 10, 8 ],
				next: null,
				speed: GUARD_SPEED
			},

			shakeLeft: {
				frames: [ 30, 30, 30, 30, 30, 30, 30,
				          30, 30, 30, 30, 30, 30, 
				          31, 32, 31, 32, 30],
				next: null,
				speed: GUARD_SPEED
			}
		}
	});
	
	return guard;
}
	
function createHoleObj()
{
	holeObj.sprite = new GameSprite(holeData, "digHoleLeft");
	
	if(curAiVersion < 3) {
		holeObj.digLimit = 6; //for check guard is close to runner when digging
	} else {
		holeObj.digLimit = 8; //for check guard is close to runner when digging
	}
	
	holeObj.action = ACT_STOP; //no digging 
}
