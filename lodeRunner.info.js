var classicInfo = [
	{type: 'TITLE', contain: " Classic Lode Runner " },
	{type: 'TEXT' , contain: "Release year : 1983, 1984"},
	{type: 'TEXT' , contain: "Platform : APPLE-II, Commodore 64, IBM PC, NES ..."},
	{type: 'TEXT' , contain: "Publisher : Br\u00F8derbund & Ariolasoft" }, //Brøderbund
	{type: 'TEXT' , contain: "Developer : Douglas E. Smith" },
	{type: 'TEXT' , contain: "Difficulty : \u2605 \u2605 \u2605" } //★ ★ ★
];

//ref: http://www.gb64.com/game.php?id=5906&d=42
var proInfo = [
	{type: 'TITLE', contain: "    Professional Lode Runner    " },
	{type: 'TEXT' , contain: "Release year : 1984, 1985"},
	{type: 'TEXT' , contain: "Platform : Commodore 64"},
	{type: 'TEXT' , contain: "Publisher : DodoSoft & AlphaSoft" },
	{type: 'TEXT' , contain: "Developer : Unknown" },
	{type: 'TEXT' , contain: "Difficulty : \u2605 \u2605 \u2605 \u2605" } //★ ★ ★ ★
];

//ref:http://www.vizzed.com/play/revenge-of-lode-runner-appleii-online-apple-ii-6223-game
var revengeInfo = [
	{type: 'TITLE', contain: "    Revenge of Lode Runner    " },
	{type: 'TEXT' , contain: "Release year : 1985, 1986"},
	{type: 'TEXT' , contain: "Platform : APPLE-II"},
	{type: 'TEXT' , contain: "Publisher : Br\u00F8derbund" }, //Brøderbund
	{type: 'TEXT' , contain: "Developer : Mad Man" },
	{type: 'TEXT' , contain: "Difficulty : \u2605 \u2605 \u2605 \u2605" } //★ ★ ★ ★
];

var fanBookInfo = [
	{type: 'TITLE', contain: " Lode Runner Fan Book " },
	{type: 'TEXT' , contain: 'From : "Apple Lode Runner - The Remake 2.0"'},
	{type: 'TEXT' , contain: "Platform : Microsoft Windows"},
	{type: 'TEXT' , contain: "Publisher : Spoonbill Software" },
	{type: 'TEXT' , contain: 'Developer : Custom levels'},
	{type: 'TEXT_LINK' , text: "URL : ",
	 				     textLink: "https://www.omninet.net.au/~irhumph/loderunner.htm",
	 				     url: "https://www.omninet.net.au/~irhumph/loderunner.htm"
	},
	{type: 'TEXT' , contain: "Difficulty : \u2605 \u2605 \u2605 \u2605 \u2605" } //★ ★ ★ ★ ★
];

var championInfo = [
	{type: 'TITLE', contain: " Championship Lode Runner " },
	{type: 'TEXT' , contain: "Release year : 1984, 1985"},
	{type: 'TEXT' , contain: "Platform : APPLE-II, Commodore 64, NES ..."},
	{type: 'TEXT' , contain: "Publisher : Br\u00F8derbund & Hudson Soft" }, //Brøderbund
	{type: 'TEXT' , contain: "Developer : Douglas E. Smith" },
	{type: 'TEXT' , contain: "Difficulty : \u2605 \u2605 \u2605 \u2605 \u2605" } //★ ★ ★ ★ ★
];

//=========================================================================================

var editInfo = [
	{type: 'TITLE', contain: "Edit Custom Level"},
	{type: 'TEXT' , contain: "NEW : New or clear editing level"},
	{type: 'TEXT' , contain: "LOAD : Load exists level for customization"},
	{type: 'TEXT' , contain: "TEST : Test editing level" },
	{type: 'TEXT' , contain: "SAVE : Save current level" }
	
];

var testInfo = [
	{type: 'TITLE', contain: "Test Custom Level"},
	{type: 'TEXT' , contain: "If test success, players can save it. "}
];

var customInfo = [
	{type: 'TITLE', contain: "Custom Levels"},
	{type: 'TEXT' , contain: "Players can create new levels or edit exists levels."}
];

var demoHelp = [
	{type: 'TITLE', contain: " Demo Mode "},
	{type: 'TEXT' , contain: "     Demo data collected from players," },
	{type: 'TEXT' , contain: " Only demo the fastest passed levels or" },
	{type: 'TEXT' , contain: "Recently passed levels of current player." }
];

