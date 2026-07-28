//=============================================================================
// Level pass dialog: the training-mode level-complete screen, as a DOM dialog.
//
// Replaces levelPassDialog in menu.js -- ~370 lines of createjs Text, Shape,
// Container and Shadow, hand-rolled hover borders, and manual addChild/
// removeChild -- with markup the browser lays out.
//
// Header is a two-line celebration: LEVEL COMPLETE, then quieter LEVEL NNN
// (brick on the number). Sizes are baked ~80% of Simon's scale-1 constants
// (see levelPass.css). Dual party poppers (lodeRunner.confetti.js) fire on
// open from dialed-in left/right settings.
//
// The count-up is the point of the screen, so its cadence is carried over
// exactly: 85ms a step, +47 a step at 100 points each, a four-step rest
// between rows, and scoreBell / scoreCount / scoreEnding at the same moments.
// Time counts DOWN from MAX_TIME_COUNT (999), which is why it is the long row.
//
// One dialog, built once, reused. open() takes plain numbers -- no stage, no
// scale, no bitmaps -- and reports the choice through onPick(0|1|2), the same
// contract gameFinishCallback already expects.
//=============================================================================

var levelPass = (function() {
	// Simon's constants, verbatim from levelPassDialog.
	var COUNT_MS = 85;    // countTime
	var ADD      = 47;    // countAddValue
	var POINT    = 100;   // onePointValue

	// Party poppers -- dialed in tools/confetti/. Left is canonical; right was
	// authored with mirror on (so its xFrac/angle are pre-mirror values).
	var POPPER_LEFT = {
		xFrac: -0.2, yFrac: 0.3, angle: 64, energy: 1.4,
		size: 0.25, spread: 35, count: 80, mirror: false
	};
	var POPPER_RIGHT = {
		xFrac: -0.08, yFrac: 0.63, angle: 70, energy: 1.5,
		size: 0.25, spread: 35, count: 80, mirror: true
	};

	// Icons: replay and next are ours; the grid is the mark the board already
	// uses for level select (SVG_GRID in boardIcons), so the two surfaces name
	// the same action the same way.
	var SVG_REPLAY =
		'<svg viewBox="0 0 24 24" aria-hidden="true">' +
			'<path d="M12 5V1L7 6l5 5V7a6 6 0 1 1-6 6H4a8 8 0 1 0 8-8z"/></svg>';
	var SVG_GRID =
		'<svg viewBox="0 0 40 36" class="ic-grid" aria-hidden="true">' +
			'<rect x="9" y="7" width="9" height="9"/>' +
			'<rect x="22" y="7" width="9" height="9"/>' +
			'<rect x="9" y="20" width="9" height="9"/>' +
			'<rect x="22" y="20" width="9" height="9"/></svg>';
	var SVG_NEXT =
		'<svg viewBox="0 0 24 24" aria-hidden="true">' +
			'<path d="M4 11h11.2l-4.6-4.6L12 5l7 7-7 7-1.4-1.4 4.6-4.6H4z"/></svg>';

	var dialog, rowsEl, btnsEl;
	var timers = [];
	var popperTimer = null;   // setInterval id for the 4s re-fire loop
	var popperShots = 0;
	var pickFun = null;
	var pending = 0;      // which button the close is reporting; 0 = replay
	var done = 0;         // tally finished: buttons are live
	var POPPER_EVERY = 4000;
	var POPPER_SHOTS = 10;    // then stop (~40s at POPPER_EVERY)

	function later(fn, ms) { timers.push(setTimeout(fn, ms)); }
	function clearTimers() {
		for(var i = 0; i < timers.length; i++) clearTimeout(timers[i]);
		timers = [];
		if(popperTimer != null) {
			clearInterval(popperTimer);
			popperTimer = null;
		}
		popperShots = 0;
	}
	function pad3(n) { return ("00" + n).slice(-3); }
	function pad6(n) { return ("00000" + n).slice(-6); }

	function build() {
		dialog = document.createElement("dialog");
		dialog.className = "lp-dialog";
		dialog.innerHTML =
			'<div class="lp-panel">' +
				'<div class="lp-heading">' +
					'<p class="lp-title">LEVEL COMPLETE</p>' +
					'<p class="lp-level">LEVEL <b class="lvl">001</b></p>' +
				'</div>' +
				'<div class="lp-rows">' +
					'<span class="lp-glyph lp-glyph-gold r-gold" role="img" aria-label="Gold"></span>' +
					'<span class="lp-val r-gold v-gold">000</span>' +
					'<span class="lp-glyph lp-glyph-guard r-guard" role="img" aria-label="Guards trapped"></span>' +
					'<span class="lp-val r-guard v-guard">000</span>' +
					'<span class="lp-lbl r-time">TIME</span>' +
					'<span class="lp-val r-time v-time">999</span>' +
					'<span class="lp-lbl">SCORE</span>' +
					'<span class="lp-val v-score">000000</span>' +
					'<span class="lp-lbl">HI-SCORE</span>' +
					'<span class="lp-val v-hi">000000</span>' +
				'</div>' +
				'<div class="lp-buttons">' +
					'<button class="lp-btn" data-pick="0" title="Replay this level" ' +
					        'aria-label="Replay this level">' + SVG_REPLAY + '</button>' +
					'<button class="lp-btn" data-pick="1" title="Choose a level" ' +
					        'aria-label="Choose a level">' + SVG_GRID + '</button>' +
					'<button class="lp-btn" data-pick="2" title="Next level" ' +
					        'aria-label="Next level">' + SVG_NEXT + '</button>' +
				'</div>' +
			'</div>';
		document.body.appendChild(dialog);

		rowsEl = dialog.querySelector(".lp-rows");
		btnsEl = dialog.querySelector(".lp-buttons");

		btnsEl.onclick = function(e) {
			var b = e.target.closest("button");
			if(!b || !done) return;          // inert until the tally settles
			choose(+b.getAttribute("data-pick"));
		};

		// Esc leaves you on the level you just finished, which is the same place
		// Replay puts you -- there is nowhere else to be, so it is not a dismiss.
		// While the tally is still counting there is nothing to choose yet, so
		// Esc is swallowed rather than closing on a half-counted score.
		dialog.addEventListener("cancel", function(e) {
			e.preventDefault();
			if(done) choose(0);
		});

		// Every close path converges here, so the pick is reported from here.
		// The game is parked in GAME_WAITING until the callback moves it on, so
		// a close that reported nothing would strand it -- that makes replay the
		// default for any exit we did not explicitly route.
		dialog.addEventListener("close", function() {
			clearTimers();
			document.dispatchEvent(new CustomEvent("menu-close"));
			var fn = pickFun; pickFun = null;
			if(fn) fn(pending);
		});
	}

	// choose() records the pick and closes; the close handler reports it.
	function choose(which) {
		pending = which;
		if(dialog.open) dialog.close();
	}

	// The text sheet is rebuilt on every theme/color change, so re-read it on
	// open rather than caching -- the glyphs must match the board just left.
	//
	// getThemeBitmapImage is the accessor the rest of the game uses and is live
	// from the first theme build; textAtlas is not created until createSpriteSheet
	// runs, so reading that instead can miss on an early open. The image is a
	// plain <img> on the untinted color and a recolored <canvas> on every other
	// slot (createBitmap, colorTheme.js) -- CSS needs a URL for both.
	function bindAtlas() {
		var img = getThemeBitmapImage("text");
		if(!img) return;
		var url = img.src || (img.toDataURL ? img.toDataURL() : "");
		if(url) dialog.style.setProperty("--lp-atlas", 'url("' + url + '")');
	}

	function celebrate() {
		if(typeof confetti === "undefined" || !confetti.burst) return;
		var left = {}, right = {}, k;
		for(k in POPPER_LEFT) left[k] = POPPER_LEFT[k];
		for(k in POPPER_RIGHT) right[k] = POPPER_RIGHT[k];
		left.origin = right.origin = dialog;
		confetti.burst(left);
		confetti.burst(right);
	}

	function startCelebrateLoop() {
		popperShots = 0;
		function shot() {
			celebrate();
			popperShots++;
			if(popperShots >= POPPER_SHOTS && popperTimer != null) {
				clearInterval(popperTimer);
				popperTimer = null;
			}
		}
		shot();
		if(window.matchMedia &&
		   window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;
		popperTimer = setInterval(shot, POPPER_EVERY);
	}

	// One counter for all three rows. Simon had three near-identical copies of
	// this (goldScoreCounting / guardScoreCounting / timeScoreCounting).
	function countUp(show, el, from, to, hiScore, state, whenDone) {
		rowsEl.classList.add(show);
		soundPlay("scoreBell");
		var cur = from, dir = (to < from) ? -1 : 1;

		(function step() {
			if(cur === to) { later(whenDone, COUNT_MS * 4); return; }
			var delta = Math.min(ADD, Math.abs(to - cur)) * dir;
			cur += delta;
			state.score += Math.abs(delta) * POINT;
			el.textContent = pad3(cur);

			dialog.querySelector(".v-score").textContent = pad6(state.score);
			if(hiScore < state.score) {          // his updateHiScore()
				var hi = dialog.querySelector(".v-hi");
				hi.textContent = pad6(state.score);
				hi.classList.add("beat");
			}
			soundPlay("scoreCount");
			later(step, COUNT_MS);
		})();
	}

	// open(opts) -- opts: { level, gold, guardDead, time, hiScore, onPick }
	// onPick(0) replay this level, (1) choose a level, (2) next level.
	function open(opts) {
		if(!dialog) build();
		clearTimers();
		pickFun = opts.onPick || null;
		pending = 0;      // replay unless a button says otherwise
		done = 0;

		var maxTime = MAX_TIME_COUNT;
		var state = { score: 0 };

		bindAtlas();
		rowsEl.className = "lp-rows";
		btnsEl.classList.remove("in");
		dialog.querySelector(".lvl").textContent     = pad3(opts.level);
		dialog.querySelector(".v-gold").textContent  = "000";
		dialog.querySelector(".v-guard").textContent = "000";
		dialog.querySelector(".v-time").textContent  = pad3(maxTime);
		dialog.querySelector(".v-score").textContent = "000000";
		var hiEl = dialog.querySelector(".v-hi");
		hiEl.textContent = pad6(opts.hiScore);
		hiEl.classList.remove("beat");

		dialog.showModal();
		document.dispatchEvent(new CustomEvent("menu-open"));

		// Wait a frame so the dialog's box is laid out before we measure it.
		later(startCelebrateLoop, 40);

		later(function() {
			countUp("show-gold", dialog.querySelector(".v-gold"), 0, opts.gold,
			        opts.hiScore, state, function() {
				countUp("show-guard", dialog.querySelector(".v-guard"), 0, opts.guardDead,
				        opts.hiScore, state, function() {
					countUp("show-time", dialog.querySelector(".v-time"), maxTime, opts.time,
					        opts.hiScore, state, function() {
						soundPlay("scoreEnding");
						done = 1;
						btnsEl.classList.add("in");
						// focus Next so the keyboard has somewhere to land
						btnsEl.querySelector('[data-pick="2"]').focus();
					});
				});
			});
		}, 200);
	}

	return { init: build, open: open };
})();
