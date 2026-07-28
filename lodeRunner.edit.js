var emptyTile, actTile;
var cursorTileObj;
var editMap;
	
var MAX_EDIT_GUARD = 5;     //maximum number of guards
var EMPTY_ID = 0, GUARD_ID = 8, RUNNER_ID = 9;
var EDIT_PADDING = 1;

//value | Character | Type
//------+-----------+-----------
//  0x0 |  <space>  | Empty space
//  0x1 |     #     | Normal Brick
//  0x2 |     @     | Solid Brick
//  0x3 |     H     | Ladder
//  0x4 |     -     | Hand-to-hand bar (Line of rope)
//  0x5 |     X     | False brick
//  0x6 |     S     | Ladder appears at end of level
//  0x7 |     $     | Gold chest
//  0x8 |     0     | Guard
//  0x9 |     &     | Player

var tileIdMapping = { ' ':0, '#':1, '@':2, 'H':3, '-':4, 'X':5, 'S':6, '$':7, '0':8, '&':9 };

var tileInfo = [
	[ "eraser",   ' ' ], //(0), empty
	[ "brick",    '#' ], //(1)
	[ "solid",    '@' ], //(2)
	[ "ladder",   'H' ], //(3)
	[ "rope",     '-' ], //(4)
	[ "trapBrick",'X' ], //(5)
	[ "hladder",  'S' ], //(6)
	[ "gold",     '$' ], //(7)
	[ "guard1",   '0' ], //(8)
	[ "runner1",  '&' ]  //(9)
];

var baseTile=[];	
var lastRunner = null;
var lastGuardList = [];	
var editBorder, editStartX;
var testLevelInfo = {level: -1};

var mouseInStage = 1;
//var mouseOver = 0;	
var mouseDown = 0;
var lastDown = {x:-1, y:-1};

var testButton, newButton, saveButton, loadButton;
var editorTile =[], editorActiveTileId = -1;
var editorButton = [], editorButtonMouseOverId = -1;
var selectedTile = null;
var editInNarrowScreen = 0;

var editMapIsEmpty = 1;

function startEditMode() 
{
	playMode = PLAY_EDIT;
	playData = PLAY_DATA_USERDEF; //for title name only
	disableAutoDemoTimer();
	clearIdleDemoTimer();
	stopPlayTicker();
	worldDisplay.clear();
	canvasOverlay.clear();
	setKeyHandler(editHandleKeyDown);
	focusGame();
	
	editInNarrowScreen = canvasEditReSize();
	
	setEditSelectMenu();
	
	createBaseTile();
	createEditMap();
	checkEditMapEmpty(); // 2021/04
	startEditInput();
	setButtonState();
	initForPlay();
	installEditUnloadGuard();
	stagePresent();
}

// The editor's level picker is the shared DOM level selector (Load button).
function setEditSelectMenu()
{
}

/** Replace a CanvasShape's ops with one fillRect (local or absolute coords). */
function editShapeFill(shape, color, x, y, w, h)
{
	shape.ops.length = 0;
	shape.fillRect(color, x, y, w, h);
}

/** Sync alpha across a button's overlay pieces. */
function setEditorButtonAlpha(button, a)
{
	button.alpha = a;
	if(button.border) button.border.alpha = a;
	if(button.back) button.back.alpha = a;
	if(button.label) button.label.alpha = a;
}

function canvasEditReSize()
{
	var menuIconAreaX = screenBorder + BASE_ICON_X * tileScale; //current icon size X
	var toolAreaX = BASE_TILE_X*3/2; //edit tool size X
	var canvas = document.getElementById('canvas');
	var narrowScreen = 0;
	
	//(1) try use scale same as play mode 
	canvasX = (BASE_SCREEN_X+toolAreaX) * tileScale + EDIT_PADDING * (NO_OF_TILES_X+1);
	canvasY =  BASE_SCREEN_Y * tileScale + EDIT_PADDING * (NO_OF_TILES_Y+1);
	
	if(canvasX > (screenX1 - menuIconAreaX) || canvasY > screenY1) {
		//(2) can not fit, find new scale 
		for (var scale = MAX_SCALE*100; scale >= MIN_SCALE*100; scale -= 10) {
			tileScale = scale/100; //new scale 
			canvasX = (BASE_SCREEN_X+toolAreaX) * tileScale + EDIT_PADDING * (NO_OF_TILES_X+1);
			canvasY =  BASE_SCREEN_Y * tileScale + EDIT_PADDING * (NO_OF_TILES_Y+1);
			if (canvasX <= (screenX1 - menuIconAreaX) && canvasY <= screenY1 || tileScale <= MIN_SCALE) break;
		}
	}
	debug("EDIT SCALE = " + tileScale);

	var left = ((screenX1 - canvasX)/2|0),
		top  = ((screenY1 - canvasY)/2|0);
	
	if(left < menuIconAreaX) {
		narrowScreen = 1;
		left = ((screenX1 - canvasX - menuIconAreaX)/2|0);
	}

	canvas.width = canvasX;
	canvas.height = canvasY;
	
	canvas.style.left = (left>0?left:0) + "px";
	canvas.style.top =  (top>0?top:0) + "px";
	canvas.style.position = "absolute";
	canvas.style.cursor = "default";
	
	tileWScale = BASE_TILE_X * tileScale;
	tileHScale = BASE_TILE_Y * tileScale;
	
	editBorder = 4 * tileScale;	
	editStartX = (tileWScale + W2 * tileScale);
	
	return narrowScreen;
}

