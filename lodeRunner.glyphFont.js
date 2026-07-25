//=============================================================================
// Bitmap glyph font: single source of truth for the text atlas layout.
//
// The atlas is one image of fixed cells (BASE_TILE_X x BASE_TILE_Y). Each glyph
// name maps to a frame index; a string maps to a list of frame indices. This is
// the same mapping the createjs SpriteSheet "textData" and drawText() encode,
// pulled into one place so owned Canvas glyphs and the HUD agree on the font.
//=============================================================================

//glyph name -> atlas frame index (mirrors textData.animations, static cells only)
var GLYPH_FRAME = {
	N0:0, N1:1, N2:2, N3:3, N4:4, N5:5, N6:6, N7:7, N8:8, N9:9,
	A:10, B:11, C:12, D:13, E:14, F:15, G:16, H:17, I:18, J:19,
	K:20, L:21, M:22, N:23, O:24, P:25, Q:26, R:27, S:28, T:29,
	U:30, V:31, W:32, X:33, Y:34, Z:35,
	DOT:36, LT:37, GT:38, DASH:39,
	"@":40, "#":41, SPACE:43, COLON:44, UNDERLINE:45,
	D0:50, D1:51, D2:52, D3:53, D4:54, D5:55, D6:56, D7:57, D8:58, D9:59
};

//FLASH cursor: cycling cells + advance speed (frames added per tick)
var GLYPH_FLASH = { frames:[42, 42, 43, 43], speed:0.25 };

//one uppercase character -> glyph name; numberType ("N" default, "D" blue) picks
//the digit variant. Matches drawText()'s switch exactly.
function charToGlyphName(ch, numberType)
{
	if(!numberType) numberType = "N";
	var code = ch.charCodeAt(0);
	if(code >= 48 && code <= 57) return numberType + ch;      //0-9
	if(code >= 65 && code <= 90) return ch;                   //A-Z
	switch(code) {
	case 46: return "DOT";       // .
	case 60: return "LT";        // <
	case 62: return "GT";        // >
	case 45: return "DASH";      // -
	case 58: return "COLON";     // :
	case 95: return "UNDERLINE"; // _
	case 35: return "#";         // guard dead in trap hole
	case 64: return "@";         // gold
	default: return "SPACE";
	}
}

//frame index list for a string (upper-cased first, like drawText)
function glyphFramesForText(text, numberType)
{
	var s = String(text).toUpperCase();
	var out = [];
	for(var i = 0; i < s.length; i++) out.push(GLYPH_FRAME[charToGlyphName(s.charAt(i), numberType)]);
	return out;
}

//atlas descriptor consumed by CanvasGlyph: image + cell geometry + text mapping
function makeGlyphAtlas(image, cellW, cellH)
{
	var cols = Math.max(1, (image.naturalWidth || image.width) / cellW | 0);
	return {
		image: image,
		cellW: cellW,
		cellH: cellH,
		cols: cols,
		frameOf: function(name) { return GLYPH_FRAME[name]; },
		framesForText: function(text, numberType) { return glyphFramesForText(text, numberType); }
	};
}
