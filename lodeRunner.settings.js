//=============================================================================
// Settings model + DOM settings panel.
//
// gameSettings is the single source of truth for user-facing settings (sound,
// theme, color, speed, repeat, gamepad). It reads current game state and exposes
// absolute setters that call the real game functions and notify listeners. The
// DOM panel binds to it; the legacy icon widgets route through the same model so
// the two UIs never desync.
//=============================================================================

// Interaction accent: hover, focus rings, links. All three are period monitor
// phosphors -- green and amber are what these machines actually glowed, gold is
// the game's own treasure color. Purely cosmetic and panel-only; nothing in the
// game reads it.
var ACCENTS = {
	green: { name: "Green", base: "#5f9e6e", bright: "#7fc48e" },
	gold:  { name: "Gold",  base: "#c8a63c", bright: "#e7c64a" },
	amber: { name: "Amber", base: "#c98a3c", bright: "#e0a95c" }
};
var ACCENT_DEFAULT = "gold";
var curAccent = ACCENT_DEFAULT;

// Drives the two custom properties the whole panel already keys off, so one
// write recolors every hover and focus ring at once.
function applyAccent(id)
{
	var a = ACCENTS[id] || ACCENTS[ACCENT_DEFAULT];
	var s = document.documentElement.style;
	s.setProperty("--ls-cyan", a.base);
	s.setProperty("--ls-cyan-bright", a.bright);
	curAccent = ACCENTS[id] ? id : ACCENT_DEFAULT;
}

function initAccent()
{
	var saved = getStorage(STORAGE_ACCENT);
	applyAccent(ACCENTS[saved] ? saved : ACCENT_DEFAULT);
}