function createBaseTile()
{
	for(var id = 0; id < tileInfo.length; id++) {
		baseTile[id] = { image: getThemeBitmap(tileInfo[id][0]).image, id: id };
	}
	
	emptyTile = { image: getThemeBitmap("empty").image, id: 0 };
	actTile = baseTile[1];
}

function createEditMap() 
{
	var bmp;
		
	setCanvasBackground();
	setEditBackground(editStartX,0, 
				 (tileWScale+EDIT_PADDING)*NO_OF_TILES_X+EDIT_PADDING,
				 (tileHScale+EDIT_PADDING)*NO_OF_TILES_Y+EDIT_PADDING
	);
	initMapInfo();
	getTestLevel(testLevelInfo);
	
	
	//(1) create empty map[x][y] array;
	editMap = [];
	for(var x = 0; x < NO_OF_TILES_X; x++) {
		editMap[x] = [];
	}
	
	//(2) draw map
	var index = 0;
	for(var y = 0; y < NO_OF_TILES_Y; y++) {
		for(var x = 0; x < NO_OF_TILES_X; x++) {
			var id = tile2Id(testLevelInfo.levelMap.charAt(index++));
			var px = (tileWScale + EDIT_PADDING) * x+EDIT_PADDING + editStartX;
			var py = (tileHScale + EDIT_PADDING) * y+EDIT_PADDING;
			var back = new CanvasShape().fillRect("black", px, py, tileWScale, tileHScale);
			bmp = new CanvasBitmap(id == 0 ? emptyTile.image : baseTile[id].image);
			bmp.x = px;
			bmp.y = py;
			bmp.scaleX = bmp.scaleY = tileScale;
			editMap[x][y] = { bmp: bmp, id: id };
			canvasOverlay.add(back);
			canvasOverlay.add(bmp);
			addManCheck(id, x, y);
		}
	}
	
	drawEditGround();
	drawEditBlock(editStartX,0, canvasX-editStartX-1,
				 (tileHScale+EDIT_PADDING)*NO_OF_TILES_Y+EDIT_PADDING
	);
	
	addSelectIcon();
 	addCursorTile();
	drawEditLevel();
 	
	addEditorButton();
	
	mouseInStage = 1;
	mouseDown = 0;
	lastDown = {x:-1, y:-1};
}

function clearEditMap()
{
	initMapInfo();	
	for(var y = 0; y < NO_OF_TILES_Y; y++) {
		for(var x = 0; x < NO_OF_TILES_X; x++) {
			var tileObj = editMap[x][y];
			tileObj.bmp.image = emptyTile.image;
			tileObj.id = emptyTile.id;
		}
	}
	editMapIsEmpty = 1;
	stagePresent();
}

function tile2Id(tileChar)
{
	if( tileIdMapping.hasOwnProperty(tileChar)) {
		return tileIdMapping[tileChar];
	} else {
		return 0;
	}
}

function setCanvasBackground()
{
	canvasOverlay.add(new CanvasShape().fillRect("black", 0, 0, canvas.width, canvas.height));
	document.body.style.background = backgroundColor;
}

function setEditBackground(startX, startY, width, height)
{
	var editBack = new CanvasShape().fillRect("gold", startX, startY, width, height);
	editBack.alpha = 0.6;
	canvasOverlay.add(editBack);
}
	
function drawEditBlock(startX, startY, width, height)
{
	var editBlock = new CanvasShape().strokeRect("red", 2, startX, startY, width, height);
	editBlock.alpha = 0.6;
	canvasOverlay.add(editBlock);
}

function drawEditGround()
{
	var x = (tileWScale + EDIT_PADDING) * NO_OF_TILES_X+EDIT_PADDING + editStartX;
	var y = (tileHScale + EDIT_PADDING) * NO_OF_TILES_Y+EDIT_PADDING;
	
	var groundTile = new CanvasShape().fillRect(getThemeTileColor(), 0, y, x, 10*tileScale);
	canvasOverlay.add(groundTile); 
}

function addSelectIcon()
{
	var x = W4 * tileScale;
	var y;
	for(var i = 1; i < baseTile.length; i++) {
		y = (tileHScale*5/3)*(i-1) + tileHScale/10;
		drawSelectIcon(i, x, y);
	}
	y = (tileHScale*5/3)*(i-1) + tileHScale/10;
	drawSelectIcon(0, x, y);
}
	
function addCursorTile()
{
	var back = new CanvasShape().fillRect("black", 0, 0, tileWScale, tileHScale);
	var bmp = new CanvasBitmap(actTile.image);
	bmp.scaleX = bmp.scaleY = tileScale;
	back.alpha = 0;
	bmp.alpha = 0;
	canvasOverlay.add(back);
	canvasOverlay.add(bmp);
	cursorTileObj = { back: back, bmp: bmp, alpha: 0, x: 0, y: 0 };
}