function createDemoInfo()
{
	var titleName = playDataToTitleName(playData);
	var player = playerDemoData[curLevel-1].player;
	
	if(player == "") player = "Unknown";
	
	var demoInfo = [
		{type: 'TITLE', contain: "    " + playDataToTitleName(playData)+ "    " },
		{type: 'TEXT' , contain: "Demo level : " + curLevel},
		{type: 'TEXT' , contain: "Player : " + player },
		{type: 'TEXT_flagID_MSG' , text: "Location :  ",  
		                           flagId: playerDemoData[curLevel-1].cId.toLowerCase(),
		                           msg: " " + playerDemoData[curLevel-1].location
		},
		{type: 'TEXT' , contain: "Date : " + playerDemoData[curLevel-1].date+ " (" + playerDemoData[curLevel-1].ai+")" }
	];
	
	return demoInfo;
}

function infoMenu(callbackFun, args)
{
	var infoMsg = null;
	
	switch(playMode) {
	case PLAY_CLASSIC:
	case PLAY_MODERN:
		if(playData == PLAY_DATA_USERDEF) {
			infoMsg = customInfo;
		} else {
			infoMsg = getPlayVerInfo(playData);	
		}
		break;	
	case PLAY_DEMO:
	case PLAY_DEMO_ONCE:
		infoMsg = createDemoInfo();	
		break;
	case PLAY_EDIT:
		infoMsg = editInfo;
		break;
	case PLAY_TEST:
		infoMsg = testInfo;
		break;
	}
	 
	if(infoMsg) infoObj.showInfo(infoMsg, callbackFun, args);
	else {
		if(callbackFun) callbackFun(args);
		error("Error:  playMode = " + playMode);
	}
}