var gameSettings = {
	_listeners: [],

	//subscribe to any settings change; fn(key, value)
	onChange: function(fn) { this._listeners.push(fn); },
	_notify: function(key, value) {
		// mainTick returns on GAME_PAUSE before it repaints, so a paused board
		// never redraws itself. Present here and changes show live under the
		// open menu: pick a color, watch the bricks change.
		stagePresent();
		for(var i = 0; i < this._listeners.length; i++) this._listeners[i](key, value);
	},

	//-------- read current game state (globals owned elsewhere) --------
	get: function(key) {
		switch(key) {
		case "sound":   //true = audible (demo mode has its own mute flag)
			return !((playMode == PLAY_DEMO || playMode == PLAY_DEMO_ONCE) ? demoSoundOff : soundOff);
		case "theme":   return curTheme;                  //THEME_APPLE2 | THEME_C64
		case "color":   return curColorId[curTheme];      //0..maxThemeColor-1
		case "speed":   return speed;                     //0..speedMode.length-1
		case "repeat":  return !!repeatAction;
		case "gamepad": return !!gamepadMode;
		case "accent":  return curAccent;                 //"green" | "gold" | "amber"
		//navigation state (which game is loaded / how it's being played)
		case "mode":    return playMode;                  //PLAY_CLASSIC | PLAY_MODERN | PLAY_DEMO | PLAY_EDIT | ...
		case "version": return playData;                  //1..5 game id, or PLAY_DATA_USERDEF
		}
		return undefined;
	},

	//-------- absolute setters (no-op when already at the value) --------

	//sound: on = audible. Cuts looping sfx on mute; unlocks audio on unmute.
	setSound: function(on) {
		var want = on ? 0 : 1;
		var inDemo = (playMode == PLAY_DEMO || playMode == PLAY_DEMO_ONCE);
		var cur = inDemo ? demoSoundOff : soundOff;
		if(cur === want) return;
		if(inDemo) demoSoundOff = want; else soundOff = want;
		if(want) { soundStop(soundDig); soundStop(soundFall); } //muting: cut looping sfx
		this._notify("sound", on);
	},

	//theme: THEME_APPLE2 | THEME_C64. Lazy-loads the other pack then recolors.
	setTheme: function(theme, done) {
		if(theme === curTheme || themeSwitchPending) { if(done) done(); return; }
		var self = this;
		themeSwitchPending = 1;
		ensureThemeLoaded(theme, function() {
			themeSwitchPending = 0;
			curTheme = theme;
			setThemeMode(curTheme);
			soundStop(soundDig); soundStop(soundFall);
			themeDataReset(1);
			if(playMode == PLAY_EDIT) startEditMode();
			else changeThemeScreen();
			self._notify("theme", theme);
			if(done) done();
		});
	},

	setAccent: function(id) {
		if(!ACCENTS[id] || id === curAccent) return;
		applyAccent(id);
		setStorage(STORAGE_ACCENT, id);
		this._notify("accent", id);
	},

	//tile color slot 0..maxThemeColor-1 for the active theme.
	setColor: function(id) {
		if(curColorId[curTheme] === id) return;
		themeColorChange(id); //recolor + rebuild + repaint (owns its own work)
		this._notify("color", id);
	},

	//speed index 0..speedMode.length-1 (absolute, unlike setSpeed's delta).
	setSpeed: function(idx) {
		idx = Math.max(0, Math.min(speedMode.length - 1, idx | 0));
		if(idx === speed) return;
		speed = idx;
		setClockFps(speedMode[speed]);
		this._notify("speed", speed);
	},

	setRepeat: function(on) {
		if(!!repeatAction === !!on) return;
		repeatAction = on ? 1 : 0;
		if(gameState != GAME_START) repeatActionPressed = 1;
		setRepeatAction();
		this._notify("repeat", on);
	},

	//gamepad on/off. Honors "not supported" like toggleGamepadMode.
	setGamepad: function(on) {
		if(on && !gamepadSupport()) { gamepadMode = 0; this._notify("gamepad", false); return; }
		if(!!gamepadMode === !!on) return;
		gamepadMode = on ? 1 : 0;
		if(gamepadMode) gamepadEnable(); else gamepadDisable();
		setGamepadMode();
		this._notify("gamepad", on);
	},

	//-------- navigation (launches gameplay; replaces the canvas game-menu) --------

	//Training on = practice any level (PLAY_MODERN); off = Challenge, from level
	//1 for score (PLAY_CLASSIC). Either way the current version relaunches.
	setMode: function(on) {
		var self = this;
		function done(){ self._notify("mode", playMode); }
		if(on) modernPlay(0, done); else classicPlay(0, done);
	},

	//switch the loaded game version (playData), then relaunch the current play mode
	//so the new version's levels load. Version and mode are coupled at launch.
	setVersion: function(playDataId) {
		if(playDataId === playData) return;
		playData = playDataId;
		this.setMode(playMode === PLAY_MODERN);       //classic/other -> challenge
		this._notify("version", playData);
	},

	//enter the level editor (minimal wire; the editor UI is a separate project)
	enterEditor: function() {
		editEdit(0, null);
		this._notify("mode", PLAY_EDIT);
	},

	//open the level picker for the current mode. Training/Demo only -- Challenge
	//starts at level 1 and progresses, so there is nothing to pick.
	chooseLevel: function() {
		var self = this;
		levelSelect.open({
			current: curLevel,
			onPick: function(level) {
				soundStop(soundDig); soundStop(soundFall);
				curLevel = level;
				if(playMode == PLAY_DEMO) setDemoInfo(); else setModernInfo();
				startGame();
				self._notify("level", level);
			}
		});
	}
};

//=============================================================================
// DOM settings panel. Built from real game data; controls bind to gameSettings.
// Coexists with the legacy icon strip for now.
//=============================================================================