function setCursorTileImage(image)
{
	cursorTileObj.bmp.image = image;
}

function setCursorTileAlpha(a)
{
	cursorTileObj.alpha = a;
	cursorTileObj.back.alpha = a;
	cursorTileObj.bmp.alpha = a;
}

function setCursorTileXY(x, y)
{
	cursorTileObj.x = x;
	cursorTileObj.y = y;
	cursorTileObj.back.x = x;
	cursorTileObj.back.y = y;
	cursorTileObj.bmp.x = x;
	cursorTileObj.bmp.y = y;
}

// Pointer-driven editor input (no Ticker / no setFPS(60)).
var editInputActive = 0;
var editPointerHandlers = null;

function editCanvasLocalXY(e)
{
	var canvas = document.getElementById("canvas");
	var rect = canvas.getBoundingClientRect();
	var sx = canvas.width / rect.width;
	var sy = canvas.height / rect.height;
	return {
		x: (e.clientX - rect.left) * sx,
		y: (e.clientY - rect.top) * sy
	};
}

function startEditInput()
{
	stopEditInput();

	var canvas = document.getElementById("canvas");
	editPointerHandlers = {
		down: function (e) {
			if (e.button !== 0 && e.buttons !== 1) return;
			var p = editCanvasLocalXY(e);
			if (tryEditUiClick(p.x, p.y)) {
				stagePresent();
				return;
			}
			mouseDown = 1;
			editPointerAt(p.x, p.y);
		},
		move: function (e) {
			mouseInStage = 1;
			if (e.buttons === 0) mouseDown = 0;
			var p = editCanvasLocalXY(e);
			editPointerAt(p.x, p.y);
		},
		up: function (e) {
			if (e.button !== 0) return;
			mouseDown = 0;
			lastDown = {x:-1, y:-1};
		},
		leave: function () {
			mouseInStage = 0;
			mouseDown = 0;
			lastDown = {x:-1, y:-1};
			if (cursorTileObj) setCursorTileAlpha(0);
			if (editorActiveTileId >= 0) selectTileMouseOut(editorTile[editorActiveTileId]);
			if (editorButtonMouseOverId >= 0) editorButtonMouseOut(editorButton[editorButtonMouseOverId]);
			stagePresent();
		},
		enter: function () {
			mouseInStage = 1;
		}
	};

	canvas.addEventListener("pointerdown", editPointerHandlers.down);
	canvas.addEventListener("pointermove", editPointerHandlers.move);
	canvas.addEventListener("pointerup", editPointerHandlers.up);
	canvas.addEventListener("pointerleave", editPointerHandlers.leave);
	canvas.addEventListener("pointerenter", editPointerHandlers.enter);
	editInputActive = 1;
}

function stopEditInput()
{
	if (!editInputActive && !editPointerHandlers) return;
	var canvas = document.getElementById("canvas");
	if (canvas && editPointerHandlers) {
		canvas.removeEventListener("pointerdown", editPointerHandlers.down);
		canvas.removeEventListener("pointermove", editPointerHandlers.move);
		canvas.removeEventListener("pointerup", editPointerHandlers.up);
		canvas.removeEventListener("pointerleave", editPointerHandlers.leave);
		canvas.removeEventListener("pointerenter", editPointerHandlers.enter);
	}
	editPointerHandlers = null;
	editInputActive = 0;
	mouseDown = 0;
	lastDown = {x:-1, y:-1};
}

/** Palette / toolbar click (replaces createjs Container click listeners). */
function tryEditUiClick(x, y)
{
	var i, cur;
	for(i = 0; i < editorTile.length; i++) {
		cur = editorTile[i];
		if(cur && cur.x <= x && cur.y <= y && cur.x1 >= x && cur.y1 >= y) {
			selectTileClick(cur);
			return 1;
		}
	}
	for(i = 0; i < editorButton.length; i++) {
		cur = editorButton[i];
		if(cur && cur.alpha && cur.x <= x && cur.y <= y && cur.x1 >= x && cur.y1 >= y) {
			if(cur.onClick) cur.onClick();
			return 1;
		}
	}
	return 0;
}

function drawSelectIcon(id, x, y)
{
	var selColor = (id == actTile.id) ? "red" : "black";
	var border = new CanvasShape().fillRect(selColor, x - editBorder, y - editBorder,
		tileWScale + editBorder * 2, tileHScale + editBorder * 2);
	var back = new CanvasShape().fillRect("black", x, y, tileWScale, tileHScale);
	var bmp = new CanvasBitmap(id == 0 ? preload.getResult("eraser") : baseTile[id].image);
	bmp.x = x;
	bmp.y = y;
	bmp.scaleX = bmp.scaleY = tileScale;

	canvasOverlay.add(border);
	canvasOverlay.add(back);
	canvasOverlay.add(bmp);

	var tile = {
		x: x, y: y, x1: x + tileWScale, y1: y + tileHScale,
		myId: id, border: border, back: back, bmp: bmp
	};
	if(id == actTile.id) selectedTile = tile;
	editorTile[id] = tile;
}
	
