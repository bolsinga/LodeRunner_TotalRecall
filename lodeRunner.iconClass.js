
var mouseOverBGColor = "#fefef1"; //icon background color while mouse over it

function mainMenuIconClass( _screenX1, _screenY1, _scale, _mainMenuBitmap)
{
	var border = 4 * _scale;
	var nat = iconBitmapNaturalSize(_mainMenuBitmap);
	var bitmapX = nat.width * _scale;
	var bitmapY = nat.height * _scale;
	var icon;
	var saveStateObj;
	var self = this;
	var enabled = 0;

	init();

	function init()
	{
		var w = bitmapX + border * 2;
		var h = bitmapY + border * 2;
		icon = createIconCanvas({
			id: "main_menu",
			width: w,
			height: h,
			left: (_screenX1 - w - screenBorder),
			top: (bitmapY / 2) | 0,
			border: border,
			scale: _scale
		});
		icon.setBitmap(_mainMenuBitmap);
		icon.setAlpha(0);
	}

	this.enable = function ()
	{
		if (enabled) return;
		enabled = 1;
		disableMouseHandler();
		enableMouseHandler();
		icon.setAlpha(1);
	};

	this.disable = function (hidden)
	{
		disableMouseHandler();
		icon.setAlpha(hidden ? 0 : 1);
		enabled = 0;
	};

	function enableMouseHandler()
	{
		icon.enablePointer({ over: mouseOver, out: mouseOut, click: mouseClick });
	}

	function disableMouseHandler()
	{
		icon.disablePointer();
		icon.setCursor("default");
		icon.setHovered(false);
	}

	function mouseOver()
	{
		if (gameState == GAME_PAUSE ||
		   (gameState != GAME_START && gameState != GAME_RUNNING && playMode != PLAY_EDIT)) return;
		icon.setCursor("pointer");
		icon.setHovered(true);
	}

	function mouseOut()
	{
		icon.setCursor("default");
		icon.setHovered(false);
	}

	function mouseClick()
	{
		if (gameState == GAME_PAUSE ||
		   (gameState != GAME_START && gameState != GAME_RUNNING && playMode != PLAY_EDIT)) return;
		saveState();
		gameMenu(restoreState);
		mouseOut();
	}

	function saveState()
	{
		saveStateObj = saveKeyHandler(noKeyDown);
		gamePause();
		if (playMode == PLAY_EDIT) {
			if (editLevelModified()) saveTestState();
			stopEditInput();
		} else {
			stopPlayTicker();
			stopAllSpriteObj();
		}
		self.disable();
	}

	function restoreState()
	{
		restoreKeyHandler(saveStateObj);
		if (playMode == PLAY_EDIT) {
			startEditInput();
		} else {
			startAllSpriteObj();
			startPlayTicker();
		}
		gameResume();
		self.enable();
	}
}

