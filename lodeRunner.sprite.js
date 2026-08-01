//=============================================================================
// Owned SpriteSheet + Sprite (Phase 2/3).
//
// Drop-in replacements for EaselJS SpriteSheet / Sprite with the same
// animation table format and tick advance rules as EaselJS 0.7.1 (framerate 0
// => advance `speed` frames per tick). GameSprite extends CanvasObject and is
// painted via worldDisplay (not the CreateJS Stage).
//=============================================================================

/**
 * Build a plain sprite sheet from an EaselJS-style definition:
 *   { images: [img], frames: {width,height,regX,regY} | [[x,y,w,h],...],
 *     animations: { name: number | [start,end,next,speed] | {frames,next,speed} },
 *     framerate?: number }
 */
function makeSpriteSheet(def)
{
	var images = def.images || [];
	var frames = [];
	var framerate = def.framerate || 0;
	var data = {};
	var animNames = [];

	if (def.frames instanceof Array) {
		for (var i = 0; i < def.frames.length; i++) {
			var h = def.frames[i];
			frames.push({
				image: images[h[4] ? h[4] : 0],
				rect: { x: h[0], y: h[1], width: h[2], height: h[3] },
				regX: h[5] || 0,
				regY: h[6] || 0
			});
		}
	} else if (def.frames) {
		var d = def.frames;
		var fw = d.width, fh = d.height;
		var rx = d.regX || 0, ry = d.regY || 0;
		var numFrames = d.count || 0;
		var a = 0;
		for (var di = 0; di < images.length; di++) {
			var img = images[di];
			var cols = (img.width / fw) | 0;
			var rows = (img.height / fh) | 0;
			var n = numFrames > 0 ? Math.min(numFrames - a, cols * rows) : cols * rows;
			for (var j = 0; j < n; j++) {
				frames.push({
					image: img,
					rect: { x: (j % cols) * fw, y: ((j / cols) | 0) * fh, width: fw, height: fh },
					regX: rx,
					regY: ry
				});
			}
			a += n;
		}
	}

	if (def.animations) {
		for (var name in def.animations) {
			if (!def.animations.hasOwnProperty(name)) continue;
			var jAnim = { name: name };
			var k = def.animations[name];
			var e;
			if (typeof k === "number") {
				e = jAnim.frames = [k];
			} else if (k instanceof Array) {
				if (k.length === 1) {
					jAnim.frames = [k[0]];
					e = jAnim.frames;
				} else {
					jAnim.speed = k[3];
					jAnim.next = k[2];
					e = jAnim.frames = [];
					for (var b = k[0]; b <= k[1]; b++) e.push(b);
				}
			} else {
				jAnim.speed = k.speed;
				jAnim.next = k.next;
				var l = k.frames;
				e = jAnim.frames = (typeof l === "number") ? [l] : l.slice(0);
			}
			if (jAnim.next === true || jAnim.next === undefined) jAnim.next = name;
			if (jAnim.next === false || (e.length < 2 && jAnim.next === name)) jAnim.next = null;
			if (!jAnim.speed) jAnim.speed = 1;
			animNames.push(name);
			data[name] = jAnim;
		}
	}

	return {
		framerate: framerate,
		complete: true,
		_frames: frames,
		_data: data,
		_animations: animNames,
		getAnimation: function (animName) { return this._data[animName]; },
		getFrame: function (idx) {
			return (this._frames && this._frames[idx]) ? this._frames[idx] : null;
		},
		getNumFrames: function (animName) {
			if (animName == null) return this._frames ? this._frames.length : 0;
			var anim = this._data[animName];
			return anim ? anim.frames.length : 0;
		}
	};
}

/**
 * Animated bitmap driven by a makeSpriteSheet() sheet.
 * API: gotoAndPlay/Stop, play/stop, paused, currentAnimation/Frame, spriteSheet,
 * advance(delta), animationend listeners, setTransform/set, draw via CanvasObject.
 */
function GameSprite(spriteSheet, frameOrAnimation)
{
	CanvasObject.call(this);

	this.paused = true;
	this.currentAnimation = null;
	this.currentAnimationFrame = 0;
	this.currentFrame = 0;
	this.framerate = 0;
	this.image = null;
	this.sourceRect = null;
	this._animation = null;
	this._currentFrame = 0;
	this._spriteSheet = null;
	this._listeners = {};

	if (spriteSheet) this.spriteSheet = spriteSheet;
	if (frameOrAnimation != null) this.gotoAndPlay(frameOrAnimation);
}

GameSprite.prototype = Object.create(CanvasObject.prototype);
GameSprite.prototype.constructor = GameSprite;

Object.defineProperty(GameSprite.prototype, "spriteSheet", {
	get: function () { return this._spriteSheet; },
	set: function (sheet) {
		this._spriteSheet = sheet;
		this._applyFrame();
	}
});

GameSprite.prototype.play = function () { this.paused = false; };
GameSprite.prototype.stop = function () { this.paused = true; };

