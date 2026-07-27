//=============================================================================
// Board icons: the two in-play / in-edit controls that sit on the game surface.
//
// Training: watch-demo + choose-level.
// Level editor: import + export (same bar geometry -- swap the pair, do not
// invent a second layout).
//
// Pinned top-right, balancing the settings hamburger top-left. Inline SVG stays
// sharp at any density and takes its color from the panel palette.
//=============================================================================

var boardIcons = (function() {
	var root, playBtn, levelBtn, importBtn, exportBtn;
	var demoRunning = 0;

	// viewBox 40x36 throughout: the size the old icon bitmaps were authored at,
	// so the new art lands in the same visual footprint as what it replaces.
	var SVG_GRID =
		'<svg viewBox="0 0 40 36" aria-hidden="true">' +
			'<g class="bi-stroke">' +
				'<rect x="9" y="7" width="9" height="9"/>' +
				'<rect x="22" y="7" width="9" height="9"/>' +
				'<rect x="9" y="20" width="9" height="9"/>' +
				'<rect x="22" y="20" width="9" height="9"/>' +
			'</g>' +
		'</svg>';

	var SVG_PLAY =
		'<svg viewBox="0 0 40 36" aria-hidden="true">' +
			'<rect class="bi-stroke" x="5" y="7" width="30" height="22"/>' +
			'<path class="bi-fill" d="M17 13.5 L26 18 L17 22.5 Z"/>' +
		'</svg>';

	var SVG_STOP =
		'<svg viewBox="0 0 40 36" aria-hidden="true">' +
			'<rect class="bi-stroke" x="5" y="7" width="30" height="22"/>' +
			'<rect class="bi-fill" x="16" y="14" width="8" height="8"/>' +
		'</svg>';

	// Download / upload trays -- Import and Export.
	var SVG_IMPORT =
		'<svg viewBox="0 0 40 36" aria-hidden="true">' +
			'<g class="bi-stroke">' +
				'<path d="M20 6 L20 22"/>' +
				'<path d="M13 16 L20 23 L27 16"/>' +
				'<path d="M10 28 L30 28"/>' +
				'<path d="M10 28 L10 24"/>' +
				'<path d="M30 28 L30 24"/>' +
			'</g>' +
		'</svg>';

	var SVG_EXPORT =
		'<svg viewBox="0 0 40 36" aria-hidden="true">' +
			'<g class="bi-stroke">' +
				'<path d="M20 23 L20 7"/>' +
				'<path d="M13 13 L20 6 L27 13"/>' +
				'<path d="M10 28 L30 28"/>' +
				'<path d="M10 28 L10 24"/>' +
				'<path d="M30 28 L30 24"/>' +
			'</g>' +
		'</svg>';

	function makeBtn(cls, svg, title) {
		var b = document.createElement("button");
		b.className = "bi-btn " + cls;
		b.innerHTML = svg;
		b.title = title;
		b.setAttribute("aria-label", title);
		return b;
	}

	function build() {
		root = document.createElement("div");
		root.className = "bi-bar";
		root.hidden = true;

		playBtn = makeBtn("bi-play", SVG_PLAY, "Watch demo");
		levelBtn = makeBtn("bi-level", SVG_GRID, "Choose level");
		importBtn = makeBtn("bi-import", SVG_IMPORT, "Import custom levels");
		exportBtn = makeBtn("bi-export", SVG_EXPORT, "Export custom levels");

		root.appendChild(playBtn);
		root.appendChild(levelBtn);
		root.appendChild(importBtn);
		root.appendChild(exportBtn);
		document.body.appendChild(root);

		playBtn.onclick = function() {
			if(demoRunning) stopDemo(); else startDemo();
			focusGame();
		};
		levelBtn.onclick = function() { chooseLevel(); };
		importBtn.onclick = function() { importCustomLevels(); };
		exportBtn.onclick = function() { exportCustomLevels(); };

		setPlayLabel();
	}

	function setPlayLabel() {
		var watching = demoRunning;
		playBtn.innerHTML = watching ? SVG_STOP : SVG_PLAY;
		playBtn.title = watching ? "Stop demo" : "Watch demo";
		playBtn.setAttribute("aria-label", playBtn.title);
		playBtn.classList.toggle("bi-stopping", !!watching);
	}

	function startDemo() {
		if(!curDemoLevelIsVaild()) return;
		demoSoundOff = 1;
		playMode = PLAY_DEMO_ONCE;
		anyKeyStopDemo();
		setDemoState(1);
		startGame(1);
		setTimeout(function() { showTipsText("HIT ANY KEY TO STOP DEMO", 3500); }, 50);
	}

	function stopDemo() {
		stopDemoAndPlay();
	}

	function chooseLevel() {
		if(demoRunning) stopDemo();

		var picked = 0;
		levelSelect.open({
			current: curLevel,
			onPick: function(level) {
				picked = 1;
				soundStop(soundDig); soundStop(soundFall);
				curLevel = level;
				setModernInfo();
				startGame();
			},
			onClose: function() { if(!picked) focusGame(); }
		});
	}

	function setDemoState(on) {
		demoRunning = on ? 1 : 0;
		if(!root) return;
		setPlayLabel();
	}

	function update() {
		if(!root) build();
		var training = (playMode == PLAY_MODERN);
		var watching = (playMode == PLAY_DEMO_ONCE);
		var editing = (playMode == PLAY_EDIT || playMode == PLAY_TEST);

		root.hidden = !(training || watching || editing);
		if(root.hidden) return;

		playBtn.hidden = editing;
		levelBtn.hidden = editing;
		importBtn.hidden = !editing;
		exportBtn.hidden = !editing;

		if(editing) {
			exportBtn.disabled = !(typeof customLevels !== "undefined" && customLevels.canExport());
			return;
		}

		setDemoState(watching);
		if(!watching) playBtn.disabled = !curDemoLevelIsVaild();
		else playBtn.disabled = false;
	}

	function hide() {
		if(root) root.hidden = true;
	}

	return { init: build, update: update, hide: hide, setDemoState: setDemoState };
})();
