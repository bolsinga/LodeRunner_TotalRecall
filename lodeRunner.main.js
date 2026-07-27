/** 
 * @license ================================================================================== 
 * Lode Runner main program
 *
 * This program is a HTML5 remake of the Lode Runner games (APPLE II & C64 version).
 *
 * The program code base on CreateJS JavaScript libraries !
 * http://www.createjs.com/
 *
 * The AI algorithm reference book:
 * http://www.kingstone.com.tw/book/book_page.asp?kmcode=2014710650538
 * http://www.amazon.co.jp/Lode-Runnerで学ぶ実践C言語-ビー・エヌ・エヌ企画部/dp/4893690116
 * 
 * Source Code: https://github.com/SimonHung/LodeRunner_TotalRecall
 * Web page: http://LodeRunnerWebGame.com
 *
 * by Simon Hung 06/20/2014, 06/13/2015, 09/28/2016
 * ==================================================================================
 */

window.name = 'lodeRunnerParent'; //for world high score switch back 5/31/2015

var screenX1, screenY1;
var canvasX, canvasY;
var screenBorder;

var tileW, tileH; //tile width & tile height
var tileWScale, tileHScale; //tile width/height with scale
var W2, W4;       //W2: 1/2 tile-width,  W4: 1/4 tile width
var H2, H4;       //H2: 1/2 tile-height, H4: 1/4 tile height

var mainStageX, mainStageY;
var scroeStageX, scoreStageY;

var canvas;
var mainStage, scoreStage;
var loadingTxt;

var gameState, lastGameState;
var tileScale, xMove, yMove;

var speedMode = [14, 18, 23, 29, 35]; //slow   normal  fast , slow down all speed 6/2/2016

var speedText = ["VERY SLOW", "SLOW", "NORMAL", "FAST", "VERY FAST"];
var speed = 2; //normal 
var demoSpeed = 35;

var levelData = defaultLevelData(); //Classic Lode Runner

var curLevel = 1, maxLevel = 1, passedLevel = 0;
var playMode = PLAY_CLASSIC;
var playData = 1; //classic lode runner
var curTime = 0; //count from 0 to MAX_TIME_COUNT

var backgroundColor = "#000000"; //page background behind the board

var playerName = "";

var curTheme = THEME_APPLE2; //support 2 themes: apple2 & C64

var dbName = "LodeRunner";

function init()
{
	initAccent();         //saved accent applies before any chrome paints
	settingsPanel.init(); //settings menu is a page peer, built before the game boots

	var screenSize = getScreenSize();
	screenX1 = screenSize.x;
	screenY1 = screenSize.y;

	canvasReSize();
	createStage();
	initGameInput();   // the canvas owns the game's keyboard input
	initAudioUnlock(); // unlock audio on the first gesture, wherever it lands
	setBackground();
	initAutoDemoRnd(); //init auto demo random levels
	
	loadStoreVariable(); //load data from localStorage
	initMenuVariable();  //init menu variable
	
	getLastPlayInfo();
	// Load last-played version packs (classic is already in HTML) before preload/demo.
	ensurePlayVersionLoaded(playData, function () {
		initDemoData();
		getEditLevelInfo(); //load edit levels
		showLoadingPage(); //preload function
	});
}

function loadStoreVariable()
{
	playerName = getPlayerName();
	curTheme = getThemeMode();
	getThemeColor();
	getRepeatAction();
	if(getGamepadMode()) gamepadEnable();
}

function canvasReSize() 
{
	// Closed-form fit: the board may occupy the window less its four margins.
	// Whichever axis runs out first sets the scale and lands on its minimum
	// exactly; the other follows from the fixed 28x16 aspect and its leftover
	// space is wasted to the right and bottom.
	//
	// Tiles are PLACED at x * tileWScale but DRAWN at scaleX = tileScale, so the
	// two have to agree to the pixel or adjacent bricks show seams. An arbitrary
	// scale (0.9766 -> 42.96875px tiles) accumulates rounding error down the
	// grid; the original stepped by 0.05 for exactly this reason. Keep a step,
	// but fit closed-form and snap down to it rather than looping.
	var availX = screenX1 - BOARD_MARGIN_LEFT - BOARD_MARGIN_RIGHT;
	var availY = screenY1 - BOARD_MARGIN_TOP - BOARD_MARGIN_BOTTOM;
	var STEP = 0.05;

	tileScale = Math.min(availX / BASE_SCREEN_X, availY / BASE_SCREEN_Y);
	tileScale = Math.round(Math.floor(tileScale / STEP) * STEP * 100) / 100;

	if(tileScale > MAX_SCALE) tileScale = MAX_SCALE;
	if(tileScale < MIN_SCALE) tileScale = MIN_SCALE;

	canvasX = BASE_SCREEN_X * tileScale;
	canvasY = BASE_SCREEN_Y * tileScale;
	var iconSizeX = BASE_ICON_X * 2 * tileScale;
	debug("SCALE=" + tileScale);

	screenBorder = (screenX1 - (canvasX+iconSizeX))/2;
	if(screenBorder > ICON_BORDER*2) screenBorder = ICON_BORDER*2; 
	else if (screenBorder < 0) screenBorder = 0;
	screenBorder = (screenBorder * tileScale) | 0;
	
	canvas = document.getElementById('canvas');

	canvas.width = canvasX;
	canvas.height = canvasY;
	
	// Centre leftover space, but never sit closer than the fit margins on
	// left/top (so the chrome band stays clear and the right/bottom mins from
	// the scale math still hold when an axis is tight).
	canvas.style.left = Math.max(BOARD_MARGIN_LEFT, (screenX1 - canvasX) / 2 | 0) + "px";
	canvas.style.top  = Math.max(BOARD_MARGIN_TOP,  (screenY1 - canvasY) / 2 | 0) + "px";
	canvas.style.position = "absolute";
	canvas.style.cursor = "default";
	
	tileW = BASE_TILE_X; //tileW and tileH for detection so don't change scale
	tileH = BASE_TILE_Y;
	tileWScale = BASE_TILE_X * tileScale;
	tileHScale = BASE_TILE_Y * tileScale;
	
	W2 = (tileW/2|0); //20, 15, 10,
	H2 = (tileH/2|0); //22, 16, 11 
	
	W4 = (tileW/4|0); //10, 7, 5,
	H4 = (tileH/4|0); //11, 8, 5,
	
}

function createStage() 
{
	mainStage = new createjs.Stage(canvas);

	loadingTxt = new createjs.Text(" ", "36px Arial", "#FF0000");
	loadingTxt.x = (canvas.width - loadingTxt.getBounds().width) / 2 | 0;
	loadingTxt.y = (canvas.height - loadingTxt.getBounds().height) / 2 | 0;
	mainStage.addChild(loadingTxt);
	stagePresent();
}

