//=============================================================================
// Yes/No (and multi-choice) confirm: a small DOM dialog.
//
// open({ lines, onPick, buttons? }). Default buttons are Yes (1) / No (0).
// Esc / backdrop act as Cancel -- for the default pair that is 0 (No); when
// custom buttons are supplied, the button with id "cancel" if present, else
// the last button's id.
//=============================================================================

var yesNo = (function() {
	var dialog, msgEl, btnHost, pending = null, cancelId = 0;

	function build() {
		dialog = document.createElement("dialog");
		dialog.className = "yn-dialog";
		dialog.innerHTML =
			'<div class="yn-panel">' +
				'<div class="yn-msg" role="heading" aria-level="1"></div>' +
				'<div class="yn-buttons"></div>' +
			'</div>';
		document.body.appendChild(dialog);
		msgEl = dialog.querySelector(".yn-msg");
		btnHost = dialog.querySelector(".yn-buttons");

		btnHost.onclick = function(e) {
			var b = e.target.closest("button");
			if(!b) return;
			var raw = b.getAttribute("data-pick");
			// numeric ids stay numbers (Yes/No); named ids stay strings
			choose(/^-?\d+$/.test(raw) ? +raw : raw);
		};

		dialog.addEventListener("cancel", function(e) {
			e.preventDefault();
			choose(cancelId);
		});

		dialog.addEventListener("click", function(e) {
			if(e.target === dialog) choose(cancelId);
		});

		dialog.addEventListener("close", function() {
			document.dispatchEvent(new CustomEvent("menu-close"));
		});
	}

	function choose(which) {
		if(!dialog || !dialog.open) return;
		var fn = pending; pending = null;
		dialog.close();
		if(fn) fn(which);
	}

	function escapeHtml(s) {
		return String(s)
			.replace(/&/g, "&amp;")
			.replace(/</g, "&lt;")
			.replace(/>/g, "&gt;")
			.replace(/"/g, "&quot;");
	}

	// open(opts):
	//   lines: string[]
	//   onPick: function(id)
	//   buttons?: [{ id, label, primary? }]  -- default Yes/No
	function open(opts) {
		if(!dialog) build();
		pending = opts.onPick || null;

		var lines = opts.lines || [];
		var html = "";
		for(var i = 0; i < lines.length; i++) {
			html += '<p class="yn-line' + (i === 0 ? " lead" : "") + '">' +
			        escapeHtml(lines[i]) + '</p>';
		}
		msgEl.innerHTML = html;

		var buttons = opts.buttons;
		if(!buttons || !buttons.length) {
			buttons = [
				{ id: 1, label: "Yes", primary: true },
				{ id: 0, label: "No" }
			];
		}
		cancelId = null;
		var btnHtml = "";
		for(var j = 0; j < buttons.length; j++) {
			var b = buttons[j];
			if(b.id === "cancel" || b.id === 0) cancelId = b.id;
			btnHtml += '<button type="button" class="yn-btn' +
				(b.primary ? " yn-yes" : "") +
				'" data-pick="' + escapeHtml(String(b.id)) + '">' +
				escapeHtml(b.label) + '</button>';
		}
		if(cancelId == null) cancelId = buttons[buttons.length - 1].id;
		btnHost.innerHTML = btnHtml;

		dialog.showModal();
		document.dispatchEvent(new CustomEvent("menu-open"));
		var focus = btnHost.querySelector(".yn-yes") || btnHost.querySelector("button");
		if(focus) focus.focus();
	}

	return { init: build, open: open };
})();

function yesNoDialog(lines, onPick) {
	yesNo.open({ lines: lines, onPick: onPick });
}
