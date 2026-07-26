//=============================================================================
// Web Audio sound layer (CreateJS SoundJS replacement).
// Supports: one-shot play/stop by id, persistent instances (play/stop/pause/
// resume/getDuration), ogg to mp3 fallback, Chrome autoplay resume.
//=============================================================================

var _audioCtx = null;
var _scratchBuffer = null;
var _soundBuffers = {}; // id -> AudioBuffer
var _oneShotSources = {}; // id -> active BufferSourceNode[]

/**
 * Playback AudioContext. SoundJS creates this eagerly and decodes on it
 * (WebAudioLoader to context.decodeAudioData); that can hang under modern
 * autoplay suspension, so we only use this context for playback.
 * See CreateJS/SoundJS WebAudioPlugin.js / WebAudioLoader.js.
 */
function getAudioContext()
{
	if (!_audioCtx) {
		var AC = window.AudioContext || window.webkitAudioContext;
		_audioCtx = new AC();
		// iOS first-boot garbled-audio workaround (SoundJS WebAudioPlugin._createAudioContext)
		var ua = (typeof navigator !== "undefined" && navigator.userAgent) ? navigator.userAgent : "";
		if (/(iPhone|iPad)/i.test(ua) && _audioCtx.sampleRate !== 44100) {
			var dummy = _audioCtx.createBufferSource();
			dummy.buffer = _audioCtx.createBuffer(1, 1, 44100);
			dummy.connect(_audioCtx.destination);
			try { dummy.start(0); } catch (e) {}
			try { dummy.disconnect(); } catch (e2) {}
			try { _audioCtx.close(); } catch (e3) {}
			_audioCtx = new AC();
		}
		_scratchBuffer = _audioCtx.createBuffer(1, 1, 22050);
	}
	return _audioCtx;
}

/** SoundJS WebAudioPlugin.playEmptySound - required to unlock iOS Web Audio. */
function _playEmptySound()
{
	var ctx = getAudioContext();
	if (!_scratchBuffer) _scratchBuffer = ctx.createBuffer(1, 1, 22050);
	var source = ctx.createBufferSource();
	source.buffer = _scratchBuffer;
	source.connect(ctx.destination);
	try { source.start(0, 0, 0); } catch (e) {}
}

/** Map foo.ogg(?query) to foo.mp3(?query) for Safari / alternateExtensions. */
function soundAlternateUrl(src)
{
	return String(src).replace(/\.ogg(\?|$)/i, ".mp3$1");
}

/**
 * Decode with OfflineAudioContext so boot-time load is not blocked by
 * autoplay policy (a suspended AudioContext can leave decodeAudioData pending forever).
 */
function _decodeAudioData(arrayBuffer)
{
	var Offline = window.OfflineAudioContext || window.webkitOfflineAudioContext;
	var offline = new Offline(1, 1, 44100);
	var copy = arrayBuffer.slice(0);
	return new Promise(function (resolve, reject) {
		offline.decodeAudioData(
			copy,
			function (buf) { resolve(buf); },
			function (err) { reject(err || new Error("decodeAudioData failed")); }
		);
	});
}

function _fetchArrayBuffer(url)
{
	return fetch(url).then(function (res) {
		if (!res.ok) throw new Error("sound fetch failed: " + url + " (" + res.status + ")");
		return res.arrayBuffer();
	});
}

/**
 * Fetch + decode one sound; try .ogg then .mp3 (SoundJS alternateExtensions).
 * @returns {Promise<AudioBuffer>}
 */
function soundFetchDecode(src)
{
	var urls = [src];
	var alt = soundAlternateUrl(src);
	if (alt !== src) urls.push(alt);

	var i = 0;
	function tryNext(err)
	{
		if (i >= urls.length) {
			return Promise.reject(err || new Error("sound load failed: " + src));
		}
		var url = urls[i++];
		return _fetchArrayBuffer(url).then(function (buf) {
			return _decodeAudioData(buf);
		}).catch(tryNext);
	}
	return tryNext();
}

/**
 * Load/register a list of {id, src} sound items.
 * @param {Array<{id:string, src:string}>} items
 * @param {function(number, number)=} onProgress (loadedCount, totalCount)
 * @returns {Promise<void>}
 */
function soundLoadManifest(items, onProgress)
{
	items = items || [];
	var total = items.length;
	var loaded = 0;
	if (onProgress) onProgress(0, total);
	if (!total) return Promise.resolve();

	return Promise.all(items.map(function (item) {
		return soundFetchDecode(item.src).then(function (buffer) {
			_soundBuffers[item.id] = buffer;
			loaded++;
			if (onProgress) onProgress(loaded, total);
		});
	})).then(function () {});
}

function soundRegisterBuffer(id, buffer)
{
	_soundBuffers[id] = buffer;
}

function soundHas(id)
{
	return !!_soundBuffers[id];
}

function _trackOneShot(id, source)
{
	if (!_oneShotSources[id]) _oneShotSources[id] = [];
	_oneShotSources[id].push(source);
	source.onended = function () {
		var list = _oneShotSources[id];
		if (!list) return;
		var idx = list.indexOf(source);
		if (idx >= 0) list.splice(idx, 1);
	};
}

