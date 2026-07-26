//=============================================================================
// Board icons: the two in-play controls that sit on the game surface.
//
// Level select and watch-demo are actions you take while playing, so they live
// on the board rather than inside the settings panel -- a control you use mid
// game should not be two clicks deep. They are DOM buttons pinned top-right,
// balancing the settings hamburger top-left.
//
// Replaces selectIconClass/demoIconClass, which drew bitmaps into their own
// canvases. Inline SVG stays sharp at any density and takes its color from the
// panel palette, so no preloaded art is involved.
//=============================================================================

var boardIcons = (function() {
	var root, playBtn, levelBtn;
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

	// A screen with a play triangle: "watch this level", not "start a level".
	var SVG_PLAY =
		'<svg viewBox="0 0 40 36" aria-hidden="true">' +
			'<rect class="bi-stroke" x="5" y="7" width="30" height="22"/>' +
			'<path class="bi-fill" d="M17 13.5 L26 18 L17 22.5 Z"/>' +
		'</svg>';

	// Same frame, stop square inside. The frame holding still across the swap is
	// what makes it read as one control changing state; dimming would read as
	// disabled, which is the opposite of "this is now your way out".
	var SVG_STOP =
		'<svg viewBox="0 0 40 36" aria-hidden="true">' +
			'<rect class="bi-stroke" x="5" y="7" width="30" height="22"/>' +
			'<rect class="bi-fill" x="16" y="14" width="8" height="8"/>' +
		'</svg>';

	function build() {
		root = document.createElement("div");
		root.className = "bi-bar";
		root.hidden = true;

		playBtn = document.createElement("button");
		playBtn.className = "bi-btn bi-play";
		playBtn.innerHTML = SVG_PLAY;

		levelBtn = document.createElement("button");
		levelBtn.className = "bi-btn bi-level";
		levelBtn.innerHTML = SVG_GRID;
		levelBtn.title = "Choose level";
		levelBtn.setAttribute("aria-label", "Choose level");

		root.appendChild(playBtn);
		root.appendChild(levelBtn);
		document.body.appendChild(root);

		playBtn.onclick = function() {
			if(demoRunning) stopDemo(); else startDemo();
			focusGame();
		};
		levelBtn.onclick = function() { chooseLevel(); };

		setPlayLabel();
	}

	function setPlayLabel() {
		var watching = demoRunning;
		playBtn.innerHTML = watching ? SVG_STOP : SVG_PLAY;
		playBtn.title = watching ? "Stop demo" : "Watch demo";
		playBtn.setAttribute("aria-label", playBtn.title);
		playBtn.classList.toggle("bi-stopping", !!watching);
	}

	// Watching a recording of the level you are on. PLAY_DEMO_ONCE returns to
	// PLAY_MODERN on every exit path (death or completion), so this is a round
	// trip out of training and back, not a mode you are left sitting in.
	function startDemo() {
		if(!curDemoLevelIsVaild()) return;
		demoSoundOff = 1;              //demos always play silent
		playMode = PLAY_DEMO_ONCE;
		anyKeyStopDemo();
		setDemoState(1);
		startGame(1);
		setTimeout(function() { showTipsText("HIT ANY KEY TO STOP DEMO", 3500); }, 50);
	}

	function stopDemo() {
		stopDemoAndPlay();
	}

	// Reachable during a demo too: stop the replay first, then pick. Choosing a
	// level is itself a way out of the demo, so the button leads somewhere
	// rather than sitting inert while a recording plays.
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

	// Visible in training only: challenge starts at level 1 and progresses, so
	// there is no level to choose and no recording to watch.
	function update() {
		if(!root) build();
		var training = (playMode == PLAY_MODERN);
		var watching = (playMode == PLAY_DEMO_ONCE);

		root.hidden = !(training || watching);
		if(root.hidden) return;

		setDemoState(watching);
		if(!watching) playBtn.disabled = !curDemoLevelIsVaild();
		else playBtn.disabled = false;
	}

	function hide() {
		if(root) root.hidden = true;
	}

	return { init: build, update: update, hide: hide, setDemoState: setDemoState };
})();