function selectIconClass( _screenX1, _screenY1, _scale, _bitmap)
{
	var border = 4 * _scale;
	var nat = iconBitmapNaturalSize(_bitmap);
	var bitmapX = nat.width * _scale;
	var bitmapY = nat.height * _scale;
	var icon;
	var saveStateObj;
	var self = this;
	var enabled = 0;

	init();

	function init()
	{
		var w = bitmapX + border * 2;
		var h = bitmapY + border * 2;
		icon = createIconCanvas({
			id: "select_menu",
			width: w,
			height: h,
			left: (_screenX1 - w - screenBorder),
			top: (h + bitmapY) | 0,
			border: border,
			scale: _scale
		});
		icon.setBitmap(_bitmap);
		icon.setAlpha(0);
	}

	this.enable = function ()
	{
		if (enabled) return;
		enabled = 1;
		disableMouseHandler();
		enableMouseHandler();
		icon.bringToFront();
		icon.setAlpha(1);
	};

	this.disable = function (hidden)
	{
		disableMouseHandler();
		icon.setAlpha(hidden ? 0 : 1);
		enabled = 0;
	};

	function enableMouseHandler()
	{
		icon.enablePointer({ over: mouseOver, out: mouseOut, click: mouseClick });
	}

	function disableMouseHandler()
	{
		icon.disablePointer();
		icon.setCursor("default");
		icon.setHovered(false);
	}

	function mouseOver()
	{
		if (gameState == GAME_PAUSE ||
		   (gameState != GAME_START && gameState != GAME_RUNNING && playMode != PLAY_EDIT)) return;
		icon.setCursor("pointer");
		icon.setHovered(true);
	}

	function mouseOut()
	{
		icon.setCursor("default");
		icon.setHovered(false);
	}

	function startSelectMenu()
	{
		saveState();
		activeSelectMenu(activeSelectPlay, restoreState);
		mouseOut();
	}

	function mouseClick()
	{
		if (gameState == GAME_PAUSE ||
		   (gameState != GAME_START && gameState != GAME_RUNNING && playMode != PLAY_EDIT)) return;

		if (playMode == PLAY_EDIT && editLevelModified()) {
			if (editLevelModified()) saveTestState();
			editConfirmAbortState(startSelectMenu);
		} else {
			startSelectMenu();
		}
	}

	function activeSelectPlay(level)
	{
		soundStop(soundDig);
		soundStop(soundFall);
		switch (playMode) {
		case PLAY_EDIT:
			editSelectLevel(level);
			break;
		case PLAY_DEMO:
			curLevel = level;
			setDemoInfo();
			startGame();
			break;
		case PLAY_MODERN:
			curLevel = level;
			setModernInfo();
			startGame();
			break;
		default:
			debug("activeSelectPlay design error ! playMode = " + playMode);
			break;
		}
	}

	function saveState()
	{
		saveStateObj = saveKeyHandler(noKeyDown);
		gamePause();
		if (playMode == PLAY_EDIT) {
			stopEditInput();
		} else {
			stopPlayTicker();
			stopAllSpriteObj();
		}
		self.disable();
	}

	function restoreState()
	{
		restoreKeyHandler(saveStateObj);
		if (playMode == PLAY_EDIT) {
			startEditInput();
		} else {
			startAllSpriteObj();
			startPlayTicker();
		}
		gameResume();
		self.enable();
	}
}

function demoIconClass( _screenX1, _screenY1, _scale, _bitmap)
{
	var border = 4 * _scale;
	var nat = iconBitmapNaturalSize(_bitmap);
	var bitmapX = nat.width * _scale;
	var bitmapY = nat.height * _scale;
	var icon;
	var self = this;
	var enabled = 0;

	init();

	function init()
	{
		var w = bitmapX + border * 2;
		var h = bitmapY + border * 2;
		icon = createIconCanvas({
			id: "demo_menu",
			width: w,
			height: h,
			left: (_screenX1 - w - screenBorder),
			top: (h * 2 + bitmapY * 3 / 2) | 0,
			border: border,
			scale: _scale
		});
		icon.setBitmap(_bitmap);
		icon.setAlpha(0);
	}

	this.enable = function ()
	{
		if (!curDemoLevelIsVaild()) {
			self.disable(1);
			return;
		}
		if (enabled) return;

		enabled = 1;
		disableMouseHandler();
		enableMouseHandler();
		icon.bringToFront();
		icon.setAlpha(1);
	};

	this.disable = function (hidden)
	{
		disableMouseHandler();
		icon.setAlpha(hidden ? 0 : 1);
		enabled = 0;
	};

	function enableMouseHandler()
	{
		icon.enablePointer({ over: mouseOver, out: mouseOut, click: mouseClick });
	}

	function disableMouseHandler()
	{
		icon.disablePointer();
		icon.setCursor("default");
		icon.setHovered(false);
	}

	function mouseOver()
	{
		if (gameState == GAME_PAUSE ||
		   (gameState != GAME_START && playMode != PLAY_DEMO && playMode != PLAY_DEMO_ONCE && playMode != PLAY_EDIT))
			return;

		icon.setCursor("pointer");
		icon.setHovered(true);
	}

	function mouseOut()
	{
		icon.setCursor("default");
		icon.setHovered(false);
	}

	function mouseClick()
	{
		if (gameState == GAME_PAUSE || playMode == PLAY_DEMO_ONCE ||
		   (gameState != GAME_START && playMode != PLAY_DEMO && playMode != PLAY_EDIT))
			return;

		mouseOut();
		demoSoundOff = 1; //always sound off when start demo
		playMode = PLAY_DEMO_ONCE;
		anyKeyStopDemo();

		startGame(1);
		setTimeout(function() { showTipsText("HIT ANY KEY TO STOP DEMO", 3500); }, 50);
	}
}