//==========================================================================
// single frame-present seam: stage repaint + owned overlay pass.
// All repaints go through here so owned CanvasObjects (lodeRunner.canvasObj)
// always paint on top of the stage; later the stage update inside becomes
// the owned render loop and callers do not change.
//==========================================================================
function stagePresent()
{
	mainStage.update();
	canvasOverlay.paint(canvas.getContext("2d"));
}

function setBackground()
{
	//set background color
	var background = new createjs.Shape();
	background.graphics.beginFill("#000000").drawRect(0, 0, canvas.width, canvas.height);
	mainStage.addChild(background);
	document.body.style.background = backgroundColor;
}

function showCoverPage()
{
	// Attract/cover must not clobber an active edit session
	if (playMode == PLAY_EDIT || playMode == PLAY_TEST) {
		disableAutoDemoTimer();
		clearIdleDemoTimer();
		return;
	}
	document.body.style.background = backgroundColor;
	menuIconDisable(1);
	clearIdleDemoTimer();
	mainStage.removeAllChildren();
	canvasOverlay.clear(); //owned overlay follows the world teardown
	mainStage.addChild(titleBackground); //colorful background
	mainStage.addChild(coverBitmap);
	mainStage.addChild(signetBitmap);
	mainStage.addChild(remakeBitmap);
	stagePresent();
	waitIdleDemo(3000);
}

// Attract beat after a demo level: Classic scores (4s), then either the next
// demo or the title. Death always returns to the title after scores.
function attractAfterDemo(backToTitle)
{
	showScoreTable(1, null, function() {
		if(backToTitle) showCoverPage();
		else gameState = GAME_NEW_LEVEL;
	}, 4000, true);
}

function attractDemoEnd()
{
	attractAfterDemo(true);
}

var idleTimer=null, startIdleTime;

function clearIdleDemoTimer()
{
	if(idleTimer) clearInterval(idleTimer);
	idleTimer = null;
}

function waitIdleDemo(maxIdleTime)
{
	startIdleTime = new Date();
	idleTimer = setInterval(function(){ checkIdleTime(maxIdleTime);}, 200);
	anyKeyStopDemo();
}

function anyKeyStopDemo()
{
	setKeyHandler(anyKeyDown); // any key press
	enableStageClickEvent();
}

function stopDemoAndPlay()
{
	var showStartMsg = 1;
	if(changingLevel) return false;
	clearIdleDemoTimer();
	disableStageClickEvent();

	soundStop(soundFall);
	stopAllSpriteObj();

	if(playMode == PLAY_DEMO_ONCE) showStartMsg = 0;
	////genUserLevel(MAX_EDIT_LEVEL); //for debug only
	////getEditLevelInfo(); //load edit levels
	selectGame(showStartMsg);
}

var stageClickListenerEnabled = false;

function stageClickHandler(evt) { stopDemoAndPlay(); }

function enableStageClickEvent()
{
	disableStageClickEvent();

	//createjs.Touch.enable(mainStage);
	mainStage.addEventListener("click", stageClickHandler);
	stageClickListenerEnabled = true;
}

function disableStageClickEvent()
{
	var rc = 0;

	if(stageClickListenerEnabled) { rc = 1; mainStage.removeEventListener("click", stageClickHandler); }
	stageClickListenerEnabled = false;
	//createjs.Touch.disable(mainStage);

	return rc;
}

//=============================================================================
// Keyboard input lives on the canvas, not on document -- the game does not
// listen outside its own surface. A modal <dialog> makes everything outside it
// inert, so an open menu silences the game without anything having to block keys.
//
// setKeyHandler routes between the game's handlers as its state changes (play,
// editor, attract mode, text entry). null means no handler for this state.
//=============================================================================
var gameKeyDownHandler = null, gameKeyUpHandler = null;

function setKeyHandler(keyDown, keyUp)
{
	gameKeyDownHandler = keyDown || null;
	if(arguments.length > 1) gameKeyUpHandler = keyUp || null;
}

function getKeyHandler()
{
	return gameKeyDownHandler;
}

// Synthetic keys (the gamepad maps buttons to key codes) use the same channel
// as real ones, so they follow the same routing.
function sendGameKeyDown(event)
{
	if(gameKeyDownHandler) gameKeyDownHandler(event);
}

function sendGameKeyUp(event)
{
	if(gameKeyUpHandler) gameKeyUpHandler(event);
}

// Focus the canvas so it receives keys -- at start, and whenever a dialog hands
// control back.
function focusGame()
{
	if(canvas) canvas.focus();
}

function initGameInput()
{
	// The handlers return false to mean "consumed" (so arrows only scroll the
	// page when the game did not want them). addEventListener ignores return
	// values, so honor that contract here.
	canvas.addEventListener("keydown", function(event) {
		if(gameKeyDownHandler && gameKeyDownHandler(event) === false) event.preventDefault();
	});
	canvas.addEventListener("keyup", function(event) {
		if(gameKeyUpHandler && gameKeyUpHandler(event) === false) event.preventDefault();
	});
	canvas.addEventListener("mousedown", focusGame); // clicking the board refocuses it
	focusGame();
}

function anyKeyDown()
{
	stopDemoAndPlay();
}

function checkIdleTime(maxIdleTime)
{
	// Never kick into attract while editing or playtesting a custom level
	if (playMode == PLAY_EDIT || playMode == PLAY_TEST) {
		clearIdleDemoTimer();
		return;
	}

	var idleTime = (new Date() - startIdleTime);
		
	if(idleTime > maxIdleTime){ //start demo
		clearIdleDemoTimer();
		playMode = PLAY_AUTO;
		anyKeyStopDemo(); 
		startGame();
	}
}

//==========================
// Get playMode & playData
//==========================
function getLastPlayInfo()
{
	var infoJSON = getStorage(STORAGE_LASTPLAY_MODE);
	playMode = PLAY_NONE;

	if(infoJSON) {
		var infoObj = JSON.parse(infoJSON);
		playMode = infoObj.m; //mode= 1: classic, 2:time 
		playData = infoObj.d; //1: classic lode runner, 2: professional lode runner, 3: lode runner 3 ....
	}
	
	if( (playMode != PLAY_CLASSIC && playMode != PLAY_MODERN) || 
	    (playData < 1 || (playData > maxPlayId && playData != PLAY_DATA_USERDEF) )
	){
		playMode = PLAY_CLASSIC;
		playData = 1; //classic lode runner
	}
}

function selectGame(showDataMsg)
{
	getLastPlayInfo();
	setKeyHandler(handleKeyDown, handleKeyUp);
	initShowDataMsg(showDataMsg);
	startGame();	
}

