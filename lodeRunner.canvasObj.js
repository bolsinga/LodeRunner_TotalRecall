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
		//paint from a clean base state so objects never inherit a transform or
		//alpha left on the shared 2D context by the stage's last draw.
		//Objects currently author in buffer-pixel space, so identity is the base;
		//when Phase 3 moves authoring to base units under a tileScale/DPR
		//transform, this seam applies that transform instead of identity.
		ctx.save();
		ctx.setTransform(1, 0, 0, 1, 0, 0);
		ctx.globalAlpha = 1;
		for(var i = 0; i < this.objs.length; i++) this.objs[i].paint(ctx);
		ctx.restore();
	}
};