function soundIconClass( _screenX1, _screenY1, _scale, _soundOnBitmap, _soundOffBitmap)
{
	var border = 4 * _scale;
	var nat = iconBitmapNaturalSize(_soundOnBitmap);
	var bitmapX = nat.width * _scale;
	var bitmapY = nat.height * _scale;
	var icon;
	var self = this;
	var enabled = 0;

	function init()
	{
		var w = bitmapX + border * 2;
		var h = bitmapY + border * 2;
		icon = createIconCanvas({
			id: "sound_menu",
			width: w,
			height: h,
			left: (_screenX1 - w - screenBorder),
			top: (_screenY1 - bitmapY * 8.6) | 0,
			border: border,
			scale: _scale
		});
		icon.setAlpha(0);
		self.updateSoundImage();
	}

	this.enable = function ()
	{
		if (enabled) return;
		enabled = 1;
		disableMouseHandler();
		enableMouseHandler();
		icon.setAlpha(1);
	};

	this.disable = function (hidden)
	{
		disableMouseHandler();
		icon.setAlpha(hidden ? 0 : 1);
		enabled = 0;
	};

	function enableMouseHandler()
	{
		icon.enablePointer({ over: mouseOver, out: mouseOut, click: mouseClick });
	}

	function disableMouseHandler()
	{
		icon.disablePointer();
		icon.setCursor("default");
		icon.setHovered(false);
	}

	this.updateSoundImage = function ()
	{
		if (playMode == PLAY_DEMO || playMode == PLAY_DEMO_ONCE) {
			icon.setBitmap(demoSoundOff ? _soundOffBitmap : _soundOnBitmap);
		} else {
			icon.setBitmap(soundOff ? _soundOffBitmap : _soundOnBitmap);
		}
	};

	function mouseOver()
	{
		if (gameState == GAME_PAUSE || (gameState != GAME_START && gameState != GAME_RUNNING)) return;

		icon.setCursor("pointer");
		icon.setHovered(true);
	}

	function mouseOut()
	{
		icon.setCursor("default");
		icon.setHovered(false);
	}

	function mouseClick()
	{
		if (gameState == GAME_PAUSE || (gameState != GAME_START && gameState != GAME_RUNNING)) return;

		if (playMode == PLAY_DEMO || playMode == PLAY_DEMO_ONCE) {
			if ((demoSoundOff ^= 1)) { soundStop(soundDig); soundStop(soundFall); }
		} else {
			if ((soundOff ^= 1)) { soundStop(soundDig); soundStop(soundFall); }
		}

		resumeAudioContext();

		self.updateSoundImage();
		mouseOut();
	}

	init();
}

