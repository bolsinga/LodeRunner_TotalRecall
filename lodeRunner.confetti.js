//=============================================================================
// DOM confetti -- reusable party-popper burst (no canvas, no third-party lib).
//
// Particles are plain <i> elements on a fixed overlay, animated with the Web
// Animations API along a ballistic arc (launch velocity + gravity), then
// removed when finished. Suited to DOM dialogs where a canvas overlay would
// be a second rendering world.
//
// Settings (all optional; defaults below):
//   origin / x,y / xFrac,yFrac  -- launch point
//   angle     -- launch direction in degrees (0 = right, 90 = up)
//   energy    -- launch vigour multiplier on base 420–780 px/s
//   size      -- flake size vs base w 6–12 / h 8–16
//   spread    -- cone width in degrees
//   count     -- how many flakes
//   mirror    -- reflect across the origin element (right twin of a left popper)
//
// xFrac / yFrac may be outside 0..1 to launch off the origin element's box.
// Left is the canonical side; mirror flips xFrac (1 - x) and angle (180 - a).
//
// Usage:
//   confetti.burst({
//     origin: dialogEl, xFrac: 0, yFrac: 1/3,
//     angle: 60, energy: 1.25, size: 0.30
//   });
//   confetti.burst({ ...settings, mirror: true });
//=============================================================================