function _stopSource(source)
{
	if (!source) return;
	try { source.onended = null; source.stop(0); } catch (e) { /* already stopped */ }
}

/** One-shot play by id (Sound.play). */
function soundPlayById(id)
{
	var buffer = _soundBuffers[id];
	if (!buffer) return null;
	var ctx = getAudioContext();
	var source = ctx.createBufferSource();
	source.buffer = buffer;
	source.connect(ctx.destination);
	_trackOneShot(id, source);
	try { source.start(0); } catch (e) { return null; }
	return source;
}

/** Stop all one-shots for id (Sound.stop). */
function soundStopById(id)
{
	var list = _oneShotSources[id];
	if (!list) return;
	for (var i = 0; i < list.length; i++) _stopSource(list[i]);
	_oneShotSources[id] = [];
}

/**
 * Persistent reusable instance (Sound.createInstance).
 * play() always restarts from the beginning after stop().
 */
function SoundInstance(id)
{
	this.id = id;
	this._source = null;
	this._startedAt = 0;
	this._pauseOffset = 0;
	this.paused = false;
}

SoundInstance.prototype.getDuration = function ()
{
	var buffer = _soundBuffers[this.id];
	return buffer ? (buffer.duration * 1000) : 0;
};

SoundInstance.prototype.stop = function ()
{
	_stopSource(this._source);
	this._source = null;
	this._pauseOffset = 0;
	this.paused = false;
};

SoundInstance.prototype.play = function ()
{
	this.stop();
	var buffer = _soundBuffers[this.id];
	if (!buffer) return;
	var ctx = getAudioContext();
	var source = ctx.createBufferSource();
	source.buffer = buffer;
	source.connect(ctx.destination);
	var self = this;
	source.onended = function () {
		if (self._source === source) self._source = null;
	};
	try { source.start(0, 0); } catch (e) { return; }
	this._source = source;
	this._startedAt = ctx.currentTime;
	this._pauseOffset = 0;
	this.paused = false;
};

SoundInstance.prototype.pause = function ()
{
	if (this.paused || !this._source) return;
	var ctx = getAudioContext();
	this._pauseOffset = Math.max(0, ctx.currentTime - this._startedAt);
	_stopSource(this._source);
	this._source = null;
	this.paused = true;
};

SoundInstance.prototype.resume = function ()
{
	if (!this.paused) return;
	var buffer = _soundBuffers[this.id];
	if (!buffer) { this.paused = false; return; }
	var ctx = getAudioContext();
	var offset = Math.min(this._pauseOffset, Math.max(0, buffer.duration - 0.01));
	var source = ctx.createBufferSource();
	source.buffer = buffer;
	source.connect(ctx.destination);
	var self = this;
	source.onended = function () {
		if (self._source === source) {
			self._source = null;
			self.paused = false;
			self._pauseOffset = 0;
		}
	};
	try { source.start(0, offset); } catch (e) { this.paused = false; return; }
	this._source = source;
	this._startedAt = ctx.currentTime - offset;
	this.paused = false;
};

function soundCreateInstance(id)
{
	return new SoundInstance(id);
}

/**
 * Resume / unlock Web Audio after a user gesture.
 * Combines Chrome autoplay resume with SoundJS iOS unlock
 * (WebAudioPlugin._unlock to playEmptySound on touch/click).
 * https://developers.google.com/web/updates/2017/09/autoplay-policy-changes
 */
function resumeAudioContext()
{
	try {
		var ctx = getAudioContext();
		_playEmptySound();
		if (ctx.state === "suspended") ctx.resume();
	} catch (e) {
		console.error("There was an error while trying to resume the Web Audio context...");
		console.error(e);
	}
}

//=============================================================================
// One-time audio unlock.
//
// Browsers create the AudioContext suspended until the page sees a user
// gesture. Rather than have every path that might follow a gesture remember to
// unlock (which it will eventually forget to do), listen on the document and
// unlock on whatever gesture arrives first.
//
// Keep listening until the context is actually running. Not every gesture
// qualifies -- a bare modifier key (Ctrl on its own) is rejected -- and
// unbinding on a rejected attempt would leave the game silent for good.
//
// The listeners do not consume the event -- they observe it and get out of the
// way, so the click or key still reaches whatever it was aimed at.
//
// _playEmptySound stays: on iOS, resume() alone does not unlock Web Audio,
// which is why every audio library plays a silent buffer on the first gesture.
//=============================================================================
var UNLOCK_EVENTS = ["pointerdown", "touchend", "keydown"];

function initAudioUnlock()
{
	function stopListening() {
		for (var i = 0; i < UNLOCK_EVENTS.length; i++)
			document.removeEventListener(UNLOCK_EVENTS[i], unlock, true);
	}
	function unlock() {
		resumeAudioContext();
		var ctx = getAudioContext();
		if (ctx.state === "running") { stopListening(); return; }
		// resume() is async: unbind only once it has actually taken effect.
		if (ctx.state === "suspended" && ctx.resume) {
			ctx.resume().then(function() {
				if (getAudioContext().state === "running") stopListening();
			}, function() { /* rejected: keep listening for a real gesture */ });
		}
	}
	for (var i = 0; i < UNLOCK_EVENTS.length; i++)
		document.addEventListener(UNLOCK_EVENTS[i], unlock, true);
}