var gameTicker = null;
var changingLevel = 0; 
function startPlayTicker()
{
	stopPlayTicker();
	//createjs.Ticker.timingMode = createjs.Ticker.RAF;
	if(playMode == PLAY_AUTO || playMode == PLAY_DEMO || playMode == PLAY_DEMO_ONCE) {
		createjs.Ticker.setFPS(demoSpeed); //06/12/2014
	} else {
		createjs.Ticker.setFPS(speedMode[speed]);
	}
	createjs.Ticker.addEventListener("tick", mainTick);
	gameTicker = mainTick;
}

function stopPlayTicker()
{
	if(gameTicker) {
		createjs.Ticker.removeEventListener("tick", gameTicker);
		gameTicker = null;
	}
}

function startGame(noCycle)
{
	var levelMap;
	gameState = GAME_WAITING;
	startPlayTicker();
	changingLevel = 1;
	
	curAiVersion = AI_VERSION; //07/04/2014
	initHotKeyVariable();      //07/09/2014
	
	switch(playMode) {
	case PLAY_CLASSIC:
		getClassicInfo();
		ensureDemoDataSynced();
		levelMap = levelData[curLevel-1];	
		if(curLevel >= levelData.length && (passedLevel+1) >= levelData.length) {
			loadEndingMusic(); //6/15/2015, music prepare for winner
		}
		break;
	case PLAY_MODERN:
		getModernInfo();
		ensureDemoDataSynced();
		levelMap = levelData[curLevel-1];
		break;	
	case PLAY_TEST:
		levelMap = getTestLevelMap();
		break;
	case PLAY_DEMO:
		getDemoInfo();	
		levelMap = levelData[curLevel-1];
		break;	
	case PLAY_DEMO_ONCE:
		ensureDemoDataSynced();
		getDemoOnceInfo();	
		levelMap = levelData[curLevel-1];
		break;	
	case PLAY_AUTO:
		getAutoDemoLevel(1);
		levelMap = levelData[curLevel-1];	
		break;
	}
	showLevel(levelMap);
	if(noCycle) {
		beginPlay();
	} else {
		addCycScreen();
		setTimeout(function() { openingScreen(cycDiff*2);}, 5);
	}
}

var maxTileX = NO_OF_TILES_X - 1, maxTileY = NO_OF_TILES_Y - 1;

var runner = null,  guard= [];
var map; //[x][y] = { base: base map, act : active map, state:, bitmap: }
var guardCount, goldCount, goldComplete;

function initVariable()
{
	guard = [];
	keyAction = holeObj.action = ACT_STOP; 
	goldCount = guardCount = goldComplete = 0;
	runner = null;
	dspTrapTile = 0;
	
	initRnd(); 
	initModernVariable();
	initGuardVariable();
	initInfoVariable();
	initCycVariable();
	
	initStillFrameVariable(); //05/01/2015 replace sprite with still frame image 
	setSpeedByAiVersion(); //07/04/2014
	
	debug("curAiVersion = " + curAiVersion);
}

function buildLevelMap(levelMap) 
{
	// Resolve base/act (incl. maxGuard culling + first-&-wins) in pure helper;
	// this function only attaches CreateJS bitmaps/sprites.
	var resolved = resolveLevelMap(levelMap, maxGuard);
	var index = 0;

	map = [];
	for(var x = 0; x < NO_OF_TILES_X; x++) {
		map[x] = [];
		for(var y = 0; y < NO_OF_TILES_Y; y++) {
			map[x][y] = {
				base: resolved.map[x][y].base,
				act: resolved.map[x][y].act,
				bitmap: null
			};
		}
	}

	for(var y = 0; y < NO_OF_TILES_Y; y++) {
		for(var x = 0; x < NO_OF_TILES_X; x++) {
			var id = levelMap.charAt(index++);
			var curTile;
			var cell = resolved.map[x][y];

			switch(id) {
			default:		
			case ' ': //empty
				continue;
			case '#': //Normal Brick
				curTile = map[x][y].bitmap = getThemeBitmap("brick");
				break;	
			case '@': //Solid Brick
				curTile = map[x][y].bitmap = getThemeBitmap("solid");
				break;	
			case 'H': //Ladder
				curTile = map[x][y].bitmap = getThemeBitmap("ladder");
				break;	
			case '-': //Line of rope
				curTile = map[x][y].bitmap = getThemeBitmap("rope");
				break;	
			case 'X': //False brick
				curTile = map[x][y].bitmap = getThemeBitmap("brick");
				break;
			case 'S': //Ladder appears at end of level
				curTile = map[x][y].bitmap = getThemeBitmap("ladder");
				curTile.set({alpha:0});	//hide the laddr
				break;
			case '$': //Gold chest
				curTile = map[x][y].bitmap = getThemeBitmap("gold");
				goldCount++;	
				break;	
			case '0': //Guard - spawn only if resolveLevelMap kept GUARD_T
				if(cell.act != GUARD_T) {
					continue;  // culled by maxGuard
				}

				curTile = new createjs.Sprite(guardData, "runLeft");
				guard[guardCount] = { 
					sprite: curTile,
					pos: { x:x, y:y, xOffset:0, yOffset:0}, 
					action: ACT_STOP,
					shape: "runLeft",
					lastLeftRight: "ACT_LEFT",
					hasGold: 0
				};					
				guardCount++;	
				curTile.stop();	
				break;	
			case '&': //Player - spawn only if resolveLevelMap kept RUNNER_T
				if(cell.act != RUNNER_T) {
					continue;  // demoted (extra runner)
				}
				runner = {};	
				curTile = runner.sprite = new createjs.Sprite(runnerData, "runRight");
				runner.pos = { x:x, y:y, xOffset:0, yOffset:0};	
				runner.action = ACT_UNKNOWN;	
				runner.shape = "runRight";	
				runner.lastLeftRight = "ACT_RIGHT";
				curTile.stop();	
				break;	
			}
			curTile.setTransform(x * tileWScale, y * tileHScale, tileScale, tileScale); //x,y, scaleX, scaleY 
			mainStage.addChild(curTile); 
		}
	}
	moveSprite2Top();
}

function moveSprite2Top()
{
	//move guard to top (z index)
	for(var i = 0; i < guardCount; i++) {
		moveChild2Top(mainStage, guard[i].sprite); 
	}
	
	if(runner == null) {
		error("Without runner ???");
	} else {
		//move runner to top (z index)
		moveChild2Top(mainStage, runner.sprite); 
	}
	
	//move fill hole object to top
	moveFillHoleObj2Top();
	
	//move debug text to top
	moveChild2Top(mainStage, loadingTxt); //for debug

	// move on-board banners to top: rebuildMap re-adds every tile and addChild
	// appends, so a banner up during a rebuild ends up buried. Rect before text.
	// Null until the first banner, and a recolor can happen before that.
	if(tipsRect  != null) moveChild2Top(mainStage, tipsRect);
	if(tipsText  != null) moveChild2Top(mainStage, tipsText);
	if(tipsRect1 != null) moveChild2Top(mainStage, tipsRect1);
	if(tipsText1 != null) moveChild2Top(mainStage, tipsText1);
}