function infoMenuClass(_stageUnused, _scale)
{
	var INFO_BORDER_SIZE  = 24 * _scale;
	var INFO_BORDER_HALF  = INFO_BORDER_SIZE / 2;
		
	var TITLE_TEXT_SIZE = 40 * _scale;
	var TITLE_TEXT_COLOR = "white";
	var TITLE_TEXT_SHADOW_COLOR = "#FF0";

	var ITEM_TEXT_SIZE = 32 * _scale;
	var ITEM_TEXT_COLOR = "yellow";
	
	var FLAG_SCALE = _scale * 5/4;
	var FLAG_MSG_SIZE = 28 * _scale;
	var FLAG_MSG_COLOR = "white";
	var FLAG_FRAME = 32;
	
	var TOP_BORDER_SIZE = TITLE_TEXT_SIZE/2 | 0;
	var BOTTOM_BORDER_SIZE = ITEM_TEXT_SIZE/ 2 | 0;
	var BORDER_WIDTH =  ITEM_TEXT_SIZE;
	
	var CLOSE_BOX_SIZE = 12 * _scale + 2;

	var canvas = null;
	var ctx = null;
	var measureCanvas = document.createElement("canvas");
	var measureCtx = measureCanvas.getContext("2d");

	var rows = [];
	var hitRegions = [];
	var closeHover = false;
	var flagHoverIdx = -1;
	var linkHoverIdx = -1;

	var menuX, menuY, startX, startY;
	var screenW, screenH;
	
	var callBackFun, callBackArgs;
	var saveStateObj;
	var listening = false;

	function measureText(text, font)
	{
		measureCtx.font = font;
		var m = measureCtx.measureText(text);
		var h = parseFloat(font) || 16;
		return { width: m.width, height: h };
	}

	function flagFrameIndex(flagId)
	{
		if (flagId && (flagId in countryId)) return countryId[flagId];
		if ("unknown" in countryId) return countryId["unknown"];
		return 0;
	}

	function flagSheetMetrics()
	{
		var img = preload.getResult("flag");
		var cols = Math.max(1, (img.naturalWidth || img.width) / FLAG_FRAME | 0);
		return { img: img, cols: cols };
	}

	function drawRoundRect(c, x, y, w, h, r)
	{
		if (c.roundRect) {
			c.beginPath();
			c.roundRect(x, y, w, h, r);
			c.fill();
			return;
		}
		c.beginPath();
		c.moveTo(x + r, y);
		c.arcTo(x + w, y, x + w, y + h, r);
		c.arcTo(x + w, y + h, x, y + h, r);
		c.arcTo(x, y + h, x, y, r);
		c.arcTo(x, y, x + w, y, r);
		c.closePath();
		c.fill();
	}

	function ensureCanvas()
	{
		var gameCanvas = document.getElementById("canvas");
		screenW = gameCanvas.width;
		screenH = gameCanvas.height;
		if (!canvas) {
			canvas = document.createElement("canvas");
			canvas.id = "info_overlay";
			canvas.style.position = "absolute";
			ctx = canvas.getContext("2d");
		}
		canvas.width = screenW;
		canvas.height = screenH;
		canvas.style.left = gameCanvas.style.left || (gameCanvas.offsetLeft + "px");
		canvas.style.top = gameCanvas.style.top || (gameCanvas.offsetTop + "px");
		if (!canvas.parentNode) document.body.appendChild(canvas);
	}

	function layoutRows(infoList)
	{
		rows = [];
		menuX = menuY = 0;
		var maxTextWidth = 0;
		var sheet = flagSheetMetrics();

		for (var i = 0; i < infoList.length; i++) {
			var item = infoList[i];
			var row = { type: item.type };
			switch (item.type) {
			case "TITLE": {
				var font = "bold " + TITLE_TEXT_SIZE + "px Helvetica";
				var sz = measureText(item.contain, font);
				row.text = item.contain;
				row.font = font;
				row.width = sz.width;
				row.height = TITLE_TEXT_SIZE;
				menuY += (row.height * 3 / 2) | 0;
				break;
			}
			case "TEXT": {
				var fontT = "bold " + ITEM_TEXT_SIZE + "px Helvetica";
				var szT = measureText(item.contain, fontT);
				row.text = item.contain;
				row.font = fontT;
				row.width = szT.width;
				row.height = ITEM_TEXT_SIZE;
				menuY += (row.height * 3 / 2) | 0;
				break;
			}
			case "TEXT_flagID_MSG": {
				var fontF = "bold " + ITEM_TEXT_SIZE + "px Helvetica";
				var fontM = "bold " + FLAG_MSG_SIZE + "px Helvetica";
				var labelSz = measureText(item.text, fontF);
				var msgSz = measureText(item.msg, fontM);
				var flagW = FLAG_FRAME * FLAG_SCALE;
				var flagH = FLAG_FRAME * FLAG_SCALE;
				row.label = item.text;
				row.labelFont = fontF;
				row.textWidth = labelSz.width;
				row.textHeight = ITEM_TEXT_SIZE;
				row.flagId = item.flagId;
				row.flagFrame = flagFrameIndex(item.flagId);
				row.flagWidth = flagW;
				row.flagHeight = flagH;
				row.msg = item.msg;
				row.msgFont = fontM;
				row.msgWidth = msgSz.width;
				row.msgHeight = FLAG_MSG_SIZE;
				row.width = row.textWidth + row.flagWidth + row.msgWidth;
				menuY += (row.textHeight * 3 / 2) | 0;
				break;
			}
			case "TEXT_LINK": {
				var fontL = "bold " + ITEM_TEXT_SIZE + "px Helvetica";
				var prefixSz = measureText(item.text, fontL);
				var linkSz = measureText(item.textLink, fontL);
				row.label = item.text;
				row.linkText = item.textLink;
				row.url = item.url;
				row.font = fontL;
				row.textWidth = prefixSz.width;
				row.textHeight = ITEM_TEXT_SIZE;
				row.linkWidth = linkSz.width;
				row.width = row.textWidth + row.linkWidth;
				menuY += (row.textHeight * 3 / 2) | 0;
				break;
			}
			default:
				error("Error: type don't support, type = " + item.type);
				continue;
			}
			if (maxTextWidth < row.width) maxTextWidth = row.width;
			rows.push(row);
		}

		menuX = maxTextWidth + BORDER_WIDTH * 2;
		menuY += (TOP_BORDER_SIZE + BOTTOM_BORDER_SIZE);
		startX = (screenW - menuX) / 2 | 0;
		startY = (screenH - menuY) / 2 | 0;
		if (startX < 0) startX = 0;
		if (startY < 0) startY = 0;
	}

	function buildHitRegions()
	{
		hitRegions = [];
		var tmpY = startY;
		for (var i = 0; i < rows.length; i++) {
			var row = rows[i];
			switch (row.type) {
			case "TITLE":
				tmpY += (row.height / 2) | 0;
				row.x = startX + (menuX - row.width) / 2 | 0;
				row.y = tmpY;
				tmpY += row.height * 3 / 2 | 0;
				break;
			case "TEXT":
				row.x = startX + BORDER_WIDTH;
				row.y = tmpY;
				tmpY += row.height * 3 / 2 | 0;
				break;
			case "TEXT_flagID_MSG":
				row.x = startX + BORDER_WIDTH;
				row.y = tmpY;
				row.flagX = startX + BORDER_WIDTH + row.textWidth;
				row.flagY = tmpY + (row.textHeight - row.flagHeight) / 3;
				row.msgX = startX + BORDER_WIDTH + row.textWidth + row.flagWidth;
				row.msgY = tmpY + (row.textHeight - row.msgHeight);
				hitRegions.push({
					type: "flag",
					rowIdx: i,
					x: row.flagX,
					y: row.flagY,
					w: row.flagWidth,
					h: row.flagHeight
				});
				tmpY += row.textHeight * 3 / 2 | 0;
				break;
			case "TEXT_LINK":
				row.x = startX + BORDER_WIDTH;
				row.y = tmpY;
				row.linkX = startX + BORDER_WIDTH + row.textWidth;
				row.linkY = tmpY;
				hitRegions.push({
					type: "link",
					rowIdx: i,
					url: row.url,
					x: row.linkX,
					y: row.linkY,
					w: row.linkWidth,
					h: row.textHeight
				});
				tmpY += row.textHeight * 3 / 2 | 0;
				break;
			}
		}
		hitRegions.push({
			type: "close",
			x: startX + menuX - CLOSE_BOX_SIZE * 3 - CLOSE_BOX_SIZE / 2,
			y: startY + CLOSE_BOX_SIZE * 2 - CLOSE_BOX_SIZE / 2,
			w: CLOSE_BOX_SIZE * 2.5,
			h: CLOSE_BOX_SIZE * 2.5
		});
	}

	function redraw()
	{
		if (!ctx) return;
		ctx.clearRect(0, 0, screenW, screenH);

		ctx.globalAlpha = 0.3;
		ctx.fillStyle = "black";
		ctx.fillRect(0, 0, screenW, screenH);
		ctx.globalAlpha = 1;

		ctx.globalAlpha = 0.8;
		ctx.fillStyle = "#FF0";
		drawRoundRect(ctx, startX - INFO_BORDER_HALF, startY - INFO_BORDER_HALF,
			menuX + INFO_BORDER_SIZE, menuY + INFO_BORDER_SIZE, INFO_BORDER_HALF);
		ctx.globalAlpha = 0.6;
		ctx.fillStyle = "#190218";
		drawRoundRect(ctx, startX, startY, menuX, menuY, INFO_BORDER_HALF / 2);
		ctx.globalAlpha = 1;

		var sheet = flagSheetMetrics();
		for (var i = 0; i < rows.length; i++) {
			var row = rows[i];
			switch (row.type) {
			case "TITLE":
				ctx.font = row.font;
				ctx.fillStyle = TITLE_TEXT_COLOR;
				ctx.shadowColor = TITLE_TEXT_SHADOW_COLOR;
				ctx.shadowBlur = 2;
				ctx.textBaseline = "top";
				ctx.fillText(row.text, row.x, row.y);
				ctx.shadowBlur = 0;
				break;
			case "TEXT":
				ctx.font = row.font;
				ctx.fillStyle = ITEM_TEXT_COLOR;
				ctx.textBaseline = "top";
				ctx.fillText(row.text, row.x, row.y);
				break;
			case "TEXT_flagID_MSG":
				ctx.font = row.labelFont;
				ctx.fillStyle = ITEM_TEXT_COLOR;
				ctx.textBaseline = "top";
				ctx.fillText(row.label, row.x, row.y);
				if (sheet.img) {
					var fi = row.flagFrame | 0;
					var sx = (fi % sheet.cols) * FLAG_FRAME;
					var sy = (fi / sheet.cols | 0) * FLAG_FRAME;
					ctx.drawImage(sheet.img, sx, sy, FLAG_FRAME, FLAG_FRAME,
						row.flagX, row.flagY, row.flagWidth, row.flagHeight);
				}
				if (flagHoverIdx === i) {
					ctx.font = row.msgFont;
					ctx.fillStyle = FLAG_MSG_COLOR;
					ctx.fillText(row.msg, row.msgX, row.msgY);
				}
				break;
			case "TEXT_LINK":
				ctx.font = row.font;
				ctx.fillStyle = ITEM_TEXT_COLOR;
				ctx.textBaseline = "top";
				ctx.fillText(row.label, row.x, row.y);
				if (linkHoverIdx === i) {
					ctx.fillStyle = "#fff";
				}
				ctx.fillText(row.linkText, row.linkX, row.linkY);
				break;
			}
		}

		drawCloseIcon(closeHover);
	}

	function drawCloseIcon(mouseOver)
	{
		var cx = startX + menuX - CLOSE_BOX_SIZE * 3;
		var cy = startY + CLOSE_BOX_SIZE * 2;
		var alpha = mouseOver ? 0.6 : 0.01;
		var cycColor = mouseOver ? "red" : "gold";

		ctx.globalAlpha = alpha;
		ctx.fillStyle = cycColor;
		ctx.beginPath();
		ctx.arc(cx + CLOSE_BOX_SIZE / 2, cy + CLOSE_BOX_SIZE / 2, CLOSE_BOX_SIZE * 5 / 4, 0, Math.PI * 2);
		ctx.fill();
		ctx.globalAlpha = 1;

		ctx.strokeStyle = "white";
		ctx.lineWidth = CLOSE_BOX_SIZE / 4;
		ctx.beginPath();
		ctx.moveTo(cx, cy);
		ctx.lineTo(cx + CLOSE_BOX_SIZE, cy + CLOSE_BOX_SIZE);
		ctx.moveTo(cx + CLOSE_BOX_SIZE, cy);
		ctx.lineTo(cx, cy + CLOSE_BOX_SIZE);
		ctx.stroke();
	}

	function hitTest(mx, my)
	{
		for (var i = 0; i < hitRegions.length; i++) {
			var h = hitRegions[i];
			if (mx >= h.x && mx <= h.x + h.w && my >= h.y && my <= h.y + h.h) return h;
		}
		return null;
	}

	function canvasLocalXY(e)
	{
		var rect = canvas.getBoundingClientRect();
		var sx = canvas.width / rect.width;
		var sy = canvas.height / rect.height;
		return {
			x: (e.clientX - rect.left) * sx,
			y: (e.clientY - rect.top) * sy
		};
	}

	function onMove(e)
	{
		var p = canvasLocalXY(e);
		var hit = hitTest(p.x, p.y);
		var nextClose = hit && hit.type === "close";
		var nextFlag = (hit && hit.type === "flag") ? hit.rowIdx : -1;
		var nextLink = (hit && hit.type === "link") ? hit.rowIdx : -1;
		var cursor = (nextClose || nextLink || nextFlag >= 0) ? "pointer" : "default";
		if (canvas.style.cursor !== cursor) canvas.style.cursor = cursor;
		if (nextClose !== closeHover || nextFlag !== flagHoverIdx || nextLink !== linkHoverIdx) {
			closeHover = nextClose;
			flagHoverIdx = nextFlag;
			linkHoverIdx = nextLink;
			redraw();
		}
	}

	function onLeave()
	{
		if (closeHover || flagHoverIdx >= 0 || linkHoverIdx >= 0) {
			closeHover = false;
			flagHoverIdx = -1;
			linkHoverIdx = -1;
			redraw();
		}
		canvas.style.cursor = "default";
	}

	function onClick(e)
	{
		var p = canvasLocalXY(e);
		var hit = hitTest(p.x, p.y);
		if (!hit) return;
		if (hit.type === "close") {
			closeInfoMenu();
			return;
		}
		if (hit.type === "link" && hit.url) {
			window.open(hit.url).focus();
			canvas.style.cursor = "default";
		}
	}

	function enablePointer()
	{
		if (listening) return;
		canvas.addEventListener("mousemove", onMove);
		canvas.addEventListener("mouseleave", onLeave);
		canvas.addEventListener("click", onClick);
		listening = true;
	}

	function disablePointer()
	{
		if (!listening) return;
		canvas.removeEventListener("mousemove", onMove);
		canvas.removeEventListener("mouseleave", onLeave);
		canvas.removeEventListener("click", onClick);
		listening = false;
		canvas.style.cursor = "default";
	}

	this.showInfo = function(info, callback, args)
	{
		if (typeof args == "undefined") args = null;
		callBackFun = callback;
		callBackArgs = args;
		closeHover = false;
		flagHoverIdx = -1;
		linkHoverIdx = -1;

		ensureCanvas();
		layoutRows(info);
		buildHitRegions();
		redraw();
		enablePointer();

		saveStateObj = saveKeyHandler(InfoKeyDown);
	};

	function InfoKeyDown(event)
	{
		if (!event) { event = window.event; }
		if (event.keyCode == KEYCODE_ESC) {
			closeInfoMenu();
		}
		return false;
	}

	function closeInfoMenu()
	{
		disablePointer();
		if (canvas && canvas.parentNode) canvas.parentNode.removeChild(canvas);
		restoreKeyHandler(saveStateObj);
		if (callBackFun) setTimeout(function() { callBackFun(callBackArgs); }, 10);
	}
}
