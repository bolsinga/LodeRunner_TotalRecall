//=============================================================================
// Owned Canvas2D display objects (replaces createjs display objects).
//
// Base contract: draw(ctx) renders at the local origin; getBounds() returns
// {x, y, width, height} in local units; contains(px, py) hit-tests a
// parent-space point. Objects never join a createjs display list -- they are
// painted by canvasOverlay as a pass after the stage repaints (stagePresent
// in lodeRunner.main.js); the same paint call later moves into the owned
// render loop unchanged.
//=============================================================================

function CanvasObject()
{
	this.x = 0;
	this.y = 0;
	this.scaleX = 1;
	this.scaleY = 1;
	this.alpha = 1;
	this.visible = true;
}

//subclass hook: render at the local origin
CanvasObject.prototype.draw = function(ctx) {};

//subclass hook: local-space bounds {x, y, width, height}
CanvasObject.prototype.getBounds = function() { return null; };

//hit-test a parent-space point against local bounds
CanvasObject.prototype.contains = function(px, py)
{
	var b = this.getBounds();
	if(!b || !this.scaleX || !this.scaleY) return false;
	var lx = (px - this.x) / this.scaleX;
	var ly = (py - this.y) / this.scaleY;
	return lx >= b.x && lx < b.x + b.width && ly >= b.y && ly < b.y + b.height;
};

//apply transform + alpha, then subclass draw
CanvasObject.prototype.paint = function(ctx)
{
	if(!this.visible || this.alpha <= 0) return;
	ctx.save();
	ctx.globalAlpha = this.alpha;
	ctx.translate(this.x, this.y);
	ctx.scale(this.scaleX, this.scaleY);
	this.draw(ctx);
	ctx.restore();
};

//=====================
// text display object
//=====================
function CanvasText(text, font, color)
{
	CanvasObject.call(this);
	this.text = text;
	this.font = font;   //canvas font string, e.g. "bold 48px Helvetica"
	this.color = color;
	this.textAlign = "left";
	this.shadow = null; //{color, offsetX, offsetY, blur}
}
CanvasText.prototype = Object.create(CanvasObject.prototype);
CanvasText.prototype.constructor = CanvasText;

CanvasText.prototype.setShadow = function(color, offsetX, offsetY, blur)
{
	this.shadow = {color:color, offsetX:offsetX, offsetY:offsetY, blur:blur};
	return this;
};

//shared scratch context for text measurement (created on first use)
CanvasText._measureCtx = null;

CanvasText.prototype.getBounds = function()
{
	var ctx = CanvasText._measureCtx;
	if(!ctx) ctx = CanvasText._measureCtx = document.createElement("canvas").getContext("2d");
	ctx.font = this.font;
	var m = ctx.measureText(this.text);
	//font line box when the browser reports it, ink box as fallback
	var ascent  = (m.fontBoundingBoxAscent  != null) ? m.fontBoundingBoxAscent  : m.actualBoundingBoxAscent;
	var descent = (m.fontBoundingBoxDescent != null) ? m.fontBoundingBoxDescent : m.actualBoundingBoxDescent;
	var x = 0;
	if(this.textAlign == "center") x = -m.width / 2;
	else if(this.textAlign == "right" || this.textAlign == "end") x = -m.width;
	return {x:x, y:0, width:m.width, height:ascent + descent};
};

CanvasText.prototype.draw = function(ctx)
{
	ctx.font = this.font;
	ctx.fillStyle = this.color;
	ctx.textAlign = this.textAlign;
	ctx.textBaseline = "top";
	if(this.shadow) {
		ctx.shadowColor = this.shadow.color;
		ctx.shadowOffsetX = this.shadow.offsetX;
		ctx.shadowOffsetY = this.shadow.offsetY;
		ctx.shadowBlur = this.shadow.blur;
	}
	ctx.fillText(this.text, 0, 0);
};