function buildGroundInfo()
{
	drawGround();
	drawInfo();
}

var groundTile;
function drawGround()
{
	groundTile = [];
	for(var x = 0; x < NO_OF_TILES_X; x++) {
		groundTile[x] = getThemeBitmap("ground");
		groundTile[x].setTransform(x * tileWScale, NO_OF_TILES_Y * tileHScale, tileScale, tileScale);
		mainStage.addChild(groundTile[x]); 
	}
}


var runnerLife = RUNNER_LIFE;
var curScore = 0;
var curGetGold = 0, curGuardDeadNo = 0; //for modern mode 
var sometimePlayInGodMode = 0; //if sometime play in god mode then don't save to hi-scoe, 12/23/2014

var infoY;
var scoreTxt, scoreTile,
	lifeTxt, lifeTile,
	levelTxt, levelTile,
	demoTxt;

var goldTxt, goldTile,
	guardTxt, guardTile,
	timeTxt, timeTile;

//=============================
// initial modern mode variable
//=============================
function initModernVariable()
{
	//curTime = MAX_TIME_COUNT;
	curTime = curGetGold = curGuardDeadNo = 0;
}

function initInfoVariable()
{
	infoY =  (NO_OF_TILES_Y * BASE_TILE_Y + GROUND_TILE_Y) * tileScale;
	
	scoreTxt = []; 
	scoreTile = [];
	
	lifeTxt = []; 
	lifeTile = [];
	
	demoTxt = [];

	levelTxt = []; 
	levelTile = [];
	
	goldTxt = [];
	goldTile = [];
	
	guardTxt = [];
	guardTile = [];

	timeTxt = []; 
	timeTile = [];
}

function drawInfo()
{
	if(playMode == PLAY_CLASSIC || playMode == PLAY_AUTO || playMode == PLAY_DEMO) {
		//SCORE
		drawScoreTxt();
		drawScore(0);

		if(playMode == PLAY_DEMO) {
			drawDemoTxt();
		} else {
			//MEN
			drawLifeTxt();
			drawLife();
		}
	} else {
		//GOLD 
		drawGoldTxt();
		drawGold(0);
		
		//GUARD
		drawGuardTxt();
		drawGuard(0);
		
		//TIME 
		drawTimeTxt();
		drawTime(0);
	}
	
	//LEVEL
	drawLevelTxt();
	drawLevel();
}

//for classic & auto demo mode
function drawScoreTxt()
{
	scoreTxt = drawText(0, infoY, "SCORE", mainStage);
}

function drawLifeTxt()
{
	lifeTxt = drawText(13*tileWScale, infoY, "MEN", mainStage);
}

function drawLevelTxt()
{
	var xOffset = 20;
	
	levelTxt = drawText(xOffset*tileWScale, infoY, "LEVEL", mainStage);
}

//for demo mode
function drawDemoTxt()
{
	demoTxt = drawText(14*tileWScale, infoY, "DEMO", mainStage);
}

//for time & edit mode
function drawGoldTxt()
{
	goldTxt = drawText(0*tileWScale, infoY, "@", mainStage);
}

function drawGuardTxt()
{
	guardTxt = drawText((5+2/3)*tileWScale, infoY, "#", mainStage);
}

function drawTimeTxt()
{
	timeTxt = drawText((11+1/3)*tileWScale, infoY, "TIME", mainStage);
}

// draw score number 
function drawScore(addScore)
{
	var digitNo;
	
	curScore += addScore;
	for(var i = 0; i < scoreTile.length; i++) 
		mainStage.removeChild(scoreTile[i]);
	
	scoreTile = drawText(5*tileWScale, infoY, ("000000"+curScore).slice(-7), mainStage);
}

function drawLife()
{
	for(var i = 0; i < lifeTile.length; i++) 
		mainStage.removeChild(lifeTile[i]);

	lifeTile = drawText(16*tileWScale, infoY, ("00"+runnerLife).slice(-3), mainStage);
}

function drawLevel()
{
	for(var i = 0; i < levelTile.length; i++) 
		mainStage.removeChild(levelTile[i]);
	
	switch(playMode) {
	case PLAY_AUTO:	
		levelTile = drawText(25*tileWScale, infoY, ("00"+demoLevel).slice(-3), mainStage);
		break;	
	case PLAY_CLASSIC: 
	default:		
		levelTile = drawText(25*tileWScale, infoY, ("00"+curLevel).slice(-3), mainStage);
		break;	
	}
}

function drawGold(addGold)
{
	curGetGold += addGold;
	for(var i = 0; i < goldTile.length; i++) 
		mainStage.removeChild(goldTile[i]);
	
	goldTile = drawText(1*tileWScale, infoY, ("00"+curGetGold).slice(-3), mainStage);
}

function drawGuard(addGuard)
{
	curGuardDeadNo += addGuard;
	if(curGuardDeadNo > 100) curGuardDeadNo = 100;
	for(var i = 0; i < guardTile.length; i++) 
		mainStage.removeChild(guardTile[i]);
	
	guardTile = drawText((6+2/3)*tileWScale, infoY, ("00"+curGuardDeadNo).slice(-3), mainStage);
}


function countTime(addTime)
{
	if(curTime >= MAX_TIME_COUNT) return;
	if(addTime) curTime++;
	if(curTime > MAX_TIME_COUNT) { curTime = MAX_TIME_COUNT;}
}

function drawTime(addTime)
{
	countTime(addTime);
	for(var i = 0; i < timeTile.length; i++) 
		mainStage.removeChild(timeTile[i]);

	timeTile = drawText((15+1/3)*tileWScale, infoY, ("00"+curTime).slice(-3), mainStage);
}

