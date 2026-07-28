var inputNameState = 0;

// Active in-game name-entry session abort. inputString / inputPlayerName install
// this; showCoverPage / startGame / re-entry call abortActiveNameInput() so the
// blink clock listener cannot leak across mode changes.
var cancelActiveNameInput = null;

function abortActiveNameInput()
{
	if(!cancelActiveNameInput) return;
	var fn = cancelActiveNameInput;
	cancelActiveNameInput = null;
	fn();
}

//=============================================================================
// Owned score surface: a z-ordered list of CanvasObjects painted onto the game
// canvas, replacing the CreateJS score Stage. No CreateJS Stage/Sprite/Shape;
// blink cursors ride the owned game clock (lodeRunner.clock.js).
//=============================================================================
function ScoreSurface()
{
	this.objs = [];
	this.ctx = canvas.getContext("2d");
}
ScoreSurface.prototype.add = function(obj) { this.objs.push(obj); return obj; };
ScoreSurface.prototype.remove = function(obj)
{
	var i = this.objs.indexOf(obj);
	if(i >= 0) this.objs.splice(i, 1);
};
ScoreSurface.prototype.moveToTop = function(obj)
{
	this.remove(obj);
	this.objs.push(obj);
};
ScoreSurface.prototype.clear = function() { this.objs.length = 0; };
ScoreSurface.prototype.present = function()
{
	var ctx = this.ctx;
	ctx.save();
	ctx.setTransform(1, 0, 0, 1, 0, 0);
	ctx.clearRect(0, 0, canvasBaseW, canvasBaseH);
	applyWorldTransform(ctx);
	for(var i = 0; i < this.objs.length; i++) this.objs[i].paint(ctx);
	ctx.restore();
};

//owned glyph run over the shared text atlas; drop-in for hiscore's drawText use
//(returns one CanvasGlyph, positioned; caller adds it to a surface/overlay)
function makeGlyphText(x, y, str, numberType)
{
	var g = new CanvasGlyph(textAtlas);
	g.setText(str, numberType);
	g.x = x;
	g.y = y;
	g.scaleX = g.scaleY = 1;
	return g;
}

