//=============================================================================
// Level selector: a DOM dialog with canvas thumbnails.
//
// Replaces the createjs selectDialog. DOM owns the structure -- tabs, grid,
// native scroll, hover and selected states -- which deletes the hand-rolled
// slider, drag tracking, and the click-vs-drag heuristic that came with it.
//
// Canvas still owns each cell's picture: renderLevelMapToCanvas draws through
// the same theme and recolor pipeline as the board, so thumbnails always match
// the live game. A CSS reproduction would drift from the real tile colors.
//=============================================================================

var levelSelect = (function() {
	var THUMB_SCALE = 0.16;      // thumbnail size relative to a full board

	var dialog, gridEl, titleEl;
	var levelData, activeLevel, activeFun, postFun;

	function el(tag, cls, html) {
		var e = document.createElement(tag);
		if(cls) e.className = cls;
		if(html != null) e.innerHTML = html;
		return e;
	}

	function build() {
		dialog = document.createElement("dialog");
		dialog.className = "lv-dialog";
		dialog.innerHTML =
			'<div class="lv-panel">' +
				'<div class="lv-head">' +
					'<select class="lv-version" aria-label="Game version"></select>' +
					'<button class="lv-close" aria-label="Close">&times;</button>' +
				'</div>' +
				'<div class="lv-grid"></div>' +
			'</div>';
		document.body.appendChild(dialog);

		gridEl  = dialog.querySelector(".lv-grid");
		titleEl = dialog.querySelector(".lv-version");

		// The title doubles as the version picker: switch here and the grid
		// repopulates for that version without leaving the dialog.
		titleEl.onchange = function(e) {
			gameSettings.setVersion(+e.target.value);
			reload();
		};

		dialog.querySelector(".lv-close").onclick = function(){ close(); };
		// click on the ::backdrop (the dialog itself, outside the panel) closes
		dialog.addEventListener("click", function(e){ if(e.target === dialog) close(); });
		// every close path (Esc, backdrop, .close()) converges on the native event
		dialog.addEventListener("close", function(){
			document.dispatchEvent(new CustomEvent("menu-close"));
			if(postFun) postFun();
		});
	}

	// Cleared markers differ by mode: Demo shows a check where a recording
	// exists, Training shows the score earned on that level.
	//
	// Both sources are loaded lazily by the game and are undefined until the
	// mode that owns them has been entered -- booting straight into Training
	// leaves modernScoreInfo unset. A missing source means "nothing cleared
	// yet", never a broken dialog.
	function clearedInfo(level) {
		if(playMode == PLAY_DEMO || playMode == PLAY_DEMO_ONCE)
			return (demoData && typeof demoData[level-1] != "undefined") ? {} : null;
		var score = modernScoreInfo ? modernScoreInfo[level-1] : -1;
		return (score >= 0) ? { score: score } : null;
	}

	// A caption strip above the art carries the level number and, once cleared,
	// the score. Nothing overlays the thumbnail, and a score IS the record of
	// completion -- so no separate check mark is needed.
	function makeCell(level) {
		var cell = el("button", "lv-cell");
		cell.dataset.level = level;
		if(level === activeLevel) cell.classList.add("current");

		var cleared = clearedInfo(level);
		if(cleared) cell.classList.add("cleared");

		var cap = el("span", "lv-cap");
		cap.appendChild(el("span", "lv-num", level));
		cap.appendChild(el("span", "lv-score", (cleared && cleared.score != null) ? cleared.score : ""));
		cell.appendChild(cap);

		var thumb = renderLevelMapToCanvas(levelData[level-1], THUMB_SCALE);
		thumb.className = "lv-thumb";
		cell.appendChild(thumb);

		cell.onclick = function(){ pick(level); };
		return cell;
	}

	// Every level in one scrolling grid. The old dialog paged 30 at a time
	// because its slider was hand-rolled; native scroll needs no paging.
	function renderGrid() {
		gridEl.innerHTML = "";
		if(!levelData.length) {                 // say so rather than show an empty box
			gridEl.appendChild(el("p", "lv-empty", "No levels in this version."));
			return;
		}
		for(var lv = 1; lv <= levelData.length; lv++) gridEl.appendChild(makeCell(lv));
		gridEl.scrollTop = 0;
	}

	// Placeholders while the version's level pack loads. The registry knows how
	// many levels a version has without loading anything, so the grid is the
	// right shape and size immediately and the real cells drop straight in.
	function renderSkeleton(count) {
		gridEl.innerHTML = "";
		for(var i = 1; i <= count; i++) {
			var cell = el("div", "lv-cell lv-skeleton");
			var cap = el("span", "lv-cap");
			cap.appendChild(el("span", "lv-num", i));
			cap.appendChild(el("span", "lv-score", ""));
			cell.appendChild(cap);
			cell.appendChild(el("span", "lv-thumb lv-thumb-blank"));
			gridEl.appendChild(cell);
		}
		gridEl.scrollTop = 0;
	}

	function pick(level) {
		var chosen = activeFun;
		close();                          // close first so the game resumes onto the pick
		if(chosen) chosen(level);
	}

	function close() {
		if(dialog.open) dialog.close();
	}

	function showCurrent() {
		var cur = gridEl.querySelector(".lv-cell.current");
		if(cur) cur.scrollIntoView({ block: "center" });
	}

	// The version picker doubles as the dialog title. Each option carries its
	// real playData id and level count, the way the old version dialog listed
	// them, so switching version never leaves the level grid.
	function renderVersions() {
		var opts = "";
		for(var i = 0; i < playVersionInfo.length; i++) {
			var v = playVersionInfo[i];
			opts += '<option value="' + v.id + '">' + v.name.trim() +
			        '  (' + v.levelCount + ' Levels)</option>';
		}
		var n = (typeof editLevels === "number" && editLevels > 0) ? editLevels : 0;
		opts += '<option value="' + PLAY_DATA_USERDEF + '">' + playDataNameUserDef +
		        (n ? '  (' + n + (n === 1 ? ' Level)' : ' Levels)') : '') + '</option>';
		titleEl.innerHTML = opts;
		titleEl.value = String(playData);
		if(titleEl.selectedIndex < 0) titleEl.selectedIndex = 0;
	}

	// Fill the grid for whatever version is current: real cells if the pack is
	// already in memory, otherwise a skeleton that the loader replaces.
	function populate() {
		renderVersions();
		var info = findPlayVersionInfo(playData);
		var loaded = isPlayVersionLoaded(playData);

		levelData = loaded ? currentLevels() : [];
		if(levelData.length) { renderGrid(); showCurrent(); return; }

		renderSkeleton(info ? info.levelCount : 0);
		ensurePlayVersionLoaded(playData, function() {
			if(!dialog.open) return;          // closed while we were loading
			initDemoData();                   // demoData drives the cleared markers
			levelData = currentLevels();
			renderVersions();                 // counts may resolve late too
			renderGrid();
			showCurrent();
		});
	}

	// levelData for the loaded version; custom levels live in their own array
	function currentLevels() {
		if(playData == PLAY_DATA_USERDEF) return editLevelData || [];
		return getPlayVerData(playData) || [];
	}

	// switch version from inside the dialog and repopulate in place
	function reload() {
		activeLevel = curLevel;
		populate();
	}

	// open(opts) -- opts: { current, onPick, onClose }
	// The dialog opens at once and fills in when the version's pack is ready.
	function open(opts) {
		if(!dialog) build();
		activeLevel = opts.current;
		activeFun = opts.onPick;
		postFun = opts.onClose;

		populate();
		dialog.showModal();
		document.dispatchEvent(new CustomEvent("menu-open"));
		showCurrent();
	}


	return { init: build, open: open };
})();