function setGroundInfoOrder()
{
	var i;

	for(i = 0; i < groundTile.length; i++) moveChild2Top(mainStage, groundTile[i]);
	
	if(playMode == PLAY_CLASSIC || playMode == PLAY_AUTO || playMode == PLAY_DEMO) {
		for(i = 0; i < scoreTxt.length; i++) moveChild2Top(mainStage, scoreTxt[i]);
		for(i = 0; i < scoreTile.length; i++) moveChild2Top(mainStage, scoreTile[i]);

		if(playMode == PLAY_DEMO) {
			for(i = 0; i < demoTxt.length; i++) moveChild2Top(mainStage, demoTxt[i]);
		} else {
			for(i = 0; i < lifeTxt.length; i++) moveChild2Top(mainStage, lifeTxt[i]);
			for(i = 0; i < lifeTile.length; i++) moveChild2Top(mainStage, lifeTile[i]);
		}
	} else { //PLAY_MODERN, PLAY_DEMO_ONCE
		for(i = 0; i < goldTxt.length; i++) moveChild2Top(mainStage, goldTxt[i]);
		for(i = 0; i < goldTile.length; i++) moveChild2Top(mainStage, goldTile[i]);

		for(i = 0; i < guardTxt.length; i++) moveChild2Top(mainStage, guardTxt[i]);
		for(i = 0; i < guardTile.length; i++) moveChild2Top(mainStage, guardTile[i]);

		for(i = 0; i < timeTxt.length; i++) moveChild2Top(mainStage, timeTxt[i]);
		for(i = 0; i < timeTile.length; i++) moveChild2Top(mainStage, timeTile[i]);
	}
	
	for(i = 0; i < levelTxt.length; i++) moveChild2Top(mainStage, levelTxt[i]);
	for(i = 0; i < levelTile.length; i++) moveChild2Top(mainStage, levelTile[i]);
}

function drawText(x, y, str, parentObj, numberType)
{
	var text = str.toUpperCase();
	var textTile = [];
	
	if(typeof numberType == "undefined") numberType = "N";
	
	for(var i = 0; i < text.length; i++) {
		var code = text.charCodeAt(i);
		
		switch(true) {
		case (code >=48 && code <=57): //N0 ~ N9 or D0 ~ D9 
			textTile[i] = new createjs.Sprite(textData, numberType+String.fromCharCode(code));	
			break;
		case (code >=65 && code <= 90):
			textTile[i] = new createjs.Sprite(textData, String.fromCharCode(code));	
			break;
		case (code == 46): //'.'
			textTile[i] = new createjs.Sprite(textData, "DOT");	
			break;
		case (code == 60): //'<'
			textTile[i] = new createjs.Sprite(textData, "LT");	
			break;
		case (code == 62): //'>'
			textTile[i] = new createjs.Sprite(textData, "GT");	
			break;
		case (code == 45): //'-'
			textTile[i] = new createjs.Sprite(textData, "DASH");	
			break;
		case (code == 58): //':'
			textTile[i] = new createjs.Sprite(textData, "COLON");	
			break;
		case (code == 95): //'_'
			textTile[i] = new createjs.Sprite(textData, "UNDERLINE");	
			break;
		case (code == 35): //'#': guard dead in trap hole
			textTile[i] = new createjs.Sprite(textData, String.fromCharCode(code));	
			break;
		case (code == 64): //'@': gold
			textTile[i] = new createjs.Sprite(textData, String.fromCharCode(code));	
			break;
		default: //space
			textTile[i] = new createjs.Sprite(textData, "SPACE");	
			break;
		}
		textTile[i].setTransform(x + i*tileWScale, y, tileScale, tileScale).stop();
		parentObj.addChild(textTile[i]); 
	}
	return textTile;	
}

var playTickTimer = 0;
function playGame(deltaS)
{
	if(goldComplete && runner.pos.y == 0 && runner.pos.yOffset == 0) {
		gameState = GAME_FINISH;
		return;
	}
	
	if(++playTickTimer >= TICK_COUNT_PER_TIME) {
		if(playMode != PLAY_CLASSIC && playMode != PLAY_AUTO && playMode != PLAY_DEMO) drawTime(1);
		else countTime(1);
		playTickTimer = 0;
	}
	
	if(playMode == PLAY_AUTO || playMode == PLAY_DEMO || playMode == PLAY_DEMO_ONCE) {
		playDemo();
	} else if(recordMode == RECORD_PLAY) {
		processRecordKey();
	} else { //stop-on-release must run even when not recording
		processInputKeyState();
		if(recordMode == RECORD_KEY) recordCount++;
	}
	if(!isDigging()) moveRunner();
	else processDigHole();
	if(gameState != GAME_RUNNER_DEAD) moveGuard();
	
	if(curAiVersion >= 3) {
		processGuardShake();
		processFillHole();
		processReborn();
	}
}

//***********************
// BEGIN show new level *
//***********************
function showLevel(levelMap)
{
	mainStage.removeAllChildren();
	canvasOverlay.clear(); //owned overlay follows the world teardown

	loadingTxt.text = "";
	//loadingTxt.text = tileScale;  //for debug
	mainStage.addChild(loadingTxt); //for debug

	initVariable();	
	setBackground();
	
	buildLevelMap(levelMap);
	
	buildGroundInfo();
}

var tipsText = null, tipsRect = null;
var tipsText1 = null, tipsRect1 = null;
function showTipsText(text, time, text1)
{
	var x, y, width, height;
	
	if(tipsText != null) {
		mainStage.removeChild(tipsText);
	}
	if(tipsRect != null) {
		mainStage.removeChild(tipsRect);
	}	

	if(tipsText1 != null) {
		mainStage.removeChild(tipsText1);
		tipsText1 = null;
	}
	
	if(tipsRect1 != null) {
		mainStage.removeChild(tipsRect1);
		tipsRect1 = null;
	}	
	
	tipsText = new createjs.Text("test", "bold " +  (48*tileScale) + "px Helvetica", "#ee1122");
	tipsText.text = text;
	tipsText.set({alpha:1});
	if(text.length) {
		width = tipsText.getBounds().width;
		height = tipsText.getBounds().height;
	} else {
		width = height = 0;
	}
	x = tipsText.x = (canvas.width - width) / 2 | 0;
	y = tipsText.y = (NO_OF_TILES_Y*tileHScale - height) / 2 | 0;
	tipsText.shadow = new createjs.Shadow("white", 2, 2, 1);
	
	tipsRect = new createjs.Shape();
    tipsRect.graphics.beginFill("#020722");
    tipsRect.graphics.drawRect(-1, -1,width+2, height+2);	
	tipsRect.setTransform(x, y).set({alpha:0.8});

	mainStage.addChild(tipsRect);
	mainStage.addChild(tipsText);
	
	if(time){
		tweenGet(tipsRect,{override:true}).set({alpha:0.8}).to({alpha:0}, time);
		tweenGet(tipsText,{override:true}).set({alpha:1}).to({alpha:0}, time);
	}
	
	if(text1 != null) { //second tips 
		tipsText1 = new createjs.Text("test", "bold " +  (48*tileScale) + "px Helvetica", "#ee1122");
		tipsText1.text = text1;
		tipsText1.set({alpha:1});
		if(text1.length) {
			width = tipsText1.getBounds().width;
			height = tipsText1.getBounds().height;
		} else {
			width = height = 0;
		}
		x = tipsText1.x = (canvas.width - width) / 2 | 0;
		y = tipsText1.y = (NO_OF_TILES_Y*tileHScale - height) / 2  + tipsText.getBounds().height*2 | 0;
		tipsText1.shadow = new createjs.Shadow("white", 2, 2, 1);
	
		tipsRect1 = new createjs.Shape();
    	tipsRect1.graphics.beginFill("#020722");
    	tipsRect1.graphics.drawRect(-1, -1,width+2, height+2);	
		tipsRect1.setTransform(x, y).set({alpha:0.8});

		mainStage.addChild(tipsRect1);
		mainStage.addChild(tipsText1);
	
		if(time){
			tweenGet(tipsRect1,{override:true}).set({alpha:0.8}).to({alpha:0}, time);
			tweenGet(tipsText1,{override:true}).set({alpha:1}).to({alpha:0}, time);
		}
	}

	stagePresent();
}