function showScoreTable(_playData, _curScoreInfo, _callbackFun, _waitTime, _forceShow)
{
	var hiScoreInfo;
	var surface;
	var titleText;
	var recordId = -1;
	var savedKeyDownHander;
	var timeOutHandler = null;
	var scoreTicker = null;

	init();
	
	function init()
	{
		var haveInfo = getHiScoreInfo();
		
		if(_curScoreInfo) {
			recordId = updateScoreInfo();
			if(recordId < 0) {
				if(_callbackFun) _callbackFun();
				return; //don't need update score
			}
		}
		
		// Attract always shows the board (even all zeros); elsewhere empty
		// storage still means "nothing to display".
		if(!haveInfo && !_curScoreInfo && !_forceShow) {
			if(_callbackFun) _callbackFun();
			return; //no score info don't need display 
		}
			
		surface = new ScoreSurface();
		setScoreBackground();
		drawHiScoreList();
		surface.present();
		if(recordId >= 0) {
			var winner = 0;
			if('w' in _curScoreInfo) winner = 1;
			inputHiScoreName(winner);
		} else {
			anyKeyHandler();
			if(typeof _waitTime == "undefined") _waitTime = 3500;
			timeOutHandler = setTimeout( function() { closeScoreTable(); }, _waitTime);
		}
	}
	
	function closeScoreTable()
	{
		removeScoreScreen();
		restoreKeyDownHandler();
		if(_callbackFun) _callbackFun();
	}
	
	function getHiScoreInfo()
	{
		var infoJSON = null, levelMap;
		var rc = 0;
		
		infoJSON = getStorage(STORAGE_HISCORE_INFO + _playData);
		
		if(infoJSON) {
			var infoObj = JSON.parse(infoJSON);
			hiScoreInfo = infoObj;
			rc = 1;
		} else {
			// no score
			hiScoreInfo = [];
			for(var i = 0; i < MAX_HISCORE_RECORD; i++) {
				hiScoreInfo[i] = {s:0 , n:"" , l: 0};
			}
		}
		return rc;
	}
	
	function setHiScoreInfo()
	{
		var infoJSON = JSON.stringify(hiScoreInfo);
		setStorage(STORAGE_HISCORE_INFO + _playData, infoJSON); 
	
	}

	function updateScoreInfo()
	{
		var addId = -1;
		
		if(_curScoreInfo.s <= 0) return addId; //don't save if scroe <= 0
		
		for(var i = 0; i < MAX_HISCORE_RECORD; i++) {
			_curScoreInfo.n = "";
			if(_curScoreInfo.s >= hiScoreInfo[i].s) {
				addId = i;
				hiScoreInfo.splice(i, 0, _curScoreInfo);
				hiScoreInfo.splice(MAX_HISCORE_RECORD, 1);
				setHiScoreInfo();
				break;
			}
		}
		return addId;
	}
	
	function removeScoreScreen()
	{
		if(scoreTicker) { removeClockListener(scoreTicker); scoreTicker = null; }
		surface.clear();
		//repaint the world underneath the (now empty) score surface
		stagePresent();
	}

	function setScoreBackground()
	{
		//full-screen black backdrop
		surface.add(new CanvasShape().fillRect("black", 0, 0, canvasBaseW, canvasBaseH));
	}
	
	function getNameStartPos(nameLength, itemId) 
	{
		var x = (3.75+(MAX_HISCORE_NAME_LENGTH-nameLength)/2)*tileW;
		var y = (itemId * 1.2 + 5) * tileH;
		
		return { x: x, y: y };
	}
	
	function drawHiScoreList()
	{
		var title = playDataToTitleName(_playData);
		var localHighScore = "LOCAL HIGH SCORES";

		//title
		surface.add(makeGlyphText((NO_OF_TILES_X-title.length)/2*tileW, 0*tileH, title));
		surface.add(makeGlyphText((NO_OF_TILES_X-localHighScore.length)/2*tileW, 1.5*tileH, localHighScore));
		surface.add(makeGlyphText(0.5*tileW, 3*tileH, "NO"));
		surface.add(makeGlyphText(7.75*tileW, 3*tileH, "NAME"));
		surface.add(makeGlyphText(15.75*tileW, 3*tileH, "LEVEL"));
		surface.add(makeGlyphText(22*tileW, 3*tileH, "SCORE"));

		//bar
		var groundImg = getThemeBitmapImage("ground");
		for(var x = 0; x < NO_OF_TILES_X; x++) {
			var barTile = new CanvasBitmap(groundImg);
			barTile.x = x * tileW;
			barTile.y = 4.5*tileH;
			barTile.scaleX = barTile.scaleY = 1;
			surface.add(barTile);
		}

		for(var i = 0; i < MAX_HISCORE_RECORD; i++) {
			var pos = getNameStartPos(hiScoreInfo[i].n.length, i);

			surface.add(makeGlyphText(0.25*tileW, pos.y, ("0"+(i+1)).slice(-2) + ".")); //no

			if(hiScoreInfo[i].s > 0) {
				if(hiScoreInfo[i].n.length > 0) {
					surface.add(makeGlyphText(pos.x, pos.y, hiScoreInfo[i].n, "D")); //name
				}
				surface.add(makeGlyphText(16.75*tileW, pos.y, ("00"+hiScoreInfo[i].l).slice(-3))); //level
				surface.add(makeGlyphText(21*tileW, pos.y, ("000000"+hiScoreInfo[i].s).slice(-7))); //score
			}
		}
	}
	
	function anyKeyHandler()
	{
		savedKeyDownHander = getKeyHandler();
		setKeyHandler(function(event) {
			if(!event){ event = window.event; }

			//if( event.keyCode == KEYCODE_ENTER) {
				clearTimeout(timeOutHandler);
				closeScoreTable();
			//}
		});
	}

	function restoreKeyDownHandler()
	{
		setKeyHandler(savedKeyDownHander);
	}			
	
	function inputHiScoreName(winner) 
	{
		var name, nameText;
		var curPos = 0;
		var savedKeyDownHander;
		var cursor;

		if(winner) endingMusicPlay(); //6/15/2015, play ending music for winner
		initInput();
		
		function initInput()
		{
			inputNameState = 1;
			curPos = playerName.length;
			name = playerName.split(""); //string to array;
			nameText = null; //owned glyph run

			var pos = getNameStartPos(name.length, recordId);
			cursor = new CanvasGlyph(textAtlas);
			cursor.setAnim(GLYPH_FLASH.frames, GLYPH_FLASH.speed);
			cursor.x = pos.x - tileW/2;
			cursor.y = pos.y;
			cursor.scaleX = cursor.scaleY = 1;
			surface.add(cursor);

			//copyPlayerName();
			redrawName();
			changeKeyDownHandler();
			//tick-driven cursor blink + repaint (same owned-clock cadence as play)
			scoreTicker = scoreTick;
			addClockListener(scoreTick);
		}

		function scoreTick()
		{
			cursor.advance();
			surface.present();
		}
		
		function changeKeyDownHandler()
		{
			savedKeyDownHander = getKeyHandler();
			setKeyHandler(handleHiScoreName);
		}
		
		function inputFinish(async)
		{
			if(winner) endingMusicStop(); //6/15/2015, stop ending music
			
			//cut tail space
			for(var i = name.length-1; i >= 0; i--) {
				if(name[i] == " ") name.splice(i,1);
				else break;
			}
			
			var nameString = name.join(""); //array to string
			redrawName();
			
			//update name for score info  
			hiScoreInfo[recordId].n = nameString;
			setHiScoreInfo();

			if(nameString != playerName && nameString != "???") { //set and save playerName 
				playerName = nameString;
				setPlayerName(nameString);     
			}

			//remove cursor + stop the blink ticker; freeze final frame
			surface.remove(cursor);
			if(scoreTicker) { removeClockListener(scoreTicker); scoreTicker = null; }
			surface.present();

			setTimeout( function() { closeScoreTable(); }, 1500);

			inputNameState = 0;
		}

		function removeNameText()
		{
			if(nameText) surface.remove(nameText);
			nameText = null;
		}

		function redrawName()
		{
			var pos = getNameStartPos(name.length, recordId);
			removeNameText();
			nameText = makeGlyphText(pos.x, pos.y, name.join(""), "D");
			surface.add(nameText);

			//change cursor position
			if(name.length > 0) cursor.x = pos.x + curPos * tileW;
			else cursor.x = pos.x - tileW/2;

			//keep cursor on top
			surface.moveToTop(cursor);
		}
		
		function nextChar(charValue, nextMode)
		{
			if(typeof(charValue) == "undefined")charValue = " ";
			var code = charValue.charCodeAt(0);

			if(nextMode >=0) code++; else code--;
			
			if (code < 65 || code > 90) { //out of A-Z
				if(nextMode >=0) code = 65;
				else code= 90;
			}
			return String.fromCharCode(code); 
		}
		
		function handleHiScoreName(event)
		{
			if(!event){ event = window.event; } //cross browser issues exist
			
			var code = event.keyCode;
			
			if(curPos >= MAX_HISCORE_NAME_LENGTH && 
			   code != KEYCODE_BKSPACE && code != KEYCODE_LEFT && code != KEYCODE_ENTER) 
			{
				soundPlay("beep"); //wrong key code	
				return false;
			}

			switch(true) {
			case (code >= 48 && code <= 57): // 0 ~ 9
				if(curPos == 0) { soundPlay("beep"); break; } //first char except numbers
				name[curPos++] = String.fromCharCode(code);
				break;	
			case (code >=65 && code <= 90): // A ~ Z
			case (code >= 97 && code <= 122): //a ~ z
				if( code > 90) code -= 32;	
				name[curPos++] = String.fromCharCode(code);
				break;
			case (code == KEYCODE_DOT): //'.'		
				if(curPos == 0) { soundPlay("beep"); break;	} //first char except '.'
				name[curPos++] = ".";
				break;
			case (code == KEYCODE_DASH || code == KEYCODE_HYPHEN || code == KEYCODE_SUBTRACT): //'-'
				if(curPos == 0) { soundPlay("beep"); break;	} //first char except '-'
				name[curPos++] = "-";
				break;
			case (code == KEYCODE_SPACE): //space
				if(curPos == 0) { soundPlay("beep"); break;	} //first char except space
				name[curPos++] = " ";
				break;
			case (code == KEYCODE_BKSPACE): //backspace
				if(curPos == 0) break;
				name.splice(--curPos, 1);
				break;
			case (code == KEYCODE_LEFT): //LEFT
				if(curPos > 0) curPos--;	
				break;
			case (code == KEYCODE_RIGHT): //RIGHT
				if(curPos < name.length) curPos++;	
				break;
			case (code == KEYCODE_UP): //UP
				name[curPos] = nextChar(name[curPos], 1);
				break;
			case (code == KEYCODE_DOWN): //DOWN
				name[curPos] = nextChar(name[curPos], -1);
				break;
			case (code == KEYCODE_ENTER): //ENTER
				if(vaildPlayerName(name)) {
					restoreKeyDownHandler();  //avoid type "ENTER" twice
					inputFinish(true);	//async
				} else soundPlay("beep");	
				break;	
			default:
				//debug(code);	
				if(code > 32) soundPlay("beep"); //wrong key code	
				break;	
			}
			
			redrawName();
			return false;
		}
	}
}
 