function selectTileClick(tile)
{
	editShapeFill(selectedTile.border, "black",
		selectedTile.x - editBorder, selectedTile.y - editBorder,
		tileWScale + editBorder * 2, tileHScale + editBorder * 2);
	editShapeFill(tile.border, "red",
		tile.x - editBorder, tile.y - editBorder,
		tileWScale + editBorder * 2, tileHScale + editBorder * 2);

	actTile = baseTile[tile.myId];
	setCursorTileImage(actTile.image);
	selectedTile = tile;
}
	
function drawEditLevel()
{
	var x = 17.2*(tileWScale+EDIT_PADDING)+EDIT_PADDING;	
	var y = canvas.height - tileHScale - editBorder;
	
	canvasOverlay.add(makeGlyphText(x, y, "EDIT"));
	x += 4.3*(tileWScale+EDIT_PADDING);
	canvasOverlay.add(makeGlyphText(x, y, "LEVEL"));
	drawEditLevelNo();
}

var editLevelNoObj = [];
function drawEditLevelNo()
{
	var y = canvas.height - tileHScale - editBorder;
	
	for(var i = 0; i < editLevelNoObj.length; i++) 
		canvasOverlay.remove(editLevelNoObj[i]);
	
	editLevelNoObj = [makeGlyphText(26.5*(tileWScale+EDIT_PADDING), y, ("00"+(testLevelInfo.level)).slice(-3))];
	canvasOverlay.add(editLevelNoObj[0]);
}

function addEditorButton()
{
	editorButton = [];
	editorButtonMouseOverId = -1;
	
	drawNewButton();
	drawLoadButton();
	drawTestButton();
	drawSaveButton();
	
	enableTestButton();
}

function makeEditorButton(label, x, y, onClick)
{
	var width = label.length * tileWScale;
	var border = new CanvasShape().fillRect("#40F",
		x - editBorder, y - editBorder, width + editBorder * 2, tileHScale + editBorder * 2);
	var back = new CanvasShape().fillRect("#FFF", x, y, width, tileHScale);
	var text = makeGlyphText(x, y, label);
	canvasOverlay.add(border);
	canvasOverlay.add(back);
	canvasOverlay.add(text);
	var button = {
		x: x, y: y, x1: x + width, y1: y + tileHScale,
		border: border, back: back, label: text,
		alpha: 1, onClick: onClick
	};
	editorButton[editorButton.length] = button;
	return button;
}

function drawNewButton()
{
	var x = 0.5*(tileWScale+EDIT_PADDING)+EDIT_PADDING;
	var y = canvas.height - tileHScale - editBorder;
	
	newButton = makeEditorButton("NEW", x, y, newButtonClick);
	
	function newLevel(rc)
	{
		if(rc) 	{
			clearEditMap();
			if(testLevelInfo.level <= editLevels) { //edit exist level
				testLevelInfo.level = editLevels+1;
				drawEditLevelNo();
			}
			if(testLevelInfo.level > MAX_EDIT_LEVEL) {
				setButtonState();
			} else {
				disableTestButton();
			}
			clearTestLevel();
			testLevelInfo.fromPlayData = -1; 
			testLevelInfo.fromLevel = -1;
		}
		startEditInput();
		gameResume();
		stagePresent(); // dialog closed off-canvas; paint without waiting for a mouse move
	}
	
	function newButtonClick()
	{
		gamePause();
		stopEditInput();
		if(testLevelInfo.modified) {
			yesNoDialog(["Abort current editing ?"], newLevel);
		} else {
			newLevel(1);
		}
	}
}

function drawLoadButton()
{
	var x = 4*(tileWScale+EDIT_PADDING)+EDIT_PADDING;
	var y = canvas.height - tileHScale - editBorder;

	loadButton = makeEditorButton("LOAD", x, y, loadButtonClick);

	function saveState()
	{
		gamePause();
		stopEditInput();
	}

	function restoreState()
	{
		startEditInput();
		gameResume();
	}

	// Editor Load always opens on Custom Levels. Shipped packs stay one
	// dropdown click away; defaulting to Classic while the banner says
	// "Custom Levels / Edit Mode" is the wrong first impression.
	function openLevelPicker()
	{
		levelSelect.open({
			current: 1,
			startPlayData: PLAY_DATA_USERDEF,
			browseOnly: true,
			onPick: function(level, versionId) {
				ensurePlayVersionLoaded(versionId, function() {
					var data = (versionId == PLAY_DATA_USERDEF)
						? (editLevelData || [])
						: (getPlayVerData(versionId) || []);
					if(!data[level-1]) { restoreState(); return; }
					testLevelInfo.levelMap = data[level-1];
					testLevelInfo.pass = 1;
					testLevelInfo.fromPlayData = versionId;
					testLevelInfo.fromLevel = level;
					testLevelInfo.modified = 0; // freshly loaded baseline, not dirty
					setTestLevel(testLevelInfo);
					restoreState();
					startEditMode();
				});
			},
			onClose: restoreState
		});
	}

	function loadExistLevel(yes)
	{
		if(yes) openLevelPicker();
		else restoreState();
	}

	function loadButtonClick()
	{
		saveState();
		// Same dirty gate as NEW / leaveEdit — a non-empty map is not "editing".
		if(testLevelInfo.modified) {
			yesNoDialog(["Abort current editing ?"], loadExistLevel);
		} else {
			loadExistLevel(1);
		}
	}
}