var dspTrapTile = 0;
function toggleTrapTile()
{
	dspTrapTile ^= 1;
	
	for(var y = 0; y < NO_OF_TILES_Y; y++) {
		for(var x = 0; x < NO_OF_TILES_X; x++) {
			if( map[x][y].base == TRAP_T) {
				if(dspTrapTile) {
					map[x][y].bitmap.set({alpha:0.5}); //show trap tile
				} else {
					map[x][y].bitmap.set({alpha:1}); //hide trap tile
				}
			}
		}
	}
	
	if(dspTrapTile) {		
		showTipsText("SHOW TRAP TILE", 2000);
	} else {
		showTipsText("HIDE TRAP TILE", 2000);
	}
	
}

function startAllSpriteObj()
{
	//(1) runner stop
	if(runner && !runner.paused) runner.sprite.play();
	
	//(2) guard stop
	for(var i = 0; i < guardCount; i++) {
		if(!guard[i].paused) guard[i].sprite.play();
	}
	
	if(curAiVersion < 3) { //for sprite only
		//(3) fill hole stop
		for(var i = 0; i < fillHoleObj.length; i++)
			fillHoleObj[i].play();
	
		//(4) hole digging
		if(holeObj.action == ACT_DIGGING) holeObj.sprite.play();
	}
}

function stopAllSpriteObj()
{
	//(1) runner stop
	if(runner) {
		runner.paused = runner.sprite.paused;
		runner.sprite.stop();
	}
	
	//(2) guard stop
	for(var i = 0; i < guardCount; i++) {
		guard[i].paused = guard[i].sprite.paused;
		guard[i].sprite.stop();
	}
	
	if(curAiVersion < 3) { //for sprite only
		//(3) fill hole stop
		for(var i = 0; i < fillHoleObj.length; i++)
			fillHoleObj[i].stop();
	
		//(4) hole digging
		if(holeObj.action == ACT_DIGGING) holeObj.sprite.stop();
	}
	
}

function gameOverAnimation()
{
	var gameOverImage = getThemeBitmap("over");
	var bound = gameOverImage.getBounds();
	var x = (NO_OF_TILES_X*tileWScale)/2|0;
	var y = (NO_OF_TILES_Y*tileHScale)/2|0;
	var regX = (bound.width)/2|0;
	var regY = (bound.height)/2|0;
	
	
	var rectBlock = new createjs.Shape();
    rectBlock.graphics.beginFill("black");
    rectBlock.graphics.drawRect(-1, -1,bound.width+2, bound.height+2);
	
	rectBlock.setTransform(x, y, tileScale, tileScale).set({regX:regX, regY:regY});
	
	gameOverImage.setTransform(x, y, tileScale, tileScale).set({regX:regX, regY:regY});
	tweenGet(gameOverImage)
			.to({scaleY:-tileScale},80)
			.to({scaleY:tileScale},80)
			.to({scaleY:-tileScale},100)
			.to({scaleY:tileScale},100)
			.to({scaleY:-tileScale},150)
			.to({scaleY:tileScale},150)
			.to({scaleY:-tileScale},300)
			.to({scaleY:tileScale},300)
			.to({scaleY:-tileScale},450)
			.to({scaleY:tileScale},450)
			.to({scaleY:-tileScale},750)
			.to({scaleY:tileScale},750)
			.wait(1500)
			.call(function(){ if(gameState == GAME_OVER_ANIMATION) gameState = GAME_OVER;});
	/* 
		BUG: 
		while in PLAY_AUTO MODE and demo dead into the gameOverAnimation() 
		At this time if player press any key or click mouse will cause 
		  gameState changed to  "GAME_START" and start play the game,  
		  and after the TWEEN function into final "call( function() { gameState = GAME_OVER;})"
		  will cause program orderless and want player record hiscore table 
		  
		BUG FIXED:  9/15/2015
		   if TWEEN complete and into call() func need check gameState MUST = "GAME_OVER_ANIMATION"
		   
		==> call(function(){ if(gameState == GAME_OVER_ANIMATION) gameState = GAME_OVER;});   
		   
	*/
	
	
	mainStage.addChild(rectBlock);
	mainStage.addChild(gameOverImage);
	//stopAllSpriteObj();
}

var cycScreen, cycMaxRadius, cycDiff, cycX, cycY

function initCycVariable()
{
	cycX = NO_OF_TILES_X * tileWScale/2;
	cycY = NO_OF_TILES_Y * tileHScale/2;
	cycMaxRadius = Math.sqrt(cycX*cycX+cycY*cycY)|0+1;
	cycDiff = (cycMaxRadius/CLOSE_SCREEN_SPEED)|0;
}

function addCycScreen()
{
	cycScreen =  new createjs.Shape();
	mainStage.addChild(cycScreen);
	
	setGroundInfoOrder();
}

function removeCycScreen()
{
	mainStage.removeChild(cycScreen);
}

function newLevel(r)
{
	changingLevel = 1;
	//menuIconDisable(0);
	addCycScreen();

	//close screen
	setTimeout(function() { closingScreen(cycMaxRadius);}, 100);
}

function closingScreen(r)
{
	removeCycScreen();
	addCycScreen();
	cycScreen.graphics.beginFill("black").arc( cycX, cycY, r, 0, 2*Math.PI, true)
	cycScreen.graphics.arc( cycX, cycY, cycMaxRadius, 0, 2*Math.PI, false);
	stagePresent();
	if(r > 0) {
		r -= cycDiff;
		if(r < cycDiff*2) r = 0;
		setTimeout(function() { closingScreen(r);}, 5);
	} else {
		var levelMap;
		
		curAiVersion = AI_VERSION; //07/04/2014
		initHotKeyVariable();      //07/09/2014
		
		if(playMode == PLAY_AUTO) {
			// Safety net: never start another attract demo past the cap
			if(demoCount >= demoMaxCount) {
				attractDemoEnd();
				return;
			}
			getAutoDemoLevel(0);
		}
		if(playMode == PLAY_DEMO || playMode == PLAY_DEMO_ONCE) getNextDemoLevel();

		if(playMode == PLAY_TEST) {
			levelMap = getTestLevelMap();
		} else {
			levelMap = levelData[curLevel-1];
		}
		showLevel(levelMap);
		addCycScreen();
		setTimeout(function() { openingScreen(cycDiff*2);}, 5);
	}
}

