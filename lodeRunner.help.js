//=============================================================================
// Keys & gamepad help: a DOM dialog, sibling of the level selector.
//
// Replaces helpMenuClass and the two help PNGs. Help as a bitmap could not be
// searched, selected or reflowed, and -- because a picture cannot be diffed
// against the code it documents -- it drifted: the old art labelled Ctrl A
// "Abort Game" when Ctrl A only cost a life, and it omitted ten bindings the
// game actually had. Everything here was read off the handlers in key.js,
// edit.js, settings.js and gamepad.js.
//
// Two tabs. Keyboard leads with the movement and dig clusters, because the
// SHAPE of those keys is the instruction -- the inverted T, and the alternate
// sets that are the same T under each hand. Everything else is a lookup and
// gets a table row, with a column naming the menu control that does the same
// job where one exists.
//
// The dialog has two callers with different contracts: the settings menu opens
// it as reference, and the first-play sequence opens it between naming yourself
// and your first level (see showHelpMenu in main.js), holding the game until it
// closes. open({onClose}) serves both.
//=============================================================================

var helpDialog = (function() {
	var ART_URL = "image/gamepad-snes.svg";

	var dialog, panel, artHost;
	var postFun = null;
	var artLoaded = 0;

	//--- keyboard tab -----------------------------------------------------

	// One control set, as a column: the movement cluster, the caption naming
	// that cluster, then the dig pair directly beneath it. Everything is
	// centred on one axis, so Z X sits under the arrows, U O under I J K L and
	// Q E under W A S D -- the layout says which keys go together.
	//
	// "left" and "right" run under the dig columns rather than being repeated
	// per set: all three left-dig keys share a column, as do all three right.
	function controlSet(up, left, down, right, digL, digR, note) {
		return '<div class="hk-set">' +
			'<div class="hk-cluster">' +
				'<kbd class="cap up">'    + up    + '</kbd>' +
				'<kbd class="cap left">'  + left  + '</kbd>' +
				'<kbd class="cap down">'  + down  + '</kbd>' +
				'<kbd class="cap right">' + right + '</kbd>' +
			'</div>' +
			'<p class="hk-cap-note">' + note + '</p>' +
			'<div class="hk-cluster hk-pair">' +
				'<kbd class="cap">' + digL + '</kbd><kbd class="cap">' + digR + '</kbd>' +
			'</div>' +
			'<p class="hk-cap-note hk-dig-note"><span>left</span><span>right</span></p>' +
		'</div>';
	}


	// rows: [key, action, menu-equivalent-or-empty]
	function table(head, rows) {
		var html = '<table class="hk-table"><tr><th>Key</th><th>Action</th>' +
		           '<th>' + (head || "") + '</th></tr>';
		for(var i = 0; i < rows.length; i++) {
			var r = rows[i];
			html += '<tr>' +
				'<td class="k"><span class="hk-k">' + r[0] + '</span></td>' +
				'<td class="a">' + r[1] + '</td>' +
				'<td class="m' + (r[2] ? '' : ' none') + '">' + (r[2] || "") + '</td>' +
			'</tr>';
		}
		return html + '</table>';
	}

	function keyboardPane() {
		return '<div class="hk-body hk-pane" id="hk-pane-kb" role="tabpanel" ' +
		            'aria-labelledby="hk-tab-kb">' +

			'<div class="hk-group full">' +
				'<p class="hk-h">Move</p>' +
				'<div class="hk-sets">' +
					// the Dig header sits on its own grid row, spanning the sets,
					// so it stays a section header over the dig keys
					'<p class="hk-h hk-dig-h">Dig</p>' +
					controlSet("&uarr;", "&larr;", "&darr;", "&rarr;", "Z", "X",
					           "arrow keys") +
					controlSet("I", "J", "K", "L", "U", "O", "same, right hand") +
					controlSet("W", "A", "S", "D", "Q", "E", "same, left hand") +
				'</div>' +
			'</div>' +

			'<div class="hk-group">' +
				'<p class="hk-h">Game</p>' +
				table("", [
					["Esc",    "Pause / resume", ""],
					["Enter",  'High scores <span class="hk-tag">(classic)</span>', ""],
					["Ctrl R", 'Restart level <span class="hk-tag">(costs a life)</span>', ""],
					["Ctrl X", 'Exit game <span class="hk-tag">(back to level 1)</span>', ""],
					["Ctrl T", "Reveal trap blocks", ""],
					["Ctrl &minus;", "Slower", ""],
					["Ctrl =", "Faster", ""]
				]) +
			'</div>' +

			'<div class="hk-group">' +
				'<p class="hk-h">Settings</p>' +
				table("In menu", [
					["Ctrl M", "Menu open / close", ""],
					["Ctrl S", "Sound on / off", "Sound"],
					["Ctrl J", "Gamepad on / off", "Gamepad"],
					["Ctrl 1&ndash;5", "Color theme", "Color"],
					["Ctrl K", "Key repeat on / off", ""],
					["Ctrl H", "Red-hat guards on / off", ""]
				]) +
			'</div>' +

			'<div class="hk-group">' +
				'<p class="hk-h">Editor</p>' +
				table("", [
					["Ctrl C", "Copy level", "from play or the editor"],
					["Ctrl V", "Paste level", "into an empty editor slot"]
				]) +
			'</div>' +
		'</div>';
	}

	//--- gamepad tab ------------------------------------------------------

	// Numbers match the callouts drawn into image/gamepad-snes.svg. Every button
	// the game uses gets its own number, so nothing shares a callout.
	var GP_ROWS = [
		[1, "Run and climb",
		    "D-pad, or an analog stick if the pad has one"],
		[2, "Dig left",  "Y or X"],
		[3, "Dig right", "A"],
		[4, "Pause / resume", "Select"],
		[5, "Exit game", "hold both shoulder buttons"],
		[6, "Accept", "Start, on menus and prompts"]
	];

	function gamepadPane() {
		var list = "";
		for(var i = 0; i < GP_ROWS.length; i++) {
			var r = GP_ROWS[i];
			list += '<li><span class="gp-n">' + r[0] + '</span>' +
			        '<span>' + r[1] + '<small>' + r[2] + '</small></span></li>';
		}
		return '<div class="hk-body hk-pane hk-pane-gp" id="hk-pane-gp" ' +
		            'role="tabpanel" aria-labelledby="hk-tab-gp" hidden>' +
			'<div class="gp-wrap">' +
				'<div class="gp-fig"></div>' +
				'<div class="gp-side">' +
					'<ul class="gp-list">' + list + '</ul>' +
					'<p class="gp-status" role="status"></p>' +
				'</div>' +
			'</div>' +
		'</div>';
	}

	// The art is 20KB of paths -- too much to carry in a JS string, and it is
	// artwork, not logic. Fetched once on first view of the tab and inlined so
	// its strokes inherit currentColor; an <img> would not take the accent.
	function loadArt() {
		if(artLoaded) return;
		artLoaded = 1;
		var req = new XMLHttpRequest();
		req.open("GET", ART_URL, true);
		req.onload = function() {
			if(req.status >= 200 && req.status < 300) {
				artHost.innerHTML = req.responseText;
			} else {
				artLoaded = 0;               // let a later open try again
			}
		};
		req.onerror = function(){ artLoaded = 0; };
		req.send();
	}

	// A connected pad is worth saying out loud: "gamepad on" in the menu does
	// not mean one is plugged in, and this is the only screen that can tell you.
	function refreshGamepadStatus() {
		var el = panel.querySelector(".gp-status");
		if(!el) return;
		var pads = (navigator.getGamepads && navigator.getGamepads()) || [];
		var found = null;
		for(var i = 0; i < pads.length; i++) if(pads[i]) { found = pads[i]; break; }

		if(found) {
			el.className = "gp-status found";
			el.textContent = "Connected: " + found.id;
		} else {
			el.className = "gp-status";
			el.textContent = "No gamepad detected. Connect one and press a button.";
		}
	}

	//--- tabs -------------------------------------------------------------

	function selectTab(idx) {
		var tabs  = panel.querySelectorAll(".hk-tab");
		for(var i = 0; i < tabs.length; i++) {
			var on = (i === idx);
			tabs[i].setAttribute("aria-selected", on ? "true" : "false");
			tabs[i].tabIndex = on ? 0 : -1;
			document.getElementById(tabs[i].getAttribute("aria-controls")).hidden = !on;
		}
		if(idx === 1) { loadArt(); refreshGamepadStatus(); }
		panel.querySelector(".hk-pane:not([hidden])").scrollTop = 0;
	}

	function build() {
		dialog = document.createElement("dialog");
		dialog.className = "hk-dialog";
		dialog.innerHTML =
			'<div class="hk-panel">' +
				'<div class="hk-head">' +
					'<span class="hk-title">Lode <b>Runner</b> &mdash; Help</span>' +
					'<button class="hk-close" aria-label="Close">&times;</button>' +
				'</div>' +
				'<div class="hk-tabs" role="tablist">' +
					'<button class="hk-tab" role="tab" id="hk-tab-kb" ' +
					        'aria-controls="hk-pane-kb" aria-selected="true">Keyboard</button>' +
					'<button class="hk-tab" role="tab" id="hk-tab-gp" ' +
					        'aria-controls="hk-pane-gp" aria-selected="false">Gamepad</button>' +
				'</div>' +
				keyboardPane() +
				gamepadPane() +
			'</div>';
		document.body.appendChild(dialog);

		panel   = dialog.querySelector(".hk-panel");
		artHost = dialog.querySelector(".gp-fig");

		var tabs = panel.querySelectorAll(".hk-tab");
		for(var i = 0; i < tabs.length; i++) {
			(function(n) {
				tabs[n].onclick = function(){ selectTab(n); };
				tabs[n].onkeydown = function(e) {
					var d = e.key === "ArrowRight" ? 1 : e.key === "ArrowLeft" ? -1 : 0;
					if(!d) return;
					e.preventDefault();
					var t = (n + d + tabs.length) % tabs.length;
					selectTab(t); tabs[t].focus();
				};
			})(i);
		}

		dialog.querySelector(".hk-close").onclick = function(){ close(); };
		// click on the ::backdrop (the dialog itself, outside the panel) closes
		dialog.addEventListener("click", function(e){ if(e.target === dialog) close(); });
		// every close path (Esc, backdrop, .close()) converges on the native event
		dialog.addEventListener("close", function() {
			document.dispatchEvent(new CustomEvent("menu-close"));
			var fn = postFun; postFun = null;
			if(fn) fn();
		});

		// A pad plugged in while this is open should show up without reopening.
		window.addEventListener("gamepadconnected",    refreshGamepadStatus);
		window.addEventListener("gamepaddisconnected", refreshGamepadStatus);
	}

	function close() {
		if(dialog && dialog.open) dialog.close();
	}

	// open(opts) -- opts: { onClose }
	// onClose runs on every close path, so first-play can resume the boot
	// sequence with it and the menu can pass nothing.
	function open(opts) {
		if(!dialog) build();
		postFun = (opts && opts.onClose) || null;
		selectTab(0);
		dialog.showModal();
		document.dispatchEvent(new CustomEvent("menu-open"));
	}

	return { init: build, open: open, close: close };
})();