function drawTestButton()
{
	var x = 8.5*(tileWScale+EDIT_PADDING)+EDIT_PADDING;
	var y = canvas.height - tileHScale - editBorder;
	
	testButton = makeEditorButton("TEST", x, y, testButtonClick);
	setEditorButtonAlpha(testButton, 0);
	
	function testButtonClick()
	{
		startTestMode();
	}
}

function drawSaveButton()
{
	var x = 13*(tileWScale+EDIT_PADDING)+EDIT_PADDING;
	var y = canvas.height - tileHScale - editBorder;
	
	saveButton = makeEditorButton("SAVE", x, y, saveButtonClick);
	setEditorButtonAlpha(saveButton, 0);

	function saveButtonClick()
	{
		gamePause();
		stopEditInput();
		saveEditLevel();
		yesNoDialog(["Save Successful", "Play It ?"], playConfirm);

	}

	function playConfirm(rc)
	{
		gameResume();
		if(rc) { //yes
			clearTestLevel(); //clear current edit level 
			startPlayUserLevel();
		} else { //no
			setButtonState();
			startEditInput();
		}
	}
	
	function startPlayUserLevel()
	{
		removeEditUnloadGuard();
		playMode = PLAY_MODERN;
		playData = PLAY_DATA_USERDEF;

		curLevel = testLevelInfo.level;
		setModernInfo();
	
		canvasReSize();
		setKeyHandler(handleKeyDown);
		initShowDataMsg();
		startGame();
	}	
}

//=======================
// BEGIN for TEST Mode 
//=======================
function startTestMode()
{
	playMode = PLAY_TEST;
	playData = PLAY_DATA_USERDEF;
	
	curLevel = testLevelInfo.level;
	stopEditInput();
	saveTestState();
	canvasReSize();
	setKeyHandler(handleKeyDown); //key press
	initShowDataMsg();
	startGame();
}

function saveTestState()
{
	map2LevelData();
	setTestLevel(testLevelInfo);
}

function back2EditMode(rc)
{
	if(rc == 1) { //pass
		testLevelInfo.pass = 1;
		setTestLevel(testLevelInfo);
		//enableSaveButton();
	} else { //fail
		//if(testLevelInfo.pass && !testLevelInfo.modified) enableSaveButton();
	}
	startEditMode();
}

function getTestLevelMap(initValue)
{
	return testLevelInfo.levelMap;
}

function enableTestButton()
{
	if(lastRunner) setEditorButtonAlpha(testButton, 1);
}
//==========================

function editLevelModified()
{
	return (testLevelInfo.modified);
}

/** True when edit session has unsaved paint (for tab close / leave guards). */
function editHasUnsavedChanges()
{
	return playMode == PLAY_EDIT && editLevelModified();
}

var editUnloadGuardInstalled = 0;

function editBeforeUnload(e)
{
	if (!editHasUnsavedChanges()) return;
	e.preventDefault();
	e.returnValue = "";
	return "";
}

function installEditUnloadGuard()
{
	if (editUnloadGuardInstalled) return;
	window.addEventListener("beforeunload", editBeforeUnload);
	document.addEventListener("keydown", editShortcutKeyDown, true);
	editUnloadGuardInstalled = 1;
}

function removeEditUnloadGuard()
{
	if (!editUnloadGuardInstalled) return;
	window.removeEventListener("beforeunload", editBeforeUnload);
	document.removeEventListener("keydown", editShortcutKeyDown, true);
	editUnloadGuardInstalled = 0;
}

// Ctrl/Cmd+C/V while editing -- capture on document so paste works even when
// focus is not on the game canvas (settings close, board icons).
function editShortcutKeyDown(event)
{
	if(playMode != PLAY_EDIT) return;
	if(!(event.ctrlKey || event.metaKey)) return;
	if(event.keyCode != KEYCODE_C && event.keyCode != KEYCODE_V) return;

	var t = event.target;
	if(t && (t.tagName == "INPUT" || t.tagName == "TEXTAREA" || t.isContentEditable)) return;
	if(document.querySelector("dialog[open]")) return;

	if(editHandleKeyDown(event) === false) {
		event.preventDefault();
		event.stopPropagation();
	}
}

/**
 * Leave edit for another mode. Confirms if the map is dirty, then runs nextFun.
 * cancelFun runs if the user declines (defaults to resume edit input).
 */