//======================
// vector shape object
//======================
// Retained-mode shape: record fill/stroke ops, replay them in draw(ctx).
// Covers the rects, rounded rects, and shadowed panels the score screen and
// editor drew with CreateJS Shape/Graphics.
function CanvasShape()
{
	CanvasObject.call(this);
	this.ops = [];      //recorded draw ops, replayed in order
	this.shadow = null; //{color, offsetX, offsetY, blur}
	this.bounds = null; //optional explicit local bounds for hit-testing
}
CanvasShape.prototype = Object.create(CanvasObject.prototype);
CanvasShape.prototype.constructor = CanvasShape;

CanvasShape.prototype.setShadow = function(color, offsetX, offsetY, blur)
{
	this.shadow = {color:color, offsetX:offsetX, offsetY:offsetY, blur:blur};
	return this;
};

CanvasShape.prototype.fillRect = function(color, x, y, w, h)
{
	this.ops.push({op:"fillRect", color:color, x:x, y:y, w:w, h:h});
	return this;
};

CanvasShape.prototype.fillRoundRect = function(color, x, y, w, h, r)
{
	this.ops.push({op:"fillRoundRect", color:color, x:x, y:y, w:w, h:h, r:r});
	return this;
};

CanvasShape.prototype.strokeRect = function(color, width, x, y, w, h)
{
	this.ops.push({op:"strokeRect", color:color, width:width, x:x, y:y, w:w, h:h});
	return this;
};

CanvasShape.prototype.getBounds = function() { return this.bounds; };

function pathRoundRect(ctx, x, y, w, h, r)
{
	if(ctx.roundRect) { ctx.beginPath(); ctx.roundRect(x, y, w, h, r); return; }
	ctx.beginPath();
	ctx.moveTo(x + r, y);
	ctx.arcTo(x + w, y, x + w, y + h, r);
	ctx.arcTo(x + w, y + h, x, y + h, r);
	ctx.arcTo(x, y + h, x, y, r);
	ctx.arcTo(x, y, x + w, y, r);
	ctx.closePath();
}

CanvasShape.prototype.draw = function(ctx)
{
	if(this.shadow) {
		ctx.shadowColor = this.shadow.color;
		ctx.shadowOffsetX = this.shadow.offsetX;
		ctx.shadowOffsetY = this.shadow.offsetY;
		ctx.shadowBlur = this.shadow.blur;
	}
	for(var i = 0; i < this.ops.length; i++) {
		var o = this.ops[i];
		if(o.op == "fillRect") {
			ctx.fillStyle = o.color;
			ctx.fillRect(o.x, o.y, o.w, o.h);
		} else if(o.op == "fillRoundRect") {
			ctx.fillStyle = o.color;
			pathRoundRect(ctx, o.x, o.y, o.w, o.h, o.r);
			ctx.fill();
		} else if(o.op == "strokeRect") {
			ctx.strokeStyle = o.color;
			ctx.lineWidth = o.width;
			ctx.strokeRect(o.x, o.y, o.w, o.h);
		}
	}
};

//=================================
// bitmap glyph atlas (text font)
//=================================
// Draws a string from the shared glyph atlas image (one glyph per grid cell),
// the owned replacement for the Sprite(textData, ...) glyphs the score
// screen builds. atlasImage + cell size + name->frame map are supplied by the
// caller (from preload's textData), so this class owns no game asset globals.
// A single-glyph, multi-frame instance (frames + speed) is the FLASH cursor.
function CanvasGlyph(atlas)
{
	CanvasObject.call(this);
	this.atlas = atlas;   //{image, cellW, cellH, cols, frameOf(name)}
	this.frames = [];     //atlas frame indices to draw in sequence (left to right)
	this.anim = null;     //{frames:[...], speed} for a cycling single-cell sprite
	this.frameElapsed = 0; //accumulated animation position (tick-driven)
}
CanvasGlyph.prototype = Object.create(CanvasObject.prototype);
CanvasGlyph.prototype.constructor = CanvasGlyph;

