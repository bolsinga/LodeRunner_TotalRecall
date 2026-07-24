//=============================================================================
// Image/cursor asset cache (CreateJS PreloadJS LoadQueue replacement).
// Mirrors the PreloadJS surface this game uses:
//   loadManifest([{id, src}, ...])->  HTMLImageElement in getResult(id)
//   progress by item count (loaded/total), optional per-file callback
// See CreateJS/PreloadJS LoadQueue.getResult / ImageLoader._formatImage.
//=============================================================================

var _assetResults = {}; // id -> HTMLImageElement (or null for warm-cache-only)

/** Drop-in for createjs.LoadQueue#getResult(id). */
function assetGetResult(id)
{
	return _assetResults[id];
}

/** Compatibility shim so existing preload.getResult(...) call sites keep working. */
var preload = {
	getResult: assetGetResult
};

function isCursorAssetSrc(src)
{
	return /\.cur(\?|$)/i.test(String(src));
}

/**
 * Load one image to an HTMLImageElement (same result type as PreloadJS ImageLoader).
 * Uses decode() when available so pixels are ready before Bitmap/SpriteSheet use.
 */
function assetLoadImage(src)
{
	return new Promise(function (resolve, reject) {
		var img = new Image();
		img.onload = function () {
			if (typeof img.decode === "function") {
				img.decode().then(function () { resolve(img); }).catch(function () { resolve(img); });
			} else {
				resolve(img);
			}
		};
		img.onerror = function () {
			reject(new Error("image load failed: " + src));
		};
		img.src = src;
	});
}

/** Warm-cache .cur files (never read via getResult in this game). */
function assetWarmCache(src)
{
	return fetch(src).then(function (res) {
		if (!res.ok) throw new Error("asset fetch failed: " + src + " (" + res.status + ")");
		return null;
	});
}

function assetLoadOne(item)
{
	if (isCursorAssetSrc(item.src)) {
		return assetWarmCache(item.src).then(function () {
			_assetResults[item.id] = null;
			return null;
		});
	}
	return assetLoadImage(item.src).then(function (img) {
		_assetResults[item.id] = img;
		return img;
	});
}

/**
 * Load a list of {id, src} items (re-enterable; merges into the same cache).
 * @param {Array<{id:string, src:string}>} items
 * @param {{onProgress?:function(number,number), onFileLoad?:function({item, result}), onError?:function(*)}}= handlers
 * @returns {Promise<void>}
 */
function assetLoadManifest(items, handlers)
{
	handlers = handlers || {};
	items = items || [];
	var total = items.length;
	var loaded = 0;
	if (handlers.onProgress) handlers.onProgress(0, total);
	if (!total) return Promise.resolve();

	return Promise.all(items.map(function (item) {
		return assetLoadOne(item).then(function (result) {
			loaded++;
			if (handlers.onFileLoad) handlers.onFileLoad({ item: item, result: result });
			if (handlers.onProgress) handlers.onProgress(loaded, total);
		}).catch(function (err) {
			// PreloadJS default: log and continue so the queue can still complete.
			loaded++;
			if (handlers.onError) handlers.onError(err);
			else console.log("error", err);
			if (handlers.onProgress) handlers.onProgress(loaded, total);
		});
	})).then(function () {});
}