function leaveEditMode(nextFun, cancelFun)
{
	disableAutoDemoTimer();
	clearIdleDemoTimer();
	stopEditInput();
	if (editLevelModified()) {
		yesNoDialog(["Abort current editing ?"],
			function (rc) {
				if (rc) {
					testLevelInfo.modified = 0;
					removeEditUnloadGuard();
					nextFun();
				} else if (cancelFun) {
					cancelFun();
				} else {
					startEditInput();
					installEditUnloadGuard();
					gameResume();
				}
			});
		return;
	}
	removeEditUnloadGuard();
	nextFun();
}

function editConfirmAbortState(callbackFun)
{
	gamePause();
	stopEditInput();
	yesNoDialog(["Abort current editing ?"],
				function(rc) {  gameResume(); if(rc) callbackFun(); else startEditInput(); } );
}

function disableTestButton()
{
	setEditorButtonAlpha(testButton, 0);
	setEditorButtonAlpha(saveButton, 0);
}

function clearUserLevelScore()
{
	playData = PLAY_DATA_USERDEF;
	getModernScoreInfo();
	modernScoreInfo[testLevelInfo.level-1] = -1;
	setModernScoreInfo();
}

function delUserLevelScore(level)
{
	playData = PLAY_DATA_USERDEF;
	getModernScoreInfo();
	modernScoreInfo.splice(level-1, 1);
	modernScoreInfo[MAX_EDIT_LEVEL-1] = -1;
	setModernScoreInfo();
}

function saveEditLevel()
{
	map2LevelData();
	if(testLevelInfo.level > editLevels) { // new level
		addEditLevel(testLevelInfo.levelMap);
	} else {
		setEditLevel(testLevelInfo.level, testLevelInfo.levelMap);
	}
	clearUserLevelScore(); //clear score 
	testLevelInfo.modified = 0;
	setEditSelectMenu();
}
	
function initMapInfo()
{
	lastRunner = null;
	lastGuardList = [];	

	testLevelInfo.modified = 0;
	testLevelInfo.pass = 0;
}
		
function addManCheck(id, x, y)
{
	switch(id) {
	case RUNNER_ID:
		if (lastRunner && (lastRunner.x != x || lastRunner.y != y)) {
			var lastRunnerTile = editMap[lastRunner.x][lastRunner.y];
			lastRunnerTile.bmp.image = emptyTile.image;
			lastRunnerTile.id = emptyTile.id;
		}
		lastRunner = { x:x, y:y };
		break;	
	case GUARD_ID:
		var sameGuard=0, guardNo = lastGuardList.length;
			
		for(var i = 0; i < guardNo; i++) {
			if(lastGuardList[i].x == x && lastGuardList[i].y == y) {
				sameGuard = 1;
				break;
			}
		}
		if(!sameGuard) {
			if(guardNo >= MAX_EDIT_GUARD) { //too many guards remove first one
				var x1 = lastGuardList[0].x, y1 = lastGuardList[0].y;
				var guardTile = editMap[x1][y1];
					
				guardTile.bmp.image = emptyTile.image;
				guardTile.id = emptyTile.id;
				lastGuardList.splice(0,1); //remove first one from array
			}
			lastGuardList.push({x:x, y:y});
		}
		break;	
	}
}

function delManCheck(id, x, y)
{
	switch(id) {
	case RUNNER_ID:
		//assert(lastRunner != null, "runner == null error");
		var lastRunnerTile = editMap[lastRunner.x][lastRunner.y];
		lastRunnerTile.bmp.image = emptyTile.image;
		lastRunnerTile.id = emptyTile.id;
		lastRunner = null;
		disableTestButton();	
		break;
	case GUARD_ID:		
		var removeId = -1, guardNo = lastGuardList.length;
			
		for(var i = 0; i < guardNo; i++) {
			if(lastGuardList[i].x == x && lastGuardList[i].y == y) {
				removeId = i;
				break;
			}
		}
		if(removeId >= 0) {
			var x1 = lastGuardList[removeId].x, y1 = lastGuardList[removeId].y;
			var guardTile = editMap[x1][y1];
			
			guardTile.bmp.image = emptyTile.image;
			guardTile.id = emptyTile.id;
			lastGuardList.splice(removeId,1);
		} else {
			error("design error !");
		}
		break;	
	}
}

//state: = 0: no change, < 0: level deleted, > 0 level change to newLevel
function editSelectMenuClose(levelDeleted, newLevel, state)
{
	if(levelDeleted) {
		
		setEditSelectMenu();
		startEditMode();
/*	
	Bug fixed: If player delete some custom levels and restart the program immediate will cause 
	           testLevel inconsistent, must del or shift testlevel immediate.  
	           ==> so move below statements into function delLevel(level).	

	switch(true) {
		case (state > 0): //level number changed
			//getTestLevel(testLevelInfo);
			//testLevelInfo.level = newLevel;
			//setTestLevel(testLevelInfo);
			startEditMode();
			break;
		case (state < 0): //level deleted
			//clearTestLevel();
			setEditSelectMenu();	
			startEditMode();
			break;	
		case (state == 0 && newLevel == 0): //newLevel = 0 : meanings edit new level just need change level id
			//if(testLevelInfo.modified == 1) {	
			//	testLevelInfo.level = editLevels+1;
			//	setTestLevel(testLevelInfo);
			//} 
			startEditMode();
			break;
		}
*/		
	}
}