//set the glyph run from a string; numberType picks the N* or D* digit variant
CanvasGlyph.prototype.setText = function(text, numberType)
{
	this.frames = this.atlas.framesForText(text, numberType);
	return this;
};

//set a cycling single-cell animation (FLASH cursor); advance() drives it
CanvasGlyph.prototype.setAnim = function(frames, speed)
{
	this.anim = {frames:frames, speed:speed};
	this.frameElapsed = 0;
	return this;
};

// advance the animation by one tick (tick-driven, not wall-clock, so the blink
// cadence rides the game clock; a new loop would change only the caller)
CanvasGlyph.prototype.advance = function()
{
	if(this.anim) this.frameElapsed += this.anim.speed;
};

CanvasGlyph.prototype.getBounds = function()
{
	var n = this.anim ? 1 : this.frames.length;
	return {x:0, y:0, width:n * this.atlas.cellW, height:this.atlas.cellH};
};

CanvasGlyph.prototype.draw = function(ctx)
{
	var a = this.atlas, cw = a.cellW, ch = a.cellH;
	if(this.anim) {
		var seq = this.anim.frames;
		var idx = seq[(this.frameElapsed | 0) % seq.length];
		this.drawFrame(ctx, idx, 0);
		return;
	}
	for(var i = 0; i < this.frames.length; i++) this.drawFrame(ctx, this.frames[i], i * cw);
};

CanvasGlyph.prototype.drawFrame = function(ctx, frame, dx)
{
	var a = this.atlas, cw = a.cellW, ch = a.cellH;
	var sx = (frame % a.cols) * cw;
	var sy = (frame / a.cols | 0) * ch;
	ctx.drawImage(a.image, sx, sy, cw, ch, dx, 0, cw, ch);
};

//=================
// bitmap object
//=================
// Draws a whole image at the local origin (optionally a sub-rect). Replaces the
// CreateJS Bitmap tiles the score screen placed on its stage.
function CanvasBitmap(image)
{
	CanvasObject.call(this);
	this.image = image;
	this.srcRect = null; //optional {x, y, width, height} into image
}
CanvasBitmap.prototype = Object.create(CanvasObject.prototype);
CanvasBitmap.prototype.constructor = CanvasBitmap;

CanvasBitmap.prototype.getBounds = function()
{
	if(this.srcRect) return {x:0, y:0, width:this.srcRect.width, height:this.srcRect.height};
	if(!this.image) return null;
	return {x:0, y:0, width:this.image.naturalWidth || this.image.width,
	                  height:this.image.naturalHeight || this.image.height};
};

CanvasBitmap.prototype.draw = function(ctx)
{
	if(!this.image) return;
	var r = this.srcRect;
	if(r) ctx.drawImage(this.image, r.x, r.y, r.width, r.height, 0, 0, r.width, r.height);
	else ctx.drawImage(this.image, 0, 0);
};

//==========================================================================
// overlay of owned objects, painted last each frame (topmost by design).
// add/remove replace stage addChild/removeChild; content is transient
// screen dressing, cleared when the world is rebuilt (new level / cover).
//==========================================================================
var canvasOverlay = {
	objs: [],
	add: function(obj)
	{
		this.remove(obj);
		this.objs.push(obj);
	},
	remove: function(obj)
	{
		var i = this.objs.indexOf(obj);
		if(i >= 0) this.objs.splice(i, 1);
	},
	clear: function()
	{
		this.objs.length = 0;
	},
	paint: function(ctx)
	{
		if(!this.objs.length) return;
		// paint from a clean base state so objects never inherit a transform or
		// alpha left on the shared 2D context by the stage's last draw.
		// Objects author in buffer-pixel space, so identity is the base; if
		// authoring moves to base units under a tileScale/DPR transform, this
		// seam applies that transform instead of identity.
		ctx.save();
		ctx.setTransform(1, 0, 0, 1, 0, 0);
		ctx.globalAlpha = 1;
		for(var i = 0; i < this.objs.length; i++) this.objs[i].paint(ctx);
		ctx.restore();
	}
};