function repeatActionIconClass( _screenX1, _screenY1, _scale, _repeatActionOnBitmap, _repeatActionOffBitmap)
{
	var border = 4 * _scale;
	var nat = iconBitmapNaturalSize(_repeatActionOnBitmap);
	var bitmapX = nat.width * _scale;
	var bitmapY = nat.height * _scale;
	var icon;
	var self = this;
	var enabled = 0;

	function init()
	{
		var w = bitmapX + border * 2;
		var h = bitmapY + border * 2;
		icon = createIconCanvas({
			id: "repeat_menu",
			width: w,
			height: h,
			left: (_screenX1 - w - screenBorder),
			top: (_screenY1 - bitmapY * 6.4) | 0,
			border: border,
			scale: _scale
		});
		icon.setAlpha(0);
		self.updateRepeatActionImage();
	}

	this.enable = function ()
	{
		if (enabled) return;
		enabled = 1;
		disableMouseHandler();
		enableMouseHandler();
		icon.setAlpha(1);
	};

	this.disable = function (hidden)
	{
		disableMouseHandler();
		icon.setAlpha(hidden ? 0 : 1);
		enabled = 0;
	};

	function enableMouseHandler()
	{
		icon.enablePointer({ over: mouseOver, out: mouseOut, click: mouseClick });
	}

	function disableMouseHandler()
	{
		icon.disablePointer();
		icon.setCursor("default");
		icon.setHovered(false);
	}

	this.updateRepeatActionImage = function ()
	{
		icon.setBitmap(repeatAction ? _repeatActionOnBitmap : _repeatActionOffBitmap);
	};

	function mouseOver()
	{
		if (gameState == GAME_PAUSE || (gameState != GAME_START && gameState != GAME_RUNNING) ||
		   playMode == PLAY_DEMO || playMode == PLAY_DEMO_ONCE || playMode == PLAY_EDIT) return;

		icon.setCursor("pointer");
		icon.setHovered(true);
	}

	function mouseOut()
	{
		icon.setCursor("default");
		icon.setHovered(false);
	}

	function mouseClick()
	{
		if (gameState == GAME_PAUSE || (gameState != GAME_START && gameState != GAME_RUNNING) ||
		   playMode == PLAY_DEMO || playMode == PLAY_DEMO_ONCE || playMode == PLAY_EDIT) return;

		toggleRepeatAction();
		self.updateRepeatActionImage();
		mouseOut();
	}

	init();
}

function infoIconClass( _screenX1, _screenY1, _scale, _bitmap)
{
	var border = 4 * _scale;
	var nat = iconBitmapNaturalSize(_bitmap);
	var bitmapX = nat.width * _scale;
	var bitmapY = nat.height * _scale;
	var icon;
	var saveStateObj;
	var self = this;
	var enabled = 0;

	function init()
	{
		var w = bitmapX + border * 2;
		var h = bitmapY + border * 2;
		icon = createIconCanvas({
			id: "info_menu",
			width: w,
			height: h,
			left: (_screenX1 - w - screenBorder),
			top: (_screenY1 - bitmapY * 4.8),
			border: border,
			scale: _scale
		});
		icon.setBitmap(_bitmap);
		icon.setAlpha(0);
	}

	this.enable = function ()
	{
		if (enabled) return;
		enabled = 1;
		disableMouseHandler();
		enableMouseHandler();
		icon.setAlpha(1);
	};

	this.disable = function (hidden)
	{
		disableMouseHandler();
		icon.setAlpha(hidden ? 0 : 1);
		enabled = 0;
	};

	function enableMouseHandler()
	{
		icon.enablePointer({ over: mouseOver, out: mouseOut, click: mouseClick });
	}

	function disableMouseHandler()
	{
		icon.disablePointer();
		icon.setCursor("default");
		icon.setHovered(false);
	}

	function mouseOver()
	{
		if (gameState == GAME_PAUSE || (gameState != GAME_START && gameState != GAME_RUNNING && playMode != PLAY_EDIT)) return;

		icon.setCursor("pointer");
		icon.setHovered(true);
	}

	function mouseOut()
	{
		icon.setCursor("default");
		icon.setHovered(false);
	}

	function mouseClick()
	{
		if (gameState == GAME_PAUSE || (gameState != GAME_START && gameState != GAME_RUNNING && playMode != PLAY_EDIT)) return;
		saveState();
		infoMenu(restoreState, null);
		mouseOut();
	}

	function saveState()
	{
		saveStateObj = saveKeyHandler(noKeyDown);
		gamePause();
		if (playMode == PLAY_EDIT) {
			if (editLevelModified()) saveTestState();
			stopEditInput();
		} else {
			stopPlayTicker();
			stopAllSpriteObj();
		}
		self.disable();
	}

	function restoreState()
	{
		restoreKeyHandler(saveStateObj);
		if (playMode == PLAY_EDIT) {
			startEditInput();
		} else {
			startAllSpriteObj();
			startPlayTicker();
		}
		gameResume();
		self.enable();
	}

	init();
}