function inputPlayerName(_stage, _callbackFun) 
{
	var constString = "PLAYER NAME:"
	var constSize = constString.length;
	var maxInputSize = MAX_HISCORE_NAME_LENGTH;
	var borderSize = 2;
	var totalSizeX = constSize + maxInputSize + borderSize + 1; //+1 flash 
	var totalSizeY = 3;
	
	var inputBoardX = (NO_OF_TILES_X - totalSizeX) / 2;
	var inputBoardY = (NO_OF_TILES_Y - totalSizeY) / 2;
	
	var inputStartX = inputBoardX + constSize + 1;
	var inputStartY = inputBoardY + 1;
	
	var background = new CanvasShape();
	var textBorder = new CanvasShape();
	var textBackground = new CanvasShape();

	background.fillRect("black", 0, 0, canvasBaseW, canvasBaseH);
	background.alpha = 0.2;

	var x = inputBoardX*tileW, y = inputBoardY*tileH;
	var w = totalSizeX*tileW, h = totalSizeY*tileH;
	var radius = (tileW/4)|0;
	textBorder.fillRoundRect("#f00", x, y, w, h, radius);
	textBorder.alpha = 0.6;
	textBorder.setShadow("#111", tileW/4, tileH/4, 10);

	x = (inputBoardX+0.5)*tileW; y = (inputBoardY+0.5)*tileH;
	w = (totalSizeX-1)*tileW; h = (totalSizeY-1)*tileH;
	textBackground.alpha = 0.5;
	textBackground.fillRoundRect("#111", x, y, w, h, radius/2);

	canvasOverlay.add(background);
	canvasOverlay.add(textBorder);
	canvasOverlay.add(textBackground);

	x = (inputBoardX+1)*tileW; y = (inputBoardY+1)*tileH;
	var constObj = makeGlyphText(x, y, constString, "D");
	canvasOverlay.add(constObj);

	x = inputStartX*tileW; y = inputStartY*tileH;
	inputString(_stage, maxInputSize, x, y, playerName, inputComplete);

	// Wrap the inputString abort so board chrome leaves with the blink ticker.
	var stringCancel = cancelActiveNameInput;
	cancelActiveNameInput = function() {
		if(stringCancel) stringCancel();
		removeNameBoard();
	};

	function removeNameBoard()
	{
		canvasOverlay.remove(constObj);
		canvasOverlay.remove(textBackground);
		canvasOverlay.remove(textBorder);
		canvasOverlay.remove(background);
	}

	function inputComplete(string)
	{
		setPlayerName(string);
		playerName = string;
		cancelActiveNameInput = null;
		removeNameBoard();
		stagePresent();
		_callbackFun();
	}
}