function editSelectLevel(level)
{
	testLevelInfo.level = level;
	testLevelInfo.levelMap = editLevelData[level-1];
	testLevelInfo.fromPlayData = testLevelInfo.fromLevel = -1;
	setTestLevel(testLevelInfo);
	startEditMode();
}

function map2LevelData()
{
	var i=0;
	
	testLevelInfo.levelMap = "";
	for(var y = 0; y < NO_OF_TILES_Y; y++) {
		for(var x = 0; x < NO_OF_TILES_X; x++) {
			testLevelInfo.levelMap += tileInfo[editMap[x][y].id][1];
		}
	}
}

function checkEditMapEmpty()
{
	editMapIsEmpty = 1;
	
	mapCheckLoop:
	for(var y = 0; y < NO_OF_TILES_Y; y++) {
		for(var x = 0; x < NO_OF_TILES_X; x++) {
			if(editMap[x][y].id != emptyTile.id) {
				editMapIsEmpty = 0;
				break mapCheckLoop;
			}
		}
	}
}

function copyEditingMap()
{
	var curEditMap = "";
	for(var y = 0; y < NO_OF_TILES_Y; y++) {
		for(var x = 0; x < NO_OF_TILES_X; x++) {
			curEditMap += tileInfo[editMap[x][y].id][1];
		}
	}
	
	return curEditMap;
}

//==============================
// Too many user created Levels
//==============================
var editWarningText = null;
function editWarningMsg(hidden)
{
	var width, height;

	if(editWarningText == null) {
		editWarningText = new CanvasText("Too many custom levels !",
			"bold " + (64 * tileScale) + "px Helvetica", "#fc5c1c");
		editWarningText.setShadow("white", tileScale, 2 * tileScale, 1);
	}
	
	var bounds = editWarningText.getBounds();
	width = bounds.width;
	height = bounds.height;
	editWarningText.x = ((NO_OF_TILES_X+2)*(tileWScale+EDIT_PADDING) - width) / 2 | 0;
	editWarningText.y = (NO_OF_TILES_Y*tileHScale - height) / 2 | 0;
	
	if(hidden) {
		canvasOverlay.remove(editWarningText);
	} else {
		canvasOverlay.add(editWarningText);
	}
	stagePresent();
}

var copyLevelMap = null, copyLevelPassed = 0;
function editHandleKeyDown(event)
{
	if(!event){ event = window.event; } //cross browser issues exist

	// metaKey: Cmd on macOS (users paste with Cmd+V as often as Ctrl+V)
	if (event.ctrlKey || event.metaKey) {
		switch(event.keyCode) {
		case KEYCODE_C: //CTRL-C : copy current level
			if (!editMapIsEmpty) {	
				copyLevelMap = copyEditingMap();
				copyLevelPassed = (!testLevelInfo.modified && lastRunner) || testLevelInfo.pass;
				setTimeout(function() { showTipsText("COPY MAP", 1500);}, 50);
				return false;
			}
			break;	
		case KEYCODE_V: //CTRL-V : paste copy map
			if(copyLevelMap != null && editMapIsEmpty && testLevelInfo.level <= MAX_EDIT_LEVEL) {
				editPasteMap();
				return false;
			}
			break;	
		}
	}
	return true;
}	

function editPasteMap()
{
	testLevelInfo.levelMap = copyLevelMap;
	testLevelInfo.modified = 1;
	testLevelInfo.pass = copyLevelPassed;
	testLevelInfo.fromPlayData = testLevelInfo.fromLevel = -1;
	setTestLevel(testLevelInfo);
	copyLevelMap = null; //clear copy map after paste
	startEditMode();
	////setButtonState();
	setTimeout(function() { showTipsText("PASTE MAP", 1500);}, 50);
}

function checkTileMouseOver(x, y)
{
	var curTile;
	for(var i = 0; i < editorTile.length; i++) {
		curTile = editorTile[i];
		if(curTile.x <= x && curTile.y <= y && curTile.x1 >= x && curTile.y1 >= y) {
			if(editorActiveTileId == i) return;
			selectTileMouseOver(curTile);
			if(editorActiveTileId >= 0) selectTileMouseOut(editorTile[editorActiveTileId]);
			editorActiveTileId = i;
			return;
		}
	}
	if(editorActiveTileId >= 0) selectTileMouseOut(editorTile[editorActiveTileId]);
	editorActiveTileId = -1;
}

function selectTileMouseOver(tile)
{ 
	editShapeFill(tile.border, "gold",
		tile.x - editBorder, tile.y - editBorder,
		tileWScale + editBorder * 2, tileHScale + editBorder * 2);
	canvas.style.cursor = "pointer";
}
	
function selectTileMouseOut(tile)
{ 
	var color = (actTile.id == tile.myId) ? "red" : "black";
	editShapeFill(tile.border, color,
		tile.x - editBorder, tile.y - editBorder,
		tileWScale + editBorder * 2, tileHScale + editBorder * 2);
	canvas.style.cursor = "default";
}