function helpIconClass( _screenX1, _screenY1, _scale, _bitmap)
{
	var border = 4 * _scale;
	var nat = iconBitmapNaturalSize(_bitmap);
	var bitmapX = nat.width * _scale;
	var bitmapY = nat.height * _scale;
	var icon;
	var saveStateObj;
	var self = this;
	var enabled = 0;

	function init()
	{
		var w = bitmapX + border * 2;
		var h = bitmapY + border * 2;
		icon = createIconCanvas({
			id: "help_menu",
			width: w,
			height: h,
			left: (_screenX1 - w - screenBorder),
			top: (_screenY1 - bitmapY * 3.2),
			border: border,
			scale: _scale
		});
		icon.setBitmap(_bitmap);
		icon.setAlpha(0);
	}

	this.enable = function ()
	{
		if (enabled) return;
		enabled = 1;
		disableMouseHandler();
		enableMouseHandler();
		icon.setAlpha(1);
	};

	this.disable = function (hidden)
	{
		disableMouseHandler();
		icon.setAlpha(hidden ? 0 : 1);
		enabled = 0;
	};

	function enableMouseHandler()
	{
		icon.enablePointer({ over: mouseOver, out: mouseOut, click: mouseClick });
	}

	function disableMouseHandler()
	{
		icon.disablePointer();
		icon.setCursor("default");
		icon.setHovered(false);
	}

	function mouseOver()
	{
		if (gameState == GAME_PAUSE || (gameState != GAME_START && gameState != GAME_RUNNING && playMode != PLAY_EDIT)) return;

		icon.setCursor("pointer");
		icon.setHovered(true);
	}

	function mouseOut()
	{
		icon.setCursor("default");
		icon.setHovered(false);
	}

	function mouseClick()
	{
		if (gameState == GAME_PAUSE || (gameState != GAME_START && gameState != GAME_RUNNING && playMode != PLAY_EDIT)) return;
		saveState();
		helpMenu(restoreState);
		mouseOut();
	}

	function saveState()
	{
		saveStateObj = saveKeyHandler(noKeyDown);
		gamePause();
		if (playMode == PLAY_EDIT) {
			if (editLevelModified()) saveTestState();
			stopEditInput();
		} else {
			stopPlayTicker();
			stopAllSpriteObj();
		}
		self.disable();
	}

	function restoreState()
	{
		restoreKeyHandler(saveStateObj);
		if (playMode == PLAY_EDIT) {
			startEditInput();
		} else {
			startAllSpriteObj();
			startPlayTicker();
		}
		gameResume();
		self.enable();
	}	
	init();

}

