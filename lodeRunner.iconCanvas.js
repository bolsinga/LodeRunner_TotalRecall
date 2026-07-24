//=============================================================================
// Side-chrome icon canvases (CreateJS Stage/Container/Shape replacement for icons).
// Draws hover fill + bitmap(s); mouse via DOM on the canvas (replaces enableMouseOver).
// Still accepts createjs.Bitmap from preload via .image / getBounds().
//=============================================================================

/** Natural pixel size of a createjs.Bitmap or HTMLImageElement. */
function iconBitmapNaturalSize(bitmap)
{
	if (bitmap && typeof bitmap.getBounds === "function") {
		var b = bitmap.getBounds();
		if (b) return { width: b.width, height: b.height };
	}
	var img = iconBitmapImage(bitmap);
	return {
		width: (img && (img.naturalWidth || img.width)) || 0,
		height: (img && (img.naturalHeight || img.height)) || 0
	};
}

function iconBitmapImage(bitmap)
{
	if (!bitmap) return null;
	if (bitmap.image) return bitmap.image;
	return bitmap;
}

/**
 * @param {object} opts
 * @param {string} opts.id
 * @param {number} opts.width
 * @param {number} opts.height
 * @param {number} opts.left
 * @param {number} opts.top
 * @param {number} opts.border
 * @param {number} opts.scale
 * @param {string=} opts.hoverFill  fill when hovered (default mouseOverBGColor)
 * @param {string=} opts.baseFill   always-drawn fill (theme icon uses page background)
 * @param {boolean=} opts.append    append to document.body (default true)
 */
function createIconCanvas(opts)
{
	var canvas = document.createElement("canvas");
	canvas.id = opts.id;
	canvas.width = opts.width;
	canvas.height = opts.height;
	canvas.style.left = opts.left + "px";
	canvas.style.top = opts.top + "px";
	canvas.style.position = "absolute";
	if (opts.append !== false) document.body.appendChild(canvas);

	var ctx = canvas.getContext("2d");
	var border = opts.border;
	var scale = opts.scale;
	var hoverFill = (opts.hoverFill != null) ? opts.hoverFill : mouseOverBGColor;
	var baseFill = opts.baseFill || null;
	var alpha = 0;
	var hovered = false;
	var bitmap = null;
	var handlers = null;
	var listening = false;

	function redraw()
	{
		ctx.clearRect(0, 0, canvas.width, canvas.height);
		ctx.globalAlpha = alpha;
		if (baseFill) {
			ctx.fillStyle = baseFill;
			ctx.fillRect(0, 0, canvas.width, canvas.height);
		}
		if (hovered && hoverFill) {
			ctx.fillStyle = hoverFill;
			ctx.fillRect(0, 0, canvas.width, canvas.height);
		}
		var img = iconBitmapImage(bitmap);
		if (img) {
			var nat = iconBitmapNaturalSize(bitmap);
			ctx.drawImage(img, border, border, nat.width * scale, nat.height * scale);
		}
		ctx.globalAlpha = 1;
	}

	function onOver(e)
	{
		if (handlers && handlers.over) handlers.over(e);
	}
	function onOut(e)
	{
		if (handlers && handlers.out) handlers.out(e);
	}
	function onClick(e)
	{
		if (handlers && handlers.click) handlers.click(e);
	}

	return {
		canvas: canvas,
		redraw: redraw,
		setAlpha: function (a) {
			alpha = a;
			redraw();
		},
		setHovered: function (on) {
			hovered = !!on;
			redraw();
		},
		setCursor: function (c) {
			canvas.style.cursor = c || "default";
		},
		setBitmap: function (bmp) {
			bitmap = bmp;
			redraw();
		},
		setBaseFill: function (c) {
			baseFill = c;
			redraw();
		},
		setHoverFill: function (c) {
			hoverFill = c;
			redraw();
		},
		enablePointer: function (h) {
			handlers = h || null;
			if (listening || !handlers) return;
			canvas.addEventListener("mouseover", onOver);
			canvas.addEventListener("mouseout", onOut);
			canvas.addEventListener("click", onClick);
			listening = true;
		},
		disablePointer: function () {
			if (!listening) return;
			canvas.removeEventListener("mouseover", onOver);
			canvas.removeEventListener("mouseout", onOut);
			canvas.removeEventListener("click", onClick);
			listening = false;
			canvas.style.cursor = "default";
		},
		bringToFront: function () {
			document.body.appendChild(canvas);
		}
	};
}