function checkButtonMouseOver(x, y)
{
	var curButton;
	for(var i = 0; i < editorButton.length; i++) {
		curButton = editorButton[i];
		if(curButton.x <= x && curButton.y <= y && curButton.x1 >= x && curButton.y1 >= y) {
			if(editorButtonMouseOverId == i) return;
			editorButtonMouseOver(curButton);
			if(editorButtonMouseOverId >= 0) editorButtonMouseOut(editorButton[editorButtonMouseOverId]);
			editorButtonMouseOverId = i;
			return;
		}
	}
	if(editorButtonMouseOverId >= 0) editorButtonMouseOut(editorButton[editorButtonMouseOverId]);
	editorButtonMouseOverId = -1;
}

function editorButtonMouseOver(button)
{
	var width = button.x1 - button.x;
	editShapeFill(button.border, "red",
		button.x - editBorder, button.y - editBorder,
		width + editBorder * 2, tileHScale + editBorder * 2);
	editShapeFill(button.back, "#ffa", button.x, button.y, width, tileHScale);
	if (button.alpha)
		canvas.style.cursor = "pointer";	
}
	
function editorButtonMouseOut(button)
{
	var width = button.x1 - button.x;
	editShapeFill(button.border, "#40F",
		button.x - editBorder, button.y - editBorder,
		width + editBorder * 2, tileHScale + editBorder * 2);
	editShapeFill(button.back, "#fff", button.x, button.y, width, tileHScale);
	canvas.style.cursor = "default";	
}	

function setButtonState()
{
	if(testLevelInfo.level > MAX_EDIT_LEVEL) {
		setEditorButtonAlpha(newButton, 0);
		setEditorButtonAlpha(loadButton, 0);
		setEditorButtonAlpha(testButton, 0);
		setEditorButtonAlpha(saveButton, 0);
		canvas.style.cursor = "default";
		editWarningMsg(0);
		return;
	} else {
		setEditorButtonAlpha(newButton, 1);
		editWarningMsg(1);
	}
	
	if(testLevelInfo.modified) 	{
		enableTestButton();
		if(testLevelInfo.pass) {
			setEditorButtonAlpha(saveButton, 1);
		} else {
			setEditorButtonAlpha(saveButton, 0);
		}
	} else {
		testLevelInfo.pass = 0;
		setEditorButtonAlpha(saveButton, 0);
	}
} 

/** Process editor pointer at stage/canvas coordinates (replaces editTick poll). */
function editPointerAt(stageX, stageY)
{
	var x = ((stageX-EDIT_PADDING - editStartX)/(tileWScale+EDIT_PADDING));
	x = (x < 0)?-1:(x|0);
	var y = ((stageY-EDIT_PADDING) / (tileHScale+EDIT_PADDING) )| 0;
	var dirty = 0;
	
	if(testLevelInfo.level <= MAX_EDIT_LEVEL) {
		if(mouseInStage && x >= 0 && x < NO_OF_TILES_X && y >= 0 && y < NO_OF_TILES_Y) {
			if(editorActiveTileId >= 0) { selectTileMouseOut(editorTile[editorActiveTileId]); dirty = 1; }
			if(editorButtonMouseOverId >= 0) { editorButtonMouseOut(editorButton[editorButtonMouseOverId]); dirty = 1; }

			if( x != lastDown.x || y != lastDown.y) {
				setCursorTileXY(
					(tileWScale + EDIT_PADDING) * x+EDIT_PADDING + editStartX,
					(tileHScale + EDIT_PADDING) * y+EDIT_PADDING
				);
				setCursorTileAlpha(1);
				dirty = 1;
				if(mouseDown) {
					var clickTile = editMap[x][y];

					if(!actTile.id || clickTile.id == actTile.id) {
						if(actTile.id) setCursorTileAlpha(0.1);
						delManCheck(clickTile.id, x, y);
						clickTile.bmp.image = emptyTile.image;
						clickTile.id = emptyTile.id;
					} else {	
						delManCheck(clickTile.id, x, y);
						clickTile.bmp.image = actTile.image;
						clickTile.id = actTile.id;
						addManCheck(actTile.id, x, y);
					}
					lastDown = {x:x, y:y};
					checkEditMapEmpty();

					if(testLevelInfo.pass || actTile.id == RUNNER_ID || testLevelInfo.modified == 0) {
						testLevelInfo.modified = 1;
						testLevelInfo.pass = 0;
						setButtonState();
					}
				}
			}
		} else {
			var prevActive = editorActiveTileId;
			var prevBtn = editorButtonMouseOverId;
			checkTileMouseOver(stageX, stageY);
			checkButtonMouseOver(stageX, stageY);
			if (cursorTileObj.alpha !== 0) {
				setCursorTileAlpha(0);
				dirty = 1;
			}
			if (prevActive !== editorActiveTileId || prevBtn !== editorButtonMouseOverId) dirty = 1;
		}
	}
	if (dirty) stagePresent();
}

function levelMapIsEmpty(levelMap)
{
	for(i =0; i < levelMap.length; i++) {
		if (levelMap[i] != ' ') return 0; 
	}
	return 1;
}