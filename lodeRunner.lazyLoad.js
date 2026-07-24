//=============================================================================
// On-demand script loader for level packs and demo replay packs.
// Keeps non-classic level/demo data off the initial page load.
//=============================================================================

var _lazyScript = {}; // src -> { loaded: 0|1, callbacks: [] }

//load a script url once; callback always runs (even on error)
//concurrent requests for the same src share one script tag
function loadScriptOnce(src, callback)
{
	var state = _lazyScript[src];
	if (state) {
		if (state.loaded) {
			if (callback) callback();
		} else {
			if (callback) state.callbacks.push(callback); //load in flight
		}
		return;
	}
	state = _lazyScript[src] = { loaded: 0, callbacks: callback ? [callback] : [] };

	var script = document.createElement("script");
	script.src = src;
	script.onload = function () {
		state.loaded = 1;
		var cbs = state.callbacks;
		state.callbacks = [];
		for (var i = 0; i < cbs.length; i++) cbs[i]();
	};
	script.onerror = function () {
		error("Failed to load script: " + src);
		var cbs = state.callbacks;
		delete _lazyScript[src]; //allow retry on a later request
		for (var i = 0; i < cbs.length; i++) cbs[i]();
	};
	document.head.appendChild(script);
}

//load many scripts in parallel; callback when all finish
function loadScriptsParallel(srcs, callback)
{
	if (!srcs || srcs.length === 0) {
		if (callback) callback();
		return;
	}
	var remaining = srcs.length;
	function oneDone()
	{
		if (--remaining <= 0 && callback) callback();
	}
	for (var i = 0; i < srcs.length; i++) {
		loadScriptOnce(srcs[i], oneDone);
	}
}

//mark a script already present (e.g. classic pack in lodeRunner.html)
function markScriptLoaded(src)
{
	_lazyScript[src] = { loaded: 1, callbacks: [] };
}