var confetti = (function () {
	var COLORS = ["#e7c64a", "#b5533a", "#5a9fd4", "#d8d8e0", "#7ecf6a", "#c87ad4"];

	var DEFAULT_SIZE = 0.30;        // flake size vs base w 6–12 / h 8–16
	var DEFAULT_ENERGY = 1.25;      // multiplier on base launch speeds
	var BASE_SPEED_MIN = 420;       // px/s at energy 1.0
	var BASE_SPEED_MAX = 780;
	var DEFAULT_ANGLE = 60;
	var DEFAULT_SPREAD = 28;
	var DEFAULT_COUNT = 80;
	var STEPS = 12;                 // keyframe samples along the arc
	var GRAVITY = 1800;             // px/s^2, screen-y positive down

	var layer = null;
	var styleInjected = false;

	function ensureStyles() {
		if (styleInjected) return;
		styleInjected = true;
		var style = document.createElement("style");
		style.textContent =
			".confetti-layer{position:fixed;inset:0;overflow:hidden;" +
			"pointer-events:none;z-index:9999}" +
			".confetti-layer i{position:fixed;display:block;border-radius:1px;" +
			"will-change:transform,opacity}" +
			"@media (prefers-reduced-motion:reduce){.confetti-layer{display:none}}";
		document.head.appendChild(style);
	}

	// Modal <dialog> lives in the top layer; a body overlay would paint under it.
	// Parent the particle host to the dialog (or an explicit layerRoot) so bursts
	// appear above the panel.
	function layerRootFor(opts) {
		if (opts.layerRoot) return opts.layerRoot;
		if (opts.origin && opts.origin.tagName === "DIALOG") return opts.origin;
		return document.body;
	}

	function ensureLayer(root) {
		ensureStyles();
		if (!layer) {
			layer = document.createElement("div");
			layer.className = "confetti-layer";
			layer.setAttribute("aria-hidden", "true");
		}
		if (layer.parentNode !== root) root.appendChild(layer);
		return layer;
	}

	function rand(min, max) {
		return min + Math.random() * (max - min);
	}

	function pick(arr) {
		return arr[(Math.random() * arr.length) | 0];
	}

	function reducedMotion() {
		return window.matchMedia &&
			window.matchMedia("(prefers-reduced-motion: reduce)").matches;
	}

	// Sample a ballistic arc into WAAPI keyframes.
	// angleDeg: 0 = right, 90 = up. Gravity pulls +y (down the screen).
	function ballistics(angleDeg, speed, lifeMs) {
		var rad = angleDeg * Math.PI / 180;
		var vx = Math.cos(rad) * speed;
		var vy0 = -Math.sin(rad) * speed; // up is negative screen-y
		var T = lifeMs / 1000;
		var rot = rand(-540, 540);
		var frames = [];

		for (var i = 0; i <= STEPS; i++) {
			var u = i / STEPS;
			var t = u * T;
			var x = vx * t;
			var y = vy0 * t + 0.5 * GRAVITY * t * t;
			var opacity = u < 0.7 ? 1 : 1 - (u - 0.7) / 0.3;
			frames.push({
				transform:
					"translate(-50%,-50%) translate(" + x.toFixed(1) + "px," +
					y.toFixed(1) + "px) rotate(" + (rot * u).toFixed(1) + "deg)",
				opacity: Math.max(0, opacity),
				offset: u
			});
		}
		return frames;
	}

	function flake(host, x, y, angleDeg, spreadDeg, speedMin, speedMax, size) {
		var el = document.createElement("i");
		var w = rand(6, 12) * size;
		var h = rand(8, 16) * size;
		var angle = angleDeg + rand(-spreadDeg / 2, spreadDeg / 2);
		var speed = rand(speedMin, speedMax);
		var life = rand(1100, 1700);
		var color = pick(COLORS);

		el.style.cssText =
			"left:" + x + "px;top:" + y + "px;" +
			"width:" + w + "px;height:" + h + "px;" +
			"background:" + color + ";";

		host.appendChild(el);

		var anim = el.animate(ballistics(angle, speed, life), {
			duration: life,
			easing: "linear",   // physics lives in the keyframes
			fill: "forwards"
		});

		anim.onfinish = function () {
			el.remove();
		};
	}

	// Resolve launch point from either absolute {x,y} or an element anchor.
	// On an element: xFrac/yFrac (0..1) place within its box; corner is a
	// shorthand when you do not pass xFrac.
	function originPoint(opts) {
		if (opts.x != null && opts.y != null) {
			return { x: opts.x, y: opts.y };
		}

		var origin = opts.origin;
		if (!origin) {
			return { x: window.innerWidth / 2, y: window.innerHeight * 0.62 };
		}
		if (!(origin instanceof Element)) {
			return {
				x: (origin.x != null ? origin.x : 0.5) * window.innerWidth,
				y: (origin.y != null ? origin.y : 0.6) * window.innerHeight
			};
		}

		var r = origin.getBoundingClientRect();
		var fy = opts.yFrac != null ? opts.yFrac : 0.5;

		if (opts.xFrac != null) {
			return {
				x: r.left + r.width * opts.xFrac,
				y: r.top + r.height * fy
			};
		}

		var corner = opts.corner;
		if (corner === "left") {
			return { x: r.left, y: r.top + r.height * fy };
		}
		if (corner === "right") {
			return { x: r.right, y: r.top + r.height * fy };
		}
		if (corner === "top-left") {
			return { x: r.left, y: r.top };
		}
		if (corner === "top-right") {
			return { x: r.right, y: r.top };
		}
		if (corner === "bottom-left") {
			return { x: r.left, y: r.bottom };
		}
		if (corner === "bottom-right") {
			return { x: r.right, y: r.bottom };
		}
		return { x: r.left + r.width / 2, y: r.top + r.height / 2 };
	}

	// Reflect a left-authored launch across the origin element's vertical axis.
	function mirroredOpts(opts, angle) {
		var out = {};
		for (var k in opts) {
			if (Object.prototype.hasOwnProperty.call(opts, k)) out[k] = opts[k];
		}
		out.mirror = false;
		out.angle = 180 - angle;
		if (out.xFrac != null) out.xFrac = 1 - out.xFrac;
		if (out.corner === "left") out.corner = "right";
		else if (out.corner === "right") out.corner = "left";
		else if (out.corner === "top-left") out.corner = "top-right";
		else if (out.corner === "top-right") out.corner = "top-left";
		else if (out.corner === "bottom-left") out.corner = "bottom-right";
		else if (out.corner === "bottom-right") out.corner = "bottom-left";
		return out;
	}

	// opts: origin / x,y / xFrac,yFrac, angle, energy, size, spread, count, mirror
	function burst(opts) {
		opts = opts || {};
		if (reducedMotion()) return;

		var angle = opts.angle != null ? opts.angle : DEFAULT_ANGLE;
		if (opts.mirror) opts = mirroredOpts(opts, angle);

		var host = ensureLayer(layerRootFor(opts));
		var count = opts.count != null ? opts.count : DEFAULT_COUNT;
		angle = opts.angle != null ? opts.angle : DEFAULT_ANGLE;
		var spread = opts.spread != null ? opts.spread : DEFAULT_SPREAD;
		var energy = opts.energy != null ? opts.energy : DEFAULT_ENERGY;
		var size = opts.size != null ? opts.size : DEFAULT_SIZE;
		var speedMin = BASE_SPEED_MIN * energy;
		var speedMax = BASE_SPEED_MAX * energy;
		var pt = originPoint(opts);

		for (var i = 0; i < count; i++) {
			flake(host, pt.x, pt.y, angle, spread, speedMin, speedMax, size);
		}
	}

	return {
		burst: burst,
		defaults: {
			size: DEFAULT_SIZE,
			energy: DEFAULT_ENERGY,
			angle: DEFAULT_ANGLE,
			spread: DEFAULT_SPREAD,
			count: DEFAULT_COUNT,
			mirror: false
		}
	};
})();