// Show/hide seam for the board icons (choose level, watch demo). They show
// themselves only in the modes where they apply.
function menuIconEnable()
{
	boardIcons.update();
}

function menuIconDisable(hidden)
{
	boardIcons.hide();
}


var showStartTipsMsg = 1;
function initShowDataMsg(showMsg)
{
	if(typeof showMsg == "undefined") showMsg = 1;
	showStartTipsMsg = showMsg;
}

function showDataMsg()
{
	if(showStartTipsMsg) {
		var nameTxt = null;
		var nameTxt1 = null;
		
		nameTxt = playDataToTitleName(playData);

		switch(playMode) {
		case PLAY_EDIT:
			nameTxt1 = "Edit Mode";
			break;
		case PLAY_TEST:		
			nameTxt1 = "Test Mode";	
			break;	
		case PLAY_DEMO:
			nameTxt1 = "Demo Mode";
			break;	
		case PLAY_CLASSIC:
			if(playData != PLAY_DATA_USERDEF) nameTxt1 = "Challenge Mode";
			else nameTxt1 = "Play Mode";	
			break;
		case PLAY_MODERN:
			if(playData != PLAY_DATA_USERDEF) nameTxt1 = "Training Mode";
			else nameTxt1 = "Play Mode";	
			break;	
		}
		
		if(nameTxt)	showTipsMsg(nameTxt, mainStage, tileScale, nameTxt1);
		showStartTipsMsg = 0;
	}
}

// First run only: help sits between naming yourself and your first level, so a
// new player meets the keys once. setFirstPlayInfo runs on close rather than on
// open -- closing the tab mid-help should not burn the one showing.
function showHelpMenu()
{
	if(firstPlay) {
		helpDialog.open({ onClose: function() { setFirstPlayInfo(); initForPlay(); } });
	} else {
		initForPlay();
	}
}

function initForPlay()
{
	menuIconEnable();
	showDataMsg();
}

function openingScreen(r)
{
	removeCycScreen();
	addCycScreen();
	cycScreen.graphics.beginFill("black").arc( cycX, cycY, r, 0, 2*Math.PI, true)
	cycScreen.graphics.arc( cycX, cycY, cycMaxRadius, 0, 2*Math.PI, false);
	stagePresent();
	if(r < cycMaxRadius) {
		r += cycDiff;
		if(r > cycMaxRadius) r = cycMaxRadius;
		setTimeout(function() { openingScreen(r);}, 5);
	} else {
		removeCycScreen();
		beginPlay();
	}
}

var startBlinkTimer = 0;

function beginPlay()
{
	gameState = GAME_START;
	keyAction = ACT_STOP;
	// Stay frozen (and blink in mainTick) until first move - original Lode Runner behavior.
	// Previously gotoAndPlay() made the runner run in place during GAME_START.
	runner.sprite.stop();
	runner.sprite.visible = true;
	startBlinkTimer = 0;
	changingLevel = 0;
		
	initInputKeyState();
	if(recordMode) initRecordVariable();
	if(playMode == PLAY_AUTO || playMode == PLAY_DEMO || playMode == PLAY_DEMO_ONCE) {
		initPlayDemo();
		if(playMode == PLAY_DEMO || playMode == PLAY_DEMO_ONCE) initForPlay();
	} else { 

		if(playerName == "" || playerName.length <= 1) {
			inputPlayerName(mainStage, showHelpMenu);
		} else {
			showHelpMenu();
		}
			
		
		if(playMode != PLAY_TEST && playMode != PLAY_EDIT) {
			enableAutoDemoTimer(); //while start game and idle too long will into demo mode
		}
	}
}

function incLevel(incValue, passed)
{
	var wrap = 0;
	curLevel += incValue;
	while (curLevel > levelData.length) { curLevel-= levelData.length; wrap = 1; }
	if(playMode == PLAY_CLASSIC) setClassicInfo(passed);
	if(playMode == PLAY_MODERN) setModernInfo();
	
	return wrap;
}

function decLevel(decValue)
{
	curLevel -= decValue
	while (curLevel <= 0) curLevel += levelData.length;
	if(playMode == PLAY_CLASSIC) setClassicInfo(0);
	if(playMode == PLAY_MODERN) setModernInfo();
}


function updateModernScoreInfo()
{
	var lastHiScore = modernScoreInfo[curLevel-1];
	var levelScore = ((MAX_TIME_COUNT - curTime) + curGetGold + curGuardDeadNo) * SCORE_VALUE_PER_POINT;
	
	if(lastHiScore < levelScore) {
		modernScoreInfo[curLevel-1] = levelScore;
		setModernScoreInfo();
	}
	
	if(lastHiScore < 0) lastHiScore = 0;
	
	return lastHiScore;
}

function gameFinishActiveNew(level)
{
	curLevel = level;
	setModernInfo();
	startGame();
}

function gameFinishCloseIcon()
{
	startGame();
}

function gameFinishCallback(selectMode)
{
	switch(selectMode) {
	case 0: //return (same level)
		gameState = GAME_NEW_LEVEL;
		break;
	case 1: //menu selection
		// onClose fires on every close path, a pick included, so only resume the
		// old level when the dialog was dismissed without choosing one.
		var picked = 0;
		levelSelect.open({
			current: curLevel,
			onPick: function(level) { picked = 1; gameFinishActiveNew(level); },
			onClose: function() { if(!picked) gameFinishCloseIcon(); }
		});
		break;
	case 2: //new level
		incLevel(1,0);	
		gameState = GAME_NEW_LEVEL;
		break;
	default:
		debug("design error !");	
		break;	
	}
}

function gameFinishTestModeCallback()
{
	back2EditMode(1);
}

var lastScoreTime, scoreDuration;
var scoreIncValue, finalScore;