GameSprite.prototype.gotoAndPlay = function (frameOrAnimation) {
	this.paused = false;
	this._goto(frameOrAnimation);
};

GameSprite.prototype.gotoAndStop = function (frameOrAnimation) {
	this.paused = true;
	this._goto(frameOrAnimation);
};

GameSprite.prototype.advance = function (delta) {
	var speed = (this._animation && this._animation.speed) || 1;
	var framerate = this.framerate || (this._spriteSheet && this._spriteSheet.framerate) || 0;
	var d = framerate && delta != null ? delta / (1000 / framerate) : 1;
	if (this._animation) this.currentAnimationFrame += d * speed;
	else this._currentFrame += d * speed;
	this._normalizeFrame();
};

GameSprite.prototype.addEventListener = function (type, fn) {
	if (!this._listeners[type]) this._listeners[type] = [];
	var list = this._listeners[type];
	if (list.indexOf(fn) < 0) list.push(fn);
	return fn;
};

GameSprite.prototype.removeEventListener = function (type, fn) {
	var list = this._listeners[type];
	if (!list) return;
	var i = list.indexOf(fn);
	if (i >= 0) list.splice(i, 1);
};

GameSprite.prototype.removeAllEventListeners = function (type) {
	if (type == null) this._listeners = {};
	else delete this._listeners[type];
};

GameSprite.prototype.hasEventListener = function (type) {
	var list = this._listeners[type];
	return !!(list && list.length);
};

GameSprite.prototype.dispatchEvent = function (evt) {
	var list = this._listeners[evt.type];
	if (!list || !list.length) return false;
	evt.target = this;
	list = list.slice();
	for (var i = 0; i < list.length; i++) list[i].call(this, evt);
	return true;
};

GameSprite.prototype._goto = function (frameOrAnimation, frameOffset) {
	if (isNaN(frameOrAnimation)) {
		var anim = this._spriteSheet && this._spriteSheet.getAnimation(frameOrAnimation);
		if (anim) {
			this.currentAnimationFrame = frameOffset || 0;
			this._animation = anim;
			this.currentAnimation = frameOrAnimation;
			this._normalizeFrame();
		}
	} else {
		this.currentAnimationFrame = 0;
		this.currentAnimation = this._animation = null;
		this._currentFrame = frameOrAnimation;
		this._normalizeFrame();
	}
};

GameSprite.prototype._normalizeFrame = function () {
	var anim = this._animation;
	var wasPaused = this.paused;
	var wasFrame = this._currentFrame;
	var animFrame = this.currentAnimationFrame;

	if (anim) {
		var len = anim.frames.length;
		if ((animFrame | 0) >= len) {
			var next = anim.next;
			if (this._dispatchAnimationEnd(anim, wasFrame, wasPaused, next, len - 1)) {
				// listener changed state; stop further updates
			} else if (next) {
				return this._goto(next, animFrame - len);
			} else {
				this.paused = true;
				animFrame = this.currentAnimationFrame = anim.frames.length - 1;
				this._currentFrame = anim.frames[animFrame];
			}
		} else {
			this._currentFrame = anim.frames[animFrame | 0];
		}
	} else {
		var n = this._spriteSheet ? this._spriteSheet.getNumFrames() : 0;
		if (wasFrame >= n && n > 0) {
			if (!this._dispatchAnimationEnd(anim, wasFrame, wasPaused, null, n - 1)) {
				if ((this._currentFrame -= n) >= n) return this._normalizeFrame();
			}
		}
	}
	this.currentFrame = this._currentFrame | 0;
	this._applyFrame();
};

GameSprite.prototype._dispatchAnimationEnd = function (anim, frame, wasPaused, next, endFrame) {
	var name = anim ? anim.name : null;
	if (this.hasEventListener("animationend")) {
		this.dispatchEvent({ type: "animationend", name: name, next: next });
	}
	var changed = this._animation != anim || this._currentFrame != frame;
	if (!changed && !wasPaused && this.paused) {
		this.currentAnimationFrame = endFrame;
		changed = true;
	}
	return changed;
};

GameSprite.prototype._applyFrame = function () {
	if (!this._spriteSheet) return;
	var frame = this._spriteSheet.getFrame(this.currentFrame | 0);
	if (!frame) return;
	this.image = frame.image;
	var r = frame.rect;
	this.sourceRect = { x: r.x, y: r.y, width: r.width, height: r.height };
	this.regX = frame.regX || 0;
	this.regY = frame.regY || 0;
};

GameSprite.prototype.getBounds = function () {
	if (this.sourceRect) {
		return { x: 0, y: 0, width: this.sourceRect.width, height: this.sourceRect.height };
	}
	return null;
};

GameSprite.prototype.draw = function (ctx) {
	if (!this.image || !this.sourceRect) return;
	var r = this.sourceRect;
	ctx.drawImage(this.image, r.x, r.y, r.width, r.height, 0, 0, r.width, r.height);
};