function themeIconClass( _screenX1, _screenY1, _scale, _themeBitmapApple2, _themeBitmapC64)
{
	var border = 4 * _scale;
	var nat = iconBitmapNaturalSize(_themeBitmapApple2);
	var bitmapX = nat.width * _scale;
	var bitmapY = nat.height * _scale;
	var icon;
	var self = this;
	var enabled = 0;

	init();

	function init()
	{
		var w = bitmapX + border * 2;
		var h = bitmapY + border * 2;
		icon = createIconCanvas({
			id: "theme_menu",
			width: w,
			height: h,
			left: (_screenX1 - w - screenBorder),
			top: (_screenY1 - bitmapY * 1.5),
			border: border,
			scale: _scale,
			baseFill: backgroundColor,
			hoverFill: null
		});
		icon.setAlpha(0);
		updateThemeImage(0);
	}

	this.enable = function ()
	{
		if (enabled) return;
		enabled = 1;
		disableMouseHandler();
		enableMouseHandler();
		icon.setAlpha(1);
	};

	this.disable = function (hidden)
	{
		disableMouseHandler();
		icon.setAlpha(hidden ? 0 : 1);
		enabled = 0;
	};

	function enableMouseHandler()
	{
		icon.enablePointer({ over: mouseOver, out: mouseOut, click: mouseClick });
	}

	function disableMouseHandler()
	{
		icon.disablePointer();
		icon.setCursor("default");
	}

	function updateThemeImage(showTips)
	{
		if (curTheme == THEME_APPLE2) {
			icon.setBitmap(_themeBitmapApple2);
		} else {
			icon.setBitmap(_themeBitmapC64);
		}
	}

	function mouseOver()
	{
		if (gameState == GAME_PAUSE || (gameState == GAME_WAITING && playMode != PLAY_EDIT)) return;
		icon.setCursor("pointer");
	}

	function mouseOut()
	{
		icon.setCursor("default");
	}

	function mouseClick()
	{
		if(gameState == GAME_PAUSE || (gameState == GAME_WAITING && playMode != PLAY_EDIT)) return;
		if (themeSwitchPending) return;

		var nextTheme = (curTheme == THEME_APPLE2 ? THEME_C64 : THEME_APPLE2);

		function finishSwitch()
		{
			themeSwitchPending = 0;
			curTheme = nextTheme;

			saveState();

			soundStop(soundDig);
			soundStop(soundFall);

			themeDataReset(1);
			updateThemeImage(1);
			themeColorIconUpdate();

			if (playMode == PLAY_EDIT) {
				startEditMode();
			} else {
				changeThemeScreen();
			}
		}

		if (isThemeAssetsLoaded(nextTheme)) {
			finishSwitch();
			return;
		}

		themeSwitchPending = 1;
		showTipsText("LOADING THEME...", 0);
		ensureThemeLoaded(nextTheme, function () {
			showTipsText("", 50);
			finishSwitch();
		});
	}

	function saveState()
	{
		setThemeMode(curTheme);
		if (playMode == PLAY_EDIT) {
			if (editLevelModified()) saveTestState();
			stopEditInput();
		}
	}
}

function themeColorIconUpdate()
{
	themeColorObj.themeChange();
}

// For EDIT mode
function pasteIconClass( _screenX1, _screenY1, _scale, _bitmap)
{
	var border = 4 * _scale;
	var nat = iconBitmapNaturalSize(_bitmap);
	var bitmapX = nat.width * _scale;
	var bitmapY = nat.height * _scale;
	var icon;
	var self = this;
	var enabled = 0;

	init();

	function init()
	{
		var w = bitmapX + border * 2;
		var h = bitmapY + border * 2;
		icon = createIconCanvas({
			id: "paste_icon",
			width: w,
			height: h,
			left: (_screenX1 - w - screenBorder),
			top: (h * 2 + bitmapY * 3 / 2) | 0,
			border: border,
			scale: _scale
		});
		icon.setBitmap(_bitmap);
		icon.setAlpha(0);
	}

	this.enable = function ()
	{
		if (enabled) return;

		enabled = 1;
		disableMouseHandler();
		enableMouseHandler();
		icon.bringToFront();
		icon.setAlpha(1);
	};

	this.disable = function ()
	{
		if (!enabled) return;

		disableMouseHandler();
		icon.setAlpha(0);
		enabled = 0;
	};

	function enableMouseHandler()
	{
		icon.enablePointer({ over: mouseOver, out: mouseOut, click: mouseClick });
	}

	function disableMouseHandler()
	{
		icon.disablePointer();
		icon.setCursor("default");
		icon.setHovered(false);
	}

	function mouseOver()
	{
		if (playMode != PLAY_EDIT) return;

		icon.setCursor("pointer");
		icon.setHovered(true);
	}

	function mouseOut()
	{
		icon.setCursor("default");
		icon.setHovered(false);
	}

	function mouseClick()
	{
		if (playMode != PLAY_EDIT) return;
		mouseOut();
		editPasteMap();
	}
}

//======================================
// BEGIN: Change Theme Screen real time
//======================================

