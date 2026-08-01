//=============================================================================
// Level-select / restore thumbnails: flatten a char-map to one offscreen canvas
// (replaces CreateJS Container + cache per thumbnail).
//=============================================================================

/** Draw first frame of a SpriteSheet animation at (x,y) with scale. */
function drawSpriteAnimFrame(ctx, spriteSheet, animName, x, y, scaleX, scaleY)
{
	if (!spriteSheet || typeof spriteSheet.getAnimation !== "function") return;
	var anim = spriteSheet.getAnimation(animName);
	if (!anim || !anim.frames || !anim.frames.length) return;
	var frame = spriteSheet.getFrame(anim.frames[0]);
	if (!frame || !frame.image || !frame.rect) return;
	var r = frame.rect;
	ctx.drawImage(
		frame.image,
		r.x, r.y, r.width, r.height,
		x, y, r.width * scaleX, r.height * scaleY
	);
}

function drawThemeTileScaled(ctx, name, x, y, scaleX, scaleY)
{
	var img = getThemeBitmapImage(name);
	if (!img) return;
	var w = img.naturalWidth || img.width || BASE_TILE_X;
	var h = img.naturalHeight || img.height || BASE_TILE_Y;
	ctx.drawImage(img, x, y, w * scaleX, h * scaleY);
}

/**
 * Flatten a level char-map once to an HTMLCanvasElement (no CreateJS Container.cache).
 * Scan order matches select/restore thumbnails: bottom-right to top-left; keeps first
 * MAX_NEW_GUARD guards and first runner (differs from resolveLevelMap row-major culling).
 *
 * @param {string} levelMap
 * @param {number} scaleX
 * @param {number=} scaleY  defaults to scaleX
 * @param {number=} canvasW defaults to NO_OF_TILES_X * BASE_TILE_X * scaleX
 * @param {number=} canvasH defaults to NO_OF_TILES_Y * BASE_TILE_Y * scaleX
 * @returns {HTMLCanvasElement}
 */
function renderLevelMapToCanvas(levelMap, scaleX, scaleY, canvasW, canvasH)
{
	if (typeof scaleY === "undefined" || scaleY == null) scaleY = scaleX;
	if (typeof canvasW === "undefined" || canvasW == null)
		canvasW = NO_OF_TILES_X * BASE_TILE_X * scaleX;
	if (typeof canvasH === "undefined" || canvasH == null)
		canvasH = NO_OF_TILES_Y * BASE_TILE_Y * scaleX;

	var canvas = document.createElement("canvas");
	canvas.width = canvasW;
	canvas.height = canvasH;
	var ctx = canvas.getContext("2d");
	var guardCount = 0, runner = 0;

	var index = NO_OF_TILES_Y * NO_OF_TILES_X - 1;
	for (var y = NO_OF_TILES_Y - 1; y >= 0; y--) {
		for (var x = NO_OF_TILES_X - 1; x >= 0; x--) {
			var id = levelMap.charAt(index--);
			var dx = x * BASE_TILE_X * scaleX;
			// Match prior setTransform: Y position used scaleX even when scaleY differed.
			var dy = y * BASE_TILE_Y * scaleX;

			switch (id) {
			default:
			case " ":
				continue;
			case "#":
				drawThemeTileScaled(ctx, "brick", dx, dy, scaleX, scaleY);
				break;
			case "@":
				drawThemeTileScaled(ctx, "solid", dx, dy, scaleX, scaleY);
				break;
			case "H":
				drawThemeTileScaled(ctx, "ladder", dx, dy, scaleX, scaleY);
				break;
			case "-":
				drawThemeTileScaled(ctx, "rope", dx, dy, scaleX, scaleY);
				break;
			case "X":
				drawThemeTileScaled(ctx, "brick", dx, dy, scaleX, scaleY);
				break;
			case "S":
				continue;
			case "$":
				drawThemeTileScaled(ctx, "gold", dx, dy, scaleX, scaleY);
				break;
			case "0":
				if (++guardCount > MAX_NEW_GUARD) continue;
				drawSpriteAnimFrame(ctx, guardData, "runLeft", dx, dy, scaleX, scaleY);
				break;
			case "&":
				if (++runner > 1) continue;
				drawSpriteAnimFrame(ctx, runnerData, "runRight", dx, dy, scaleX, scaleY);
				break;
			}
		}
	}
	return canvas;
}

/** Same flatten, wrapped as a CanvasBitmap for callers that expect a paint object. */
function levelMapToBitmap(levelMap, scaleX, scaleY, canvasW, canvasH)
{
	return new CanvasBitmap(renderLevelMapToCanvas(levelMap, scaleX, scaleY, canvasW, canvasH));
}