var settingsPanel = (function() {
	var SPEED_LABELS = ["Very Slow", "Slow", "Normal", "Fast", "Very Fast"];
	var root, panel, body;

	function el(tag, cls, html) {
		var e = document.createElement(tag);
		if(cls) e.className = cls;
		if(html != null) e.innerHTML = html;
		return e;
	}

	//--- true rendered brick color for each preset slot of the active theme.
	//getThemeTileColor(0) resolves "original" to the sampled brick color, so
	//every swatch shows the actual color it produces in game.
	function swatchColors() {
		var n = (themeColor[curTheme] || []).length;
		var out = [];
		for(var i = 0; i < n; i++) out.push(getThemeTileColor(i));
		return out;
	}

	var toggleBtn, dialog;

	function build() {
		//the toggle is a peer of the game, always on screen; the dialog is a
		//native <dialog> (top layer, ::backdrop scrim, Esc + focus-trap free).
		toggleBtn = el("button", "ls-toggle");
		toggleBtn.setAttribute("aria-label", "Settings");
		toggleBtn.innerHTML = "<span></span><span></span><span></span>";
		// The toggle never holds focus. Clicking it focuses it, and closing the
		// dialog hands focus back to it -- either way the game would be left with
		// a focused button eating the keys meant for the board.
		toggleBtn.addEventListener("focus", function(){ focusGame(); });

		dialog = document.createElement("dialog");
		dialog.className = "ls-dialog";
		dialog.innerHTML =
			'<div class="ls-panel">' +
				'<div class="ls-head">' +
					'<button class="ls-back" aria-label="Back">&larr;</button>' +
					'<h2 class="ls-title"><b>LODE</b> RUNNER</h2>' +
				'</div>' +
				'<div class="ls-body">' + mainView() +
					(richOptions ? "" : '<div class="view-info"></div>') + '</div>' +
			'</div>';

		document.body.appendChild(toggleBtn);
		document.body.appendChild(dialog);
		root = dialog;                       //control/query root is the dialog
		panel = dialog.querySelector(".ls-panel");
		body = dialog.querySelector(".ls-body");
		wire();
	}

	// One dropdown row: the version name with its level count, plus an info
	// marker carrying that version's record. Both the marker and the count are
	// hidden in the closed control (see .ls-version selectedcontent) -- they
	// help you compare versions in the list, but once one is chosen the count
	// only makes the control wide.
	// Chrome/Edge render <option> children as real elements; elsewhere the
	// browser keeps only their text, which would spill every card into the
	// list. Same test the stylesheet uses -- markup and styling must agree.
	var richOptions = window.CSS && CSS.supports && CSS.supports("appearance", "base-select");

	function versionOption(id, name) {
		var count = playVersionLevelCount(id);
		var facts = richOptions ? playVersionFacts(id) : [];
		var card  = "";

		//custom levels are the user's own, so describe what they are rather
		//than inventing a publication record they do not have
		if(richOptions && id == PLAY_DATA_USERDEF)
			facts = [["Source", "Built by you in the level editor"],
			         ["Capacity", "Up to " + MAX_EDIT_LEVEL + " levels"],
			         ["Stored", "In this browser only"]];

		if(facts.length) {
			var rows = "";
			for(var i = 0; i < facts.length; i++) {
				var url = facts[i][2];
				var value = url
					? '<a class="vi-link" href="' + url + '" target="_blank" rel="noopener noreferrer">' +
					      facts[i][1] + '</a>'
					: facts[i][1];
				rows += '<span class="vi-k">' + facts[i][0] + '</span>' +
				        '<span class="vi-v">' + value + '</span>';
			}
			//popover puts the card in the top layer, so it escapes the panel's
			//overflow:hidden instead of being cut off at the 400px edge
			card = '<span class="vi">&#9432;<span class="vi-card" popover>' +
			           '<span class="vi-h">' + name + '</span>' +
			           '<span class="vi-rows">' + rows + '</span>' +
			       '</span></span>';
		}

		var levels = count ? '<span class="vi-count">' + playVersionCountText(count) + '</span>' : "";
		if(!richOptions)
			return '<option value="' + id + '">' +
			       name + (count ? "  " + playVersionCountText(count) : "") + '</option>';

		return '<option value="' + id + '">' + card +
		       '<span class="vi-label">' + name + '</span>' + levels + '</option>';
	}

	// Show a version's record beside its marker. The card is a popover, so it
	// has to be opened and placed here rather than by :hover -- top-layer
	// elements are out of flow and know nothing about the marker's position.
	function showVersionCard(marker) {
		var card = marker.querySelector(".vi-card");
		if(!card || card.matches(":popover-open")) return;

		card.showPopover();

		//offsets in em, so they track the card's type like its padding does
		var em = parseFloat(getComputedStyle(card).fontSize) || 14;
		var GAP = 2.1 * em, RISE = 0.7 * em, EDGE = 0.6 * em;

		//the card holds itself open while the pointer is inside it
		if(!card.dataset.wired) {
			card.dataset.wired = "1";
			card.addEventListener("mouseenter", function(){ clearTimeout(closeCardTimer); });
			card.addEventListener("mouseleave", function(){ card.hidePopover(); });
		}

		var m = marker.getBoundingClientRect();

		//Cap the card at the room actually available on the side it will use,
		//so a long value (the Fan Book URL) is never cropped by a fixed limit.
		var roomRight = window.innerWidth - (m.right + GAP) - EDGE;
		var roomLeft = m.left - GAP - EDGE;
		card.style.setProperty("--vi-room", Math.max(roomRight, roomLeft) + "px");

		var w = card.getBoundingClientRect().width;
		//prefer the free space right of the panel; fall back to the left edge
		var left = m.right + GAP;
		if(left + w > window.innerWidth - EDGE) left = Math.max(EDGE, m.left - GAP - w);

		var h = card.getBoundingClientRect().height;
		var top = Math.max(EDGE, Math.min(m.top - RISE, window.innerHeight - h - EDGE));

		card.style.left = left + "px";
		card.style.top = top + "px";
	}

	// Closing is deferred so the pointer can travel from the marker into the
	// card (to reach a link). Entering the card cancels the pending close.
	var closeCardTimer = null;

	function hideVersionCard(marker, delayed) {
		var card = marker.querySelector(".vi-card");
		if(!card || !card.matches(":popover-open")) return;

		clearTimeout(closeCardTimer);
		if(!delayed) { card.hidePopover(); return; }
		closeCardTimer = setTimeout(function(){
			if(!card.matches(":hover")) card.hidePopover();
		}, 260);
	}

	function mainView() {
		//version options from playVersionInfo so each carries its real playData id
		var versionOpts = "";
		for(var i = 0; i < playVersionInfo.length; i++)
			versionOpts += versionOption(playVersionInfo[i].id, playVersionInfo[i].name.trim());
		//Custom Levels is a selectable version too -- the editor switches to it, so
		//without an option here the dropdown goes blank and strands the user.
		versionOpts += versionOption(PLAY_DATA_USERDEF, playDataNameUserDef);

		//one swatch per preset slot; backgrounds are painted on open (refreshSwatches),
		//since the sampled "original" color is not ready until preload runs.
		var swatches = "";
		var slots = (themeColor[curTheme] || []).length;
		for(var c = 0; c < slots; c++) {
			var label = c === 0 ? "Original" : "Color " + c;
			swatches += '<button class="swatch" data-color="' + c + '" aria-label="' + label + '"></button>';
		}

		//accent swatches paint from the table directly -- unlike tile colors,
		//these are fixed and need no sampling
		var accentOpts = "";
		for(var key in ACCENTS) {
			accentOpts += '<button class="swatch" data-accent="' + key + '"' +
			              ' style="background:' + ACCENTS[key].bright + '"' +
			              ' aria-label="' + ACCENTS[key].name + '"></button>';
		}

		//Settings starts checked: resetting preferences is the common case, and
		//it is the only group you can lose without losing anything you earned.
		var clearChecks = "";
		for(var s = 0; s < STORAGE_GROUPS.length; s++) {
			var grp = STORAGE_GROUPS[s];
			clearChecks +=
				'<label class="clear-item">' +
					'<input type="checkbox" data-group="' + grp.id + '"' +
						(grp.id === "settings" ? " checked" : "") + '>' +
					'<span class="clear-name">' + grp.name +
						'<small>' + grp.note + '</small></span>' +
					'<span class="clear-count" data-count="' + grp.id + '"></span>' +
				'</label>';
		}

		return '<div class="view-main">' +
			'<div class="group"><p class="group-label">Game</p>' +
				'<div class="row"><span class="row-name">Version</span>' +
					//without per-option cards the info needs a route of its own
					(richOptions ? "" : '<div class="pick-group">' +
						'<button class="icon-btn ls-info" aria-label="About this version">&#9432;</button>') +
					'<select class="pick ls-version" aria-label="Game version">' +
						'<button><selectedcontent></selectedcontent></button>' +
						versionOpts +
					'</select>' +
					(richOptions ? "" : '</div>') +
				'</div>' +
				//Training on/off IS the mode: off is Challenge (level 1, for score),
				//on is practice at any level. Watching a demo is an action inside
				//training, not a third mode -- it lives on the board icons.
				'<div class="row"><span class="row-name">Training mode' +
					'<small>Practice any level</small></span>' +
					'<div class="seg ls-mode" role="group" aria-label="Training mode">' +
						'<button data-on="1">On</button><button data-on="0">Off</button>' +
					'</div>' +
				'</div>' +
				//Level: training only -- challenge starts at 1 and progresses
				'<div class="row"><span class="row-name">Level<small>Training only</small></span>' +
					'<button class="btn ls-level">Choose&hellip;</button>' +
				'</div>' +
				'<div class="row"><span class="row-name">Level Editor</span>' +
					'<button class="btn ls-editor">Open</button>' +
				'</div>' +
				'<div class="row"><span class="row-name">Custom levels' +
					'<small>Import or export a .lrwg file</small></span>' +
					'<div class="btn-pair" role="group" aria-label="Custom levels">' +
						'<button type="button" class="btn ls-import">Import</button>' +
						'<button type="button" class="btn ls-export">Export</button>' +
					'</div>' +
				'</div>' +
			'</div>' +
			'<div class="group"><p class="group-label">Display</p>' +
				'<div class="row"><span class="row-name">Theme</span>' +
					'<div class="seg ls-theme" role="group" aria-label="Theme">' +
						'<button data-theme="APPLE2">Apple II</button>' +
						'<button data-theme="C64">C64</button>' +
					'</div>' +
				'</div>' +
				'<div class="row"><span class="row-name">Color</span>' +
					'<div class="swatches ls-color" role="group" aria-label="Tile color">' + swatches + '</div>' +
				'</div>' +
				'<div class="row"><span class="row-name">Speed</span>' +
					'<div class="stepper ls-speed" role="group" aria-label="Speed">' +
						'<button class="ls-speed-down" aria-label="Slower">&minus;</button>' +
						'<span class="val ls-speed-val" aria-live="polite">Normal</span>' +
						'<button class="ls-speed-up" aria-label="Faster">+</button>' +
					'</div>' +
				'</div>' +
			'</div>' +
			'<div class="group"><p class="group-label">Controls</p>' +
				'<div class="row"><span class="row-name">Sound</span>' +
					'<div class="seg ls-sound" role="group" aria-label="Sound">' +
						'<button data-on="1">On</button><button data-on="0">Off</button></div></div>' +
				'<div class="row"><span class="row-name">Key repeat<small>Apple II vs NES feel</small></span>' +
					'<div class="seg ls-repeat" role="group" aria-label="Key repeat">' +
						'<button data-on="1">On</button><button data-on="0">Off</button></div></div>' +
				'<div class="row"><span class="row-name">Gamepad</span>' +
					'<div class="seg ls-gamepad" role="group" aria-label="Gamepad">' +
						'<button data-on="1">On</button><button data-on="0">Off</button></div></div>' +
			'</div>' +
			'<div class="group"><button class="btn ls-help" style="width:100%">Help</button></div>' +
			'<div class="group"><p class="group-label">Appearance</p>' +
				'<div class="row"><span class="row-name">Accent<small>Menu highlight color</small></span>' +
					'<div class="swatches accents ls-accent" role="group" aria-label="Accent color">' + accentOpts + '</div>' +
				'</div>' +
			'</div>' +
			'<div class="group"><p class="group-label">Testing</p>' +
				'<div class="row"><span class="row-name">Browser storage' +
					'<small>Reset to a blank slate</small></span>' +
					'<button class="btn ls-clear">Clear…</button>' +
				'</div>' +
				//the panel expands in place; nothing is destroyed until Erase
				'<div class="clear-panel ls-clear-panel" hidden>' +
					clearChecks +
					'<div class="clear-actions">' +
						'<button class="btn ls-clear-cancel">Cancel</button>' +
						'<button class="btn danger ls-clear-go">Erase</button>' +
					'</div>' +
					'<p class="clear-note ls-clear-note" role="status"></p>' +
				'</div>' +
			'</div>' +
		'</div>';
	}

	// Fallback for browsers without styleable options: the same record the
	// hover cards show, as a sub-view reached from the info button. Rendered
	// on open (not at build time) so it follows the selected version.
	function renderInfoView() {
		var host = root.querySelector(".view-info");
		if(!host) return;

		var id = gameSettings.get("version");
		var facts = playVersionFacts(id);
		if(id == PLAY_DATA_USERDEF)
			facts = [["Source", "Built by you in the level editor"],
			         ["Capacity", "Up to " + MAX_EDIT_LEVEL + " levels"],
			         ["Stored", "In this browser only"]];

		var v = findPlayVersionInfo(id);
		var name = v ? v.name.trim() : playDataNameUserDef;
		var count = playVersionLevelCount(id);
		if(count) facts = facts.concat([["Levels", count]]);

		var rows = "";
		for(var i = 0; i < facts.length; i++) {
			var url = facts[i][2];
			var value = url
				? '<a class="vi-link" href="' + url + '" target="_blank" rel="noopener noreferrer">' +
				      facts[i][1] + '</a>'
				: facts[i][1];
			rows += '<span class="vi-k">' + facts[i][0] + '</span>' +
			        '<span class="vi-v">' + value + '</span>';
		}
		host.innerHTML = '<p class="help-h">' + name + '</p>' +
		                 '<div class="vi-rows">' + rows + '</div>';
	}

	//--- open/close + sub-view routing ---
	var TITLES = { main: "<b>LODE</b> RUNNER", info: "VERSION" };
	var SUBVIEWS = ["info"];

	// The settings menu knows nothing about the game. It only opens and closes,
	// and announces that it did. The game (if it cares) listens for those
	// announcements and halts itself; see lodeRunner.game.js.
	function announce(name) {
		document.dispatchEvent(new CustomEvent(name));
	}
	function setMenuOpen(on) {
		if(on) {
			if(dialog.open) return;
			setView("main");
			dialog.showModal();               //top layer + ::backdrop scrim, native
			// Stop attract / restore last playMode before painting controls.
			// Syncing first would show Training Off while playMode is still
			// PLAY_AUTO, then menu-open restores PLAY_MODERN with no re-paint.
			announce("menu-open");
			syncFromModel();
		} else {
			dialog.close();                   // native "close" event -> menu-close
		}
	}
	function setView(view) {
		for(var i = 0; i < SUBVIEWS.length; i++) panel.classList.toggle(SUBVIEWS[i], view === SUBVIEWS[i]);
		dialog.querySelector(".ls-title").innerHTML = TITLES[view] || TITLES.main;
		body.scrollTop = 0;
	}
	function inSubView() {
		for(var i = 0; i < SUBVIEWS.length; i++) if(panel.classList.contains(SUBVIEWS[i])) return true;
		return false;
	}

	//--- reflect current game state into the controls (called on open) ---
	function pressOne(groupSel, matchFn) {
		var btns = root.querySelectorAll(groupSel + " button");
		for(var i = 0; i < btns.length; i++)
			btns[i].setAttribute("aria-pressed", matchFn(btns[i]) ? "true" : "false");
	}
	var clearing = 0;      //erase done, reload pending -- freeze the panel

	function checkedClearGroups() {
		var ids = [], boxes = root.querySelectorAll(".ls-clear-panel input[data-group]");
		for(var i = 0; i < boxes.length; i++)
			if(boxes[i].checked) ids.push(boxes[i].getAttribute("data-group"));
		return ids;
	}

	// Erase names its own scope, so the button always says what it will do, and
	// goes inert when nothing is ticked.
	function renderClearGo() {
		var ids = checkedClearGroups();
		var go = root.querySelector(".ls-clear-go");
		go.disabled = !ids.length;
		go.textContent = !ids.length ? "Erase"
		               : ids.length === STORAGE_GROUPS.length ? "Erase everything"
		               : "Erase " + ids.length + " of " + STORAGE_GROUPS.length;
	}

	// Counts come from storage each time it opens, so a group that holds
	// nothing says so instead of implying there is something to lose.
	function openClearPanel() {
		var counts = storageGroupCounts();
		var labels = root.querySelectorAll(".ls-clear-panel [data-count]");
		for(var i = 0; i < labels.length; i++) {
			var n = counts[labels[i].getAttribute("data-count")] || 0;
			labels[i].textContent = n ? n : "empty";
			labels[i].classList.toggle("none", !n);
		}
		var panel = root.querySelector(".ls-clear-panel");
		panel.hidden = false;
		root.querySelector(".ls-clear").hidden = true;
		renderClearGo();

		// It expands at the bottom of a scrolling body, so on a short window it
		// opens out of sight. Scroll its row into view -- anchoring the row
		// rather than the panel keeps the checkboxes visible when the panel is
		// taller than the remaining space.
		var row = panel.previousElementSibling || panel;
		var still = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
		row.scrollIntoView({ block: "start", behavior: still ? "auto" : "smooth" });
	}

	// Back to the resting state. Also called whenever the panel is reopened, so
	// a half-made decision never waits around for the next visit.
	function disarmClear() {
		var panel = root && root.querySelector(".ls-clear-panel");
		if(!panel || clearing) return;      //a reload is already on its way

		panel.hidden = true;
		root.querySelector(".ls-clear").hidden = false;
		var note = root.querySelector(".ls-clear-note");
		note.textContent = "";
		note.className = "clear-note ls-clear-note";

		var boxes = panel.querySelectorAll("input[data-group]");
		for(var i = 0; i < boxes.length; i++)
			boxes[i].checked = (boxes[i].getAttribute("data-group") === "settings");
	}
	function syncFromModel() {
		pressOne(".ls-theme",   function(b){ return b.getAttribute("data-theme") === gameSettings.get("theme"); });
		pressOne(".ls-sound",   function(b){ return (b.getAttribute("data-on") === "1") === gameSettings.get("sound"); });
		pressOne(".ls-repeat",  function(b){ return (b.getAttribute("data-on") === "1") === gameSettings.get("repeat"); });
		pressOne(".ls-gamepad", function(b){ return (b.getAttribute("data-on") === "1") === gameSettings.get("gamepad"); });
		pressOne(".ls-color",   function(b){ return +b.getAttribute("data-color") === gameSettings.get("color"); });
		pressOne(".ls-accent",  function(b){ return b.getAttribute("data-accent") === gameSettings.get("accent"); });
		disarmClear();
		refreshSwatches();
		renderSpeed();
		syncNav();
	}
	// Set a <select> to a value, but never leave it blank. Assigning a value with
	// no matching <option> silently sets selectedIndex = -1 and the control shows
	// nothing -- so it would lie about the game's state instead of reporting it.
	// Fall back to the first option and report what actually took.
	function selectValue(sel, value) {
		sel.value = String(value);
		if(sel.selectedIndex < 0) {
			debug("settings: no option for '" + value + "' in ." + sel.className + ", falling back");
			sel.selectedIndex = 0;
		}
		return sel.value;
	}

	// Reflect the loaded version + play mode. This reads live game state on every
	// open, so it reports whatever the game is actually doing -- including a state
	// something else put it in.
	function syncNav() {
		var vsel = dialog.querySelector(".ls-version");
		selectValue(vsel, gameSettings.get("version"));

		// Watching a demo is a round trip out of training and back, so the toggle
		// stays On for its duration rather than flickering off mid-replay.
		var mode = gameSettings.get("mode");
		var training = (mode === PLAY_MODERN || mode === PLAY_DEMO ||
		                mode === PLAY_DEMO_ONCE);
		pressOne(".ls-mode", function(b){ return (b.getAttribute("data-on") === "1") === training; });

		//choosing a level only means something when you can jump to one
		dialog.querySelector(".ls-level").disabled = !training;

		var exp = dialog.querySelector(".ls-export");
		if(exp) exp.disabled = !(typeof customLevels !== "undefined" && customLevels.canExport());
	}
	//swatch backgrounds follow the active theme's true brick colors
	//(Apple II and C64 differ; "original" is the sampled brick color)
	function refreshSwatches() {
		var colors = swatchColors();
		var btns = root.querySelectorAll(".ls-color .swatch");
		for(var i = 0; i < btns.length && i < colors.length; i++)
			btns[i].style.background = colors[i];
	}
	function renderSpeed() {
		var idx = gameSettings.get("speed");
		root.querySelector(".ls-speed-val").textContent = SPEED_LABELS[idx];
		root.querySelector(".ls-speed-down").disabled = idx <= 0;
		root.querySelector(".ls-speed-up").disabled = idx >= SPEED_LABELS.length - 1;
	}

	//--- events ---
	function wire() {
		toggleBtn.onclick = function(){ setMenuOpen(true); };
		dialog.querySelector(".ls-back").onclick = function(){ setView("main"); };
		// Help opens its own dialog, the way the level selector does: the key
		// list and controller diagram are reference material, not settings.
		dialog.querySelector(".ls-help").onclick = function() {
			setMenuOpen(false);
			helpDialog.open({});
		};

		//navigation: switching mode/version relaunches the game, so close the menu
		dialog.querySelector(".ls-mode").onclick = function(e){
			var b = e.target.closest("button"); if(!b) return;
			var on = b.getAttribute("data-on") === "1";
			if(on === (gameSettings.get("mode") === PLAY_MODERN)) return; //already there
			setMenuOpen(false);
			gameSettings.setMode(on);
		};
		var infoBtn = dialog.querySelector(".ls-info");
		if(infoBtn) infoBtn.onclick = function(){ renderInfoView(); setView("info"); };

		//capture: the picker's option rows do not bubble hover like normal DOM
		dialog.querySelector(".ls-version").addEventListener("mouseover", function(e){
			var m = e.target.closest && e.target.closest(".vi");
			if(m) showVersionCard(m);
		}, true);
		//Closing on mouseout alone would make a link in the card unreachable:
		//the pointer has to cross the gap to get there. Close on a short delay
		//instead, which entering the card cancels.
		dialog.querySelector(".ls-version").addEventListener("mouseout", function(e){
			var m = e.target.closest && e.target.closest(".vi");
			if(m) hideVersionCard(m, true);
		}, true);
		//a closing list leaves no mouseout behind, so sweep any card still up
		dialog.querySelector(".ls-version").addEventListener("toggle", function(){
			var cards = dialog.querySelectorAll(".vi-card");
			for(var i = 0; i < cards.length; i++)
				if(cards[i].matches(":popover-open")) cards[i].hidePopover();
		});
		dialog.querySelector(".ls-version").onchange = function(e){
			setMenuOpen(false);
			gameSettings.setVersion(+e.target.value);
		};
		dialog.querySelector(".ls-editor").onclick = function(){
			setMenuOpen(false);
			gameSettings.enterEditor();
		};
		dialog.querySelector(".ls-import").onclick = function(){
			setMenuOpen(false);
			importCustomLevels();
		};
		dialog.querySelector(".ls-export").onclick = function(){
			if(this.disabled) return;
			setMenuOpen(false);
			exportCustomLevels();
		};
		dialog.querySelector(".ls-level").onclick = function(){
			setMenuOpen(false);
			gameSettings.chooseLevel();
		};

		dialog.querySelector(".ls-theme").onclick = function(e){
			var b = e.target.closest("button"); if(!b) return;
			gameSettings.setTheme(b.getAttribute("data-theme"), syncFromModel);
		};
		dialog.querySelector(".ls-sound").onclick = function(e){
			var b = e.target.closest("button"); if(!b) return;
			gameSettings.setSound(b.getAttribute("data-on") === "1");
		};
		dialog.querySelector(".ls-repeat").onclick = function(e){
			var b = e.target.closest("button"); if(!b) return;
			gameSettings.setRepeat(b.getAttribute("data-on") === "1");
		};
		dialog.querySelector(".ls-gamepad").onclick = function(e){
			var b = e.target.closest("button"); if(!b) return;
			gameSettings.setGamepad(b.getAttribute("data-on") === "1");
		};
		dialog.querySelector(".ls-color").onclick = function(e){
			var b = e.target.closest("button"); if(!b) return;
			gameSettings.setColor(+b.getAttribute("data-color"));
		};
		dialog.querySelector(".ls-accent").onclick = function(e){
			var b = e.target.closest("button"); if(!b) return;
			gameSettings.setAccent(b.getAttribute("data-accent"));
			syncFromModel();          //repaint the selected ring onto the new swatch
		};
		dialog.querySelector(".ls-clear").onclick = function(){ openClearPanel(); };
		dialog.querySelector(".ls-clear-cancel").onclick = function(){ disarmClear(); };
		dialog.querySelector(".ls-clear-panel").onchange = function(){ renderClearGo(); };
		dialog.querySelector(".ls-clear-go").onclick = function(){
			var ids = checkedClearGroups();
			if(!ids.length) return;

			clearing = 1;
			var n = clearStorageGroups(ids);
			var note = dialog.querySelector(".ls-clear-note");
			this.disabled = true;
			note.textContent = n + (n === 1 ? " key" : " keys") + " removed. Reloading…";
			note.className = "clear-note ls-clear-note";
			// The game re-seeds storage as it boots (first-play version, last
			// play mode), so reloading is part of the operation, not advice.
			setTimeout(function(){ location.reload(); }, 700);
		};
		dialog.querySelector(".ls-speed-down").onclick = function(){ gameSettings.setSpeed(gameSettings.get("speed") - 1); };
		dialog.querySelector(".ls-speed-up").onclick   = function(){ gameSettings.setSpeed(gameSettings.get("speed") + 1); };

		//click on the ::backdrop (i.e. the dialog itself, outside .ls-panel) closes
		dialog.addEventListener("click", function(e){ if(e.target === dialog) setMenuOpen(false); });

		//in a sub-view, Esc goes back to main instead of closing the whole dialog
		dialog.addEventListener("cancel", function(e){
			if(inSubView()) { e.preventDefault(); setView("main"); }
		});

		// the native close event is the one place every close path converges
		// (Esc, backdrop click, .close()), so announce menu-close from here
		dialog.addEventListener("close", function(){ announce("menu-close"); });

		// Ctrl+M toggles the menu. On the document, not the canvas: the shortcut
		// belongs to the menu rather than to gameplay, and one handler owning
		// both halves means it works whether the game or the dialog has focus.
		document.addEventListener("keydown", function(e){
			if(!e.ctrlKey || e.keyCode !== KEYCODE_M) return;
			e.preventDefault();
			setMenuOpen(!dialog.open);
		}, true);

		//keep controls live if game state changes a value while open
		gameSettings.onChange(function(){ if(dialog.open) syncFromModel(); });
	}

	return { init: build };
})();