function vaildPlayerName(playerArray)
{
	var len = playerArray.length;

	//(1)skip tail space 
	for(var i = len-1; i >= 0; i--) {
		if(playerArray[i] == " ") len--;
		else break;
	}
		
	//(2) string length must > 1 and don't all same char 
	if(len <= 1) return 0; //too short
		
	for(var i = 1; i < len; i++) {
		if(playerArray[0] != playerArray[i]) return 1; //OK
	}
		
	return 0; //all same char
}	


function inputString(_stage, _maxSize, _startX, _startY, _defaultString, _callbackFun) 
{
	var inputText, inputObj;
	var curPos = 0;
	var savedKeyDownHander, hiScoreTicker;
	var cursor;
	var finished = 0;

	// One active session only — drop any stranded prior listener first.
	abortActiveNameInput();
	initInput();
		
	function initInput()
	{
		inputNameState = 1;

		curPos = _defaultString.length; // cursor start position
		inputText = _defaultString.split(""); //string to array
		inputObj = null; //owned glyph run

		cursor = new CanvasGlyph(textAtlas);
		cursor.setAnim(GLYPH_FLASH.frames, GLYPH_FLASH.speed);
		cursor.x = _startX;
		cursor.y = _startY;
		cursor.scaleX = cursor.scaleY = 1;
		canvasOverlay.add(cursor);

		drawString();
		changeKeyDownHandler();
		//tick-driven cursor blink; overlay-only paint so we never double-advance Stage sprites
		hiScoreTicker = inputTick;
		addClockListener(inputTick);
		cancelActiveNameInput = abortInput;
	}

	function inputTick()
	{
		cursor.advance();
		overlayPresent();
	}

	function drawString()
	{
		clearStringObj();
		inputObj = makeGlyphText(_startX, _startY, inputText.join(""), "D");
		canvasOverlay.add(inputObj);

		//change cursor position
		cursor.x = _startX + curPos * tileW;

		//keep cursor on top, then repaint the overlay (world underneath is static)
		canvasOverlay.remove(cursor);
		canvasOverlay.add(cursor);
		overlayPresent();
	}

	function clearStringObj()
	{
		if(inputObj) canvasOverlay.remove(inputObj);
		inputObj = null;
	}
	
	function changeKeyDownHandler()
	{
		savedKeyDownHander = getKeyHandler();
		setKeyHandler(handleStringInput);
	}
	
	function restoreKeyDownHandler()
	{
		setKeyHandler(savedKeyDownHander);
	}

	function stopBlink()
	{
		if(hiScoreTicker) {
			removeClockListener(hiScoreTicker);
			hiScoreTicker = null;
		}
	}

	// Teardown without invoking the success callback (cover / re-entry / startGame).
	function abortInput()
	{
		if(finished) return;
		finished = 1;
		stopBlink();
		restoreKeyDownHandler();
		clearStringObj();
		if(cursor) canvasOverlay.remove(cursor);
		inputNameState = 0;
		if(cancelActiveNameInput === abortInput) cancelActiveNameInput = null;
	}
	
	function nextChar(charValue, nextMode)
	{
		if(typeof(charValue) == "undefined") charValue = " ";
		var code = charValue.charCodeAt(0);
			
		if(nextMode >=0) code++; else code--;
			
		if (code < 65 || code > 90) { //out of A-Z
			if(nextMode >=0) code = 65;
			else code= 90;
		}
		return String.fromCharCode(code);
	}	
	
	function handleStringInput(event)
	{
		if(!event){ event = window.event; } //cross browser issues exist
			
		var code = event.keyCode;
			
		if(curPos >= _maxSize && code != KEYCODE_BKSPACE && code != KEYCODE_LEFT && code != KEYCODE_ENTER) 
		{
			soundPlay("beep"); //wrong key code	
			return false;
		}

		switch(true) {
		case (code >= 48 && code <= 57): // 0 ~ 9
			if(curPos == 0) { soundPlay("beep"); break; } //first char except numbers
			inputText[curPos++] = String.fromCharCode(code);
			break;	
		case (code >=65 && code <= 90): // A ~ Z
		case (code >= 97 && code <= 122): //a ~ z
			if( code > 90) code -= 32;	
			inputText[curPos++] = String.fromCharCode(code);
			break;
		case (code == KEYCODE_DOT): //'.'		
			if(curPos == 0) { soundPlay("beep"); break;	} //first char except '.'
			inputText[curPos++] = ".";
			break;
		case (code == KEYCODE_DASH || code == KEYCODE_HYPHEN || code == KEYCODE_SUBTRACT): //'-'
			if(curPos == 0) { soundPlay("beep"); break;	} //first char except '-'
			inputText[curPos++] = "-";
			break;
		case (code == KEYCODE_SPACE): //space
			if(curPos == 0) { soundPlay("beep"); break;	} //first char except space
			inputText[curPos++] = " ";
			break;
		case (code == KEYCODE_BKSPACE): //backspace
			if(curPos == 0) break;
			inputText.splice(--curPos, 1);
			break;
		case (code == KEYCODE_LEFT): //LEFT
			if(curPos > 0) curPos--;	
			break;
		case (code == KEYCODE_RIGHT): //RIGHT
			if(curPos < inputText.length) curPos++;	
			break;
		case (code == KEYCODE_UP): //UP
			inputText[curPos] = nextChar(inputText[curPos], 1);
			break;
		case (code == KEYCODE_DOWN): //DOWN
			inputText[curPos] = nextChar(inputText[curPos], -1);
			break;
		case (code == KEYCODE_ENTER): //ENTER
			if(vaildPlayerName(inputText)) { 
				inputFinish();
				return true;
			} else soundPlay("beep");	
			break;	
		default:
			//debug(code);	
			if(code > 32) soundPlay("beep"); //wrong key code	
			break;	
		}
			
		drawString();
		return false;
	}
	
	function inputFinish()
	{
		if(finished) return;
		finished = 1;
		cancelActiveNameInput = null;

		//cut tail space
		for(var i = inputText.length-1; i >= 0; i--) {
			if(inputText[i] == " ") inputText.splice(i,1);
			else break;
		}
		
		restoreKeyDownHandler();
		stopBlink();
		clearStringObj();
		canvasOverlay.remove(cursor);
		overlayPresent();

		_callbackFun(inputText.join(""));

		inputNameState = 0;
	}
}