function mainTick(event)
{ 
	var deltaS = event.delta/1000; 
	var scoreInfo;
	
	switch(gameState) {
	case GAME_START:
		countAutoDemoTimer();
		// Flash runner while waiting for first key/move (classic behavior)
		if(++startBlinkTimer >= 8) {
			startBlinkTimer = 0;
			runner.sprite.visible = !runner.sprite.visible;
		}
		if(keyAction != ACT_STOP && keyAction != ACT_UNKNOWN) {
			runner.sprite.visible = true;
			disableAutoDemoTimer();	
			gamepadClearId();	
			gameState = GAME_RUNNING;
			playTickTimer = 0; //modern mode time counter
			if(goldCount <= 0) showHideLaddr();
		}
		break;	
	case GAME_RUNNING:
		playGame(deltaS);
		break;
	case GAME_RUNNER_DEAD:
		//console.log("Time=" + curTime + ", Tick= " + playTickTimer);
		//if(recordMode) recordModeToggle(GAME_RUNNER_DEAD); //for debug only (if enable it must disable below statement)
		if(recordMode == RECORD_KEY) recordModeDump(GAME_RUNNER_DEAD);	
			
		soundStop(soundFall);
		stopAllSpriteObj();	
		themeSoundPlay("dead");
		switch(playMode) {
		case PLAY_CLASSIC:
		case PLAY_AUTO:
			--runnerLife;
			drawLife();	
			if(runnerLife <= 0) {
				gameOverAnimation();
				menuIconDisable(1);
				if(playMode == PLAY_CLASSIC) clearClassicInfo();
				gameState = GAME_OVER_ANIMATION;
			} else {
				setTimeout(function() {gameState = GAME_NEW_LEVEL; }, 500);
				gameState = GAME_WAITING;	
				if(playMode == PLAY_CLASSIC) setClassicInfo(0);
			}
			break;
		case PLAY_DEMO:	
			error("DEMO dead level=" + curLevel);
				
			setTimeout(function() {incLevel(1,0); gameState = GAME_NEW_LEVEL; }, 500);
			gameState = GAME_WAITING;	
			break;	
		case PLAY_DEMO_ONCE:
			error("DEMO dead level=" + curLevel);
				
			disableStageClickEvent();
			setKeyHandler(handleKeyDown);
			setTimeout(function() {playMode = PLAY_MODERN; startGame(); }, 500);
			gameState = GAME_WAITING;	
			break;	
		case PLAY_MODERN:		
			setTimeout(function() {gameState = GAME_NEW_LEVEL; }, 500);
			gameState = GAME_WAITING;	
			break;
		case PLAY_TEST:		
			setTimeout(function() { back2EditMode(0); }, 500);
			gameState = GAME_WAITING;	
			break;
		default:
			debug("GAME_RUNNER_DEAD: desgin error !");	
			break;	
		}
		break;	
	case GAME_OVER_ANIMATION:
		break;	
	case GAME_OVER:
		scoreInfo = null;	
		if(playMode == PLAY_CLASSIC && !sometimePlayInGodMode) {	
			scoreInfo = {s:curScore, l: passedLevel+1 };
		}	

		if(playMode == PLAY_AUTO) {
			attractDemoEnd();
		} else {
			showScoreTable(playData, scoreInfo , function() { showCoverPage();});
		}
		gameState = GAME_WAITING;	
		return;
	case GAME_FINISH: 
		stopAllSpriteObj();
		//console.log("Time=" + curTime + ", Tick= " + playTickTimer);
			
		switch(playMode) {
		case PLAY_CLASSIC:
		case PLAY_AUTO:		
		case PLAY_DEMO:		
			soundPlay(soundPass);
			finalScore = curScore + SCORE_COMPLETE_LEVEL;
			scoreDuration = ((soundPass.getDuration()) /(SCORE_COUNTER+1))| 0;
			lastScoreTime = event.time;
			scoreIncValue = SCORE_COMPLETE_LEVEL/SCORE_COUNTER|0;
			drawScore(scoreIncValue);
			gameState = GAME_FINISH_SCORE_COUNT;	
			break;
		case PLAY_DEMO_ONCE:
			soundPlay(soundEnding);
			disableStageClickEvent();
			setKeyHandler(handleKeyDown);
			setTimeout(function() {playMode = PLAY_MODERN; startGame(); }, 500);
			gameState = GAME_WAITING;
			break;
		case PLAY_MODERN:
			soundPlay(soundEnding);
			var lastHiScore = updateModernScoreInfo();
			levelPass.open({
				level: curLevel, gold: curGetGold, guardDead: curGuardDeadNo,
				time: curTime, hiScore: lastHiScore,
				onPick: gameFinishCallback
			});
			gameState = GAME_WAITING;
			break;
		case PLAY_TEST:
			soundPlay(soundEnding);
			setTimeout(function() { back2EditMode(1);},500);	
			gameState = GAME_WAITING;
			break;
		default:
			error("design error, playMode =" + playMode);
			break;	
		}

		//if(recordMode) recordModeToggle(GAME_FINISH); //for debug only (if enable it must comment below if statement)
		if(recordMode == RECORD_KEY) {
			recordModeDump(GAME_FINISH);	
			
			if( (playMode == PLAY_CLASSIC || playMode == PLAY_MODERN) && playData <= maxPlayId ) {
				updatePlayerDemoData(playData, curDemoData); //update current player demo data
			}
		}
		break;	
	case GAME_FINISH_SCORE_COUNT:		
		if(event.time > lastScoreTime+ scoreDuration) {
			lastScoreTime += scoreDuration;
			if(curScore + scoreIncValue >= finalScore) {
				curScore = finalScore;
				drawScore(0);

				// Attract: scores after every demo, title after demoMaxCount.
				// return (not break) so stagePresent below cannot wipe the board.
				if(playMode == PLAY_AUTO) {
					gameState = GAME_WAITING;
					attractAfterDemo(demoCount >= demoMaxCount);
					return;
				}

				gameState = GAME_NEW_LEVEL;
				
				switch(playMode) {
				case PLAY_TEST:		
					setTimeout(function() { back2EditMode(1);},500);	
					break;
				case PLAY_CLASSIC:
					if(++runnerLife > RUNNER_MAX_LIFE) runnerLife = RUNNER_MAX_LIFE;	
					break;	
				}

				if(recordMode != RECORD_PLAY) {
					if(incLevel(1, 1) && playMode == PLAY_CLASSIC && passedLevel >= levelData.length) 
						gameState = GAME_WIN;
				}
				
			} else {
				drawScore(scoreIncValue);
			}
		}
		break;
	case GAME_NEXT_LEVEL:
		soundStop(soundFall);		
		stopAllSpriteObj();
		incLevel(shiftLevelNum, 0);
		gameState = GAME_NEW_LEVEL; 
		return;
	case GAME_PREV_LEVEL:
		soundStop(soundFall);		
		stopAllSpriteObj();
		decLevel(shiftLevelNum);	
		gameState = GAME_NEW_LEVEL; 
		return;
	case GAME_NEW_LEVEL:
		gameState = GAME_WAITING;	
		newLevel();	
		break;
	case GAME_WIN:		
		scoreInfo = {s:curScore, l: levelData.length, w:1 }; //winner	
		menuIconDisable(1);
		clearClassicInfo();
		showScoreTable(playData, scoreInfo , function() { showCoverPage();});	
		gameState = GAME_WAITING;	
		return;			
	case GAME_LOADING:
		break;	
	case GAME_PAUSE:
	default:
		return;	
	}

	stagePresent();
}