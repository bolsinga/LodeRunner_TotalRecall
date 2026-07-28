//=============================================================================
// Custom-level Import / Export.
//
// No custom file chrome -- Export opens a system save (or download fallback),
// Import opens a system open-file picker. When custom levels already exist,
// Import offers Overwrite / Merge / Cancel via yesNo.
//=============================================================================

var customLevels = (function() {
	var fileInput = null;

	function tip(msg, ms) {
		setTimeout(function() { showTipsText(msg, ms || 2500); }, 50);
	}

	function exportFileName(d) {
		return 'LR' +
			('0' + (d.getMonth() + 1)).slice(-2) +
			('0' + d.getDate()).slice(-2) +
			('0' + d.getFullYear()).slice(-2) + '-' +
			('0' + d.getHours()).slice(-2) +
			('0' + d.getMinutes()).slice(-2) +
			('0' + d.getSeconds()).slice(-2) + '-' +
			('00' + editLevels).slice(-3) + '.lrwg';
	}

	function downloadText(filename, text) {
		var el = document.createElement('a');
		el.setAttribute('href', 'data:text/plain;charset=utf-8,' + encodeURIComponent(text));
		el.setAttribute('download', filename);
		el.style.display = 'none';
		document.body.appendChild(el);
		el.click();
		document.body.removeChild(el);
	}

	function saveTextFile(filename, text, done) {
		if(window.showSaveFilePicker) {
			window.showSaveFilePicker({
				suggestedName: filename,
				types: [{
					description: "Lode Runner levels",
					accept: { "text/plain": [".lrwg"] }
				}]
			}).then(function(handle) {
				return handle.createWritable().then(function(w) {
					return w.write(text).then(function() { return w.close(); });
				});
			}).then(function() {
				done(true);
			}).catch(function(err) {
				if(err && err.name === "AbortError") { done(false); return; }
				downloadText(filename, text);
				done(true);
			});
			return;
		}
		downloadText(filename, text);
		done(true);
	}

	function exportCustomLevels() {
		getEditLevelInfo();
		if(editLevels <= 0) {
			tip("NOTHING TO EXPORT", 2000);
			return;
		}
		var date = new Date();
		var name = exportFileName(date);
		var body = backupCustomLevelData(date);
		saveTextFile(name, body, function(ok) {
			if(ok) tip("EXPORT IS COMPLETE");
		});
	}

	function ensureFileInput() {
		if(fileInput) return fileInput;
		fileInput = document.createElement("input");
		fileInput.type = "file";
		fileInput.accept = ".lrwg";
		fileInput.style.display = "none";
		document.body.appendChild(fileInput);
		fileInput.addEventListener("change", onFilePicked);
		return fileInput;
	}

	function onFilePicked(e) {
		var file = e.target.files && e.target.files[0];
		e.target.value = ""; // reset after capturing the File (FileList is live)
		if(!file) return;
		var reader = new FileReader();
		reader.onloadend = function(ev) {
			if(ev.target.readyState != FileReader.DONE) return;
			var parsed = parseLrwgFile(ev.target.result, file.size);
			if(!parsed.ok) {
				debug(parsed.error);
				tip("WRONG FILE FORMAT", 2500);
				return;
			}
			offerImport(parsed.levels);
		};
		reader.readAsText(file);
	}

	function offerImport(levels) {
		getEditLevelInfo();
		if(editLevels <= 0) {
			applyImport(levels, "overwrite");
			return;
		}
		yesNo.open({
			lines: ["Custom levels already exist", "Overwrite, merge, or cancel?"],
			buttons: [
				{ id: "overwrite", label: "Overwrite", primary: true },
				{ id: "merge", label: "Merge" },
				{ id: "cancel", label: "Cancel" }
			],
			onPick: function(choice) {
				if(choice === "cancel") return;
				applyImport(levels, choice);
			}
		});
	}

	function applyImport(levels, mode) {
		var tmpTestInfo = { level: 1 };
		var oldEditLevels = editLevels;
		var skipped = 0;

		getTestLevel(tmpTestInfo);

		if(mode === "overwrite") {
			clearEditLevelInfo();
			clearStorage(STORAGE_MODERN_SCORE_INFO + PLAY_DATA_USERDEF);
			clearTestLevel();
			initEditLevelInfo();
			editLevelData = [];
			for(var i = 0; i < levels.length; i++)
				setEditLevel(++editLevels, levels[i]);
			setEditLevelInfo();
			if(tmpTestInfo.level > oldEditLevels &&
			   editLevels < MAX_EDIT_LEVEL &&
			   tmpTestInfo.levelMap &&
			   !levelMapIsEmpty(tmpTestInfo.levelMap)) {
				tmpTestInfo.level = editLevels + 1;
				setTestLevel(tmpTestInfo);
			}
		} else {
			// merge: append until capacity
			for(var j = 0; j < levels.length; j++) {
				if(editLevels >= MAX_EDIT_LEVEL) { skipped = levels.length - j; break; }
				setEditLevel(++editLevels, levels[j]);
			}
			setEditLevelInfo();
		}

		curLevel = 1;
		setModernInfo();
		if(playMode == PLAY_EDIT || playMode == PLAY_TEST) {
			editEdit(-1, null);
		} else {
			editPlay(-1, null);
		}

		if(skipped)
			tip("IMPORTED " + (levels.length - skipped) + ", SKIPPED " + skipped, 3000);
		else
			tip("IMPORT IS COMPLETE");
	}

	function importCustomLevels() {
		ensureFileInput().click();
	}

	function canExport() {
		getEditLevelInfo();
		return editLevels > 0;
	}

	return {
		export: exportCustomLevels,
		import: importCustomLevels,
		canExport: canExport
	};
})();

function exportCustomLevels() { customLevels.export(); }
function importCustomLevels() { customLevels.import(); }
