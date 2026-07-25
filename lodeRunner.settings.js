//=============================================================================
// Settings model + DOM settings panel (Phase 1b chrome relocation).
//
// gameSettings is the single source of truth for user-facing settings (sound,
// theme, color, speed, repeat, gamepad). It reads current game state and exposes
// absolute setters that call the real game functions and notify listeners. The
// DOM panel binds to it; the legacy icon widgets, while they still exist, route
// through the same model so the two UIs never desync. See plan.md (Phase 1b).
//=============================================================================

var gameSettings = {
	_listeners: [],

	//subscribe to any settings change; fn(key, value)
	onChange: function(fn) { this._listeners.push(fn); },
	_notify: function(key, value) {
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
		else resumeAudioContext();                              //unmuting: user gesture unlock
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
		createjs.Ticker.setFPS(speedMode[speed]);
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

	//launch a play mode for the current version. mode: "challenge" | "training" | "demo".
	setMode: function(mode) {
		var self = this;
		function done(){ self._notify("mode", playMode); }
		if(mode === "challenge") classicPlay(0, done);
		else if(mode === "training") modernPlay(0, done);
		else if(mode === "demo") demoPlay(0, done);
	},

	//switch the loaded game version (playData), then relaunch the current play mode
	//so the new version's levels load. Version and mode are coupled at launch.
	setVersion: function(playDataId) {
		if(playDataId === playData) return;
		playData = playDataId;
		var mode = (playMode === PLAY_MODERN) ? "training"
		         : (playMode === PLAY_DEMO)   ? "demo"
		         : "challenge";                       //classic/other -> challenge
		this.setMode(mode);
		this._notify("version", playData);
	},

	//enter the level editor (minimal wire; the editor UI is a separate project)
	enterEditor: function() {
		editEdit(0, null);
		this._notify("mode", PLAY_EDIT);
	}
};

//=============================================================================
// DOM settings panel. Built from real game data; controls bind to gameSettings.
// Slice 1: coexists with the legacy icon strip. Version/Mode are display-only
// placeholders until Slice 3 wires the menu replacement.
//=============================================================================

var settingsPanel = (function() {
	var SPEED_LABELS = ["Very Slow", "Slow", "Normal", "Fast", "Very Fast"];
	var MODE_INFO = [
		["Challenge", "Play from level 1 for score, competing against other players' high scores."],
		["Training",  "Jump to any level and practice; progress is kept per version."],
		["Demo",      "Watch recorded playthroughs of levels others have cleared."],
		["Edit",      "Build and test your own custom levels."]
	];
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

		dialog = document.createElement("dialog");
		dialog.className = "ls-dialog";
		dialog.innerHTML =
			'<div class="ls-panel">' +
				'<div class="ls-head">' +
					'<button class="ls-back" aria-label="Back">&larr;</button>' +
					'<h2 class="ls-title"><b>LODE</b> RUNNER</h2>' +
				'</div>' +
				'<div class="ls-body">' + mainView() + helpView() + infoView() + modeView() + '</div>' +
			'</div>';

		document.body.appendChild(toggleBtn);
		document.body.appendChild(dialog);
		root = dialog;                       //control/query root is the dialog
		panel = dialog.querySelector(".ls-panel");
		body = dialog.querySelector(".ls-body");
		wire();
	}

	function mainView() {
		//version options from playVersionInfo so each carries its real playData id
		//(name<->id order differs from gameVersionName; use the registry as truth)
		var versionOpts = "";
		for(var i = 0; i < playVersionInfo.length; i++)
			versionOpts += '<option value="' + playVersionInfo[i].id + '">' + playVersionInfo[i].name.trim() + '</option>';
		//mode dropdown = Challenge / Training / Demo (Edit is the separate Level Editor item)
		var MODE_KEYS = ["challenge", "training", "demo"];
		var modeOpts = "";
		for(var m = 0; m < MODE_KEYS.length; m++)
			modeOpts += '<option value="' + MODE_KEYS[m] + '">' + MODE_INFO[m][0] + '</option>';

		//one swatch per preset slot; backgrounds are painted on open (refreshSwatches),
		//since the sampled "original" color is not ready until preload runs.
		var swatches = "";
		var slots = (themeColor[curTheme] || []).length;
		for(var c = 0; c < slots; c++) {
			var label = c === 0 ? "Original" : "Color " + c;
			swatches += '<button class="swatch" data-color="' + c + '" aria-label="' + label + '"></button>';
		}

		return '<div class="view-main">' +
			'<div class="group"><p class="group-label">Game</p>' +
				'<div class="row"><span class="row-name">Version</span>' +
					'<div class="pick-group">' +
						'<button class="icon-btn ls-info" aria-label="About this version">&#9432;</button>' +
						'<select class="pick ls-version" aria-label="Game version">' + versionOpts + '</select>' +
					'</div>' +
				'</div>' +
				'<div class="row"><span class="row-name">Mode</span>' +
					'<div class="pick-group">' +
						'<button class="icon-btn ls-mode-info" aria-label="About game modes">&#9432;</button>' +
						'<select class="pick ls-mode" aria-label="Game mode">' + modeOpts + '</select>' +
					'</div>' +
				'</div>' +
				//Level: gated by mode (Training/Demo only); the rich picker is deferred
				'<div class="row"><span class="row-name">Level<small>Training / Demo</small></span>' +
					'<button class="btn ls-level" disabled title="Level selection is coming soon">Choose&hellip;</button>' +
				'</div>' +
				'<div class="row"><span class="row-name">Level Editor</span>' +
					'<button class="btn ls-editor">Open</button>' +
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
			'<div class="group"><button class="btn ls-keys" style="width:100%">Keys</button></div>' +
		'</div>';
	}

	function helpView() {
		return '<div class="view-help">' +
			'<p class="help-h">Move &amp; Dig</p>' +
			'<div class="keys">' +
				'<kbd>&larr; &rarr;</kbd><span>Move left / right</span>' +
				'<kbd>&uarr; &darr;</kbd><span>Climb up / down</span>' +
				'<kbd>Z</kbd><span>Dig left</span>' +
				'<kbd>X</kbd><span>Dig right</span>' +
			'</div>' +
			'<p class="help-h">Game</p>' +
			'<div class="keys">' +
				'<kbd>Esc</kbd><span>Pause / help</span>' +
				'<kbd>Ctrl &minus;</kbd><span>Slower</span>' +
				'<kbd>Ctrl =</kbd><span>Faster</span>' +
				'<kbd>Ctrl A</kbd><span>Abort level</span>' +
				'<kbd>Ctrl R</kbd><span>Abort game</span>' +
			'</div>' +
			'<div class="rebind-note"><b>Rebinding keys</b> is coming to this screen &mdash; ' +
				'you\'ll click a key and press the one you want. For now these are the defaults.</div>' +
		'</div>';
	}

	function infoView() {
		//Slice 1: static Classic details; Slice 3 populates from playVersionInfo per selection.
		return '<div class="view-info">' +
			'<p class="help-h">Classic Lode Runner</p>' +
			'<div class="info-rows">' +
				'<span class="info-k">Released</span><span>1983, 1984</span>' +
				'<span class="info-k">Platform</span><span>Apple II, C64, IBM PC, NES</span>' +
				'<span class="info-k">Publisher</span><span>Br&oslash;derbund &amp; Ariolasoft</span>' +
				'<span class="info-k">Developer</span><span>Douglas E. Smith</span>' +
				'<span class="info-k">Levels</span><span>150</span>' +
				'<span class="info-k">Difficulty</span><span class="stars">&#9733;&#9733;&#9733;</span>' +
			'</div>' +
			'<div class="about">Version details will follow the selected version here.</div>' +
		'</div>';
	}

	function modeView() {
		var rows = "";
		for(var i = 0; i < MODE_INFO.length; i++)
			rows += '<dt>' + MODE_INFO[i][0] + '</dt><dd>' + MODE_INFO[i][1] + '</dd>';
		return '<div class="view-mode"><p class="help-h">Game Modes</p><dl class="mode-list">' + rows + '</dl></div>';
	}

	//--- open/close + sub-view routing ---
	var TITLES = { main: "<b>LODE</b> RUNNER", help: "KEYS", info: "VERSION", mode: "MODES" };
	var SUBVIEWS = ["help", "info", "mode"];

	//The settings menu knows nothing about the game. It only opens and closes.
	//The game (if it cares) watches the dialog's open/close and halts itself.
	function setOpen(on) {
		if(on) {
			if(dialog.open) return;
			syncFromModel();
			setView("main");
			dialog.showModal();               //top layer + ::backdrop scrim, native
		} else {
			dialog.close();
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
	function syncFromModel() {
		pressOne(".ls-theme",   function(b){ return b.getAttribute("data-theme") === gameSettings.get("theme"); });
		pressOne(".ls-sound",   function(b){ return (b.getAttribute("data-on") === "1") === gameSettings.get("sound"); });
		pressOne(".ls-repeat",  function(b){ return (b.getAttribute("data-on") === "1") === gameSettings.get("repeat"); });
		pressOne(".ls-gamepad", function(b){ return (b.getAttribute("data-on") === "1") === gameSettings.get("gamepad"); });
		pressOne(".ls-color",   function(b){ return +b.getAttribute("data-color") === gameSettings.get("color"); });
		refreshSwatches();
		renderSpeed();
		syncNav();
	}
	//reflect the loaded version + play mode; Level is enabled only in Training/Demo
	function syncNav() {
		var version = gameSettings.get("version");
		var vsel = dialog.querySelector(".ls-version");
		if(version != null) vsel.value = String(version);
		//map current playMode to a mode-dropdown key (edit/other stay on their nearest)
		var mode = gameSettings.get("mode");
		var key = (mode === PLAY_MODERN) ? "training" : (mode === PLAY_DEMO || mode === PLAY_DEMO_ONCE) ? "demo" : "challenge";
		dialog.querySelector(".ls-mode").value = key;
		//Level picker: available in Training/Demo only (matches legacy selectIcon gating)
		dialog.querySelector(".ls-level").disabled = !(mode === PLAY_MODERN || mode === PLAY_DEMO);
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
		toggleBtn.onclick = function(){ setOpen(true); };
		dialog.querySelector(".ls-back").onclick = function(){ setView("main"); };
		dialog.querySelector(".ls-keys").onclick = function(){ setView("help"); };
		dialog.querySelector(".ls-info").onclick = function(){ setView("info"); };
		dialog.querySelector(".ls-mode-info").onclick = function(){ setView("mode"); };

		//navigation: choosing a mode/version launches gameplay, so close the menu
		dialog.querySelector(".ls-mode").onchange = function(e){
			setOpen(false);
			gameSettings.setMode(e.target.value);
		};
		dialog.querySelector(".ls-version").onchange = function(e){
			setOpen(false);
			gameSettings.setVersion(+e.target.value);
		};
		dialog.querySelector(".ls-editor").onclick = function(){
			setOpen(false);
			gameSettings.enterEditor();
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
		dialog.querySelector(".ls-speed-down").onclick = function(){ gameSettings.setSpeed(gameSettings.get("speed") - 1); };
		dialog.querySelector(".ls-speed-up").onclick   = function(){ gameSettings.setSpeed(gameSettings.get("speed") + 1); };

		//click on the ::backdrop (i.e. the dialog itself, outside .ls-panel) closes
		dialog.addEventListener("click", function(e){ if(e.target === dialog) setOpen(false); });

		//in a sub-view, Esc goes back to main instead of closing the whole dialog
		dialog.addEventListener("cancel", function(e){
			if(inSubView()) { e.preventDefault(); setView("main"); }
		});

		//keep controls live if game state changes a value while open
		gameSettings.onChange(function(){ if(dialog.open) syncFromModel(); });
	}

	return { init: build };
})();