function changeThemeScreen()
{
	rebuildMap();
	
	//Change runner theme
	runner.sprite.spriteSheet = runnerData;
	
	//change guard theme
	for(var i = 0; i < guardCount; i++) {
		if(redhatMode && guard[i].hasGold > 0)
			guard[i].sprite.spriteSheet = redhatData;
		else
			guard[i].sprite.spriteSheet = guardData;
	}
	
	//change holeObj theme
	holeObj.sprite.spriteSheet = holeData;
	
	//change fillHoleObj theme
	for(var i = 0; i < fillHoleObj.length; i++) {
		fillHoleObj[i].spriteSheet = holeData;
	}
	
	moveSprite2Top();
	
	clearGround();
	clearInfo();
	initInfoVariable();
	buildGroundInfo();
}

function rebuildMap() 
{
	var curTile;
	
	for(var x = 0; x < NO_OF_TILES_X; x++) {
		for(var y = 0; y < NO_OF_TILES_Y; y++) {
			switch(map[x][y].base) {
			default:		
			case EMPTY_T: //empty		
				continue;
			case BLOCK_T: //Normal Brick		
				curTile = getThemeBitmap("brick");		
				if(map[x][y].bitmap.alpha < 1) curTile.set({alpha:0}); //hide brick digging
				break;	
			case SOLID_T: //Solid Brick		
				curTile = getThemeBitmap("solid");		
				break;	
			case LADDR_T: //Ladder
				curTile = getThemeBitmap("ladder");
				break;	
			case BAR_T: //Line of rope
				curTile = getThemeBitmap("rope");
				break;	
			case TRAP_T: //False brick
				curTile = getThemeBitmap("brick");
				if(map[x][y].bitmap.alpha < 1) curTile.set({alpha:0.5}); //show trap tile
				break;
			case HLADR_T: //Ladder appears at end of level
				curTile = getThemeBitmap("ladder");
				curTile.set({alpha:0});	//hide the laddr
				break;
			case GOLD_T: //Gold
				curTile = getThemeBitmap("gold");
				break;
			}
			mainStage.removeChild(map[x][y].bitmap); //remove old
			curTile.setTransform(x * tileWScale, y * tileHScale, tileScale, tileScale); //x,y, scaleX, scaleY
			mainStage.addChild(curTile);  //add new
			map[x][y].bitmap = curTile;   //replace bitmap
		}
	}
}

function clearGround()
{
	for (var i = 0; i < groundTile.length; i++)
		mainStage.removeChild(groundTile[i]);
}

function clearInfo()
{
	var i;

	if(playMode == PLAY_CLASSIC || playMode == PLAY_AUTO || playMode == PLAY_DEMO) {
		for(i = 0; i < scoreTxt.length; i++) mainStage.removeChild(scoreTxt[i]);
		for(i = 0; i < scoreTile.length; i++) mainStage.removeChild(scoreTile[i]);

		if(playMode == PLAY_DEMO) {
			for(i = 0; i < demoTxt.length; i++) mainStage.removeChild(demoTxt[i]);
		} else {
			for(i = 0; i < lifeTxt.length; i++) mainStage.removeChild(lifeTxt[i]);
			for(i = 0; i < lifeTile.length; i++) mainStage.removeChild(lifeTile[i]);
		}
	} else { //PLAY_MODERN, PLAY_DEMO_ONCE
		for(i = 0; i < goldTxt.length; i++) mainStage.removeChild(goldTxt[i]);
		for(i = 0; i < goldTile.length; i++) mainStage.removeChild(goldTile[i]);

		for(i = 0; i < guardTxt.length; i++) mainStage.removeChild(guardTxt[i]);
		for(i = 0; i < guardTile.length; i++) mainStage.removeChild(guardTile[i]);

		for(i = 0; i < timeTxt.length; i++) mainStage.removeChild(timeTxt[i]);
		for(i = 0; i < timeTile.length; i++) mainStage.removeChild(timeTile[i]);
	}
	
	for(i = 0; i < levelTxt.length; i++) mainStage.removeChild(levelTxt[i]);
	for(i = 0; i < levelTile.length; i++) mainStage.removeChild(levelTile[i]);	
}

//======================================
// END: Change Theme Screen real time
//======================================