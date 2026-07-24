//=============================================================================
// Lightweight rAF tween helper (CreateJS TweenJS replacement).
// Supports the subset used by this game: set / wait / to / call + override.
//=============================================================================

var _activeTweens = typeof WeakMap !== "undefined" ? new WeakMap() : null;

//start a tween chain on target: .set(props).wait(ms).to(props, ms).call(fn)
//opts.override cancels any prior tween on the same target
function tweenGet(target, opts)
{
	opts = opts || {};
	if (opts.override) {
		var prev = _activeTweens && _activeTweens.get(target);
		if (prev) prev.cancel();
	}

	var steps = [];
	var cancelled = false;
	var rafId = 0;
	var started = false;

	function cancel()
	{
		cancelled = true;
		if (rafId) {
			cancelAnimationFrame(rafId);
			rafId = 0;
		}
		if (_activeTweens && _activeTweens.get(target) === handle) {
			_activeTweens.delete(target);
		}
	}

	var handle = { cancel: cancel };

	function applyProps(props)
	{
		for (var key in props) {
			if (Object.prototype.hasOwnProperty.call(props, key)) {
				target[key] = props[key];
			}
		}
	}

	function runStep(index)
	{
		if (cancelled) return;
		if (index >= steps.length) {
			if (_activeTweens && _activeTweens.get(target) === handle) {
				_activeTweens.delete(target);
			}
			return;
		}

		var step = steps[index];
		if (step.type === "set") {
			applyProps(step.props);
			runStep(index + 1);
			return;
		}
		if (step.type === "call") {
			step.fn.call(target);
			runStep(index + 1);
			return;
		}
		if (step.type === "wait") {
			var waitStart = performance.now();
			function waitFrame(now)
			{
				if (cancelled) return;
				if (now - waitStart >= step.ms) {
					rafId = 0;
					runStep(index + 1);
					return;
				}
				rafId = requestAnimationFrame(waitFrame);
			}
			rafId = requestAnimationFrame(waitFrame);
			return;
		}
		// step.type === "to" - linear interpolation from current values
		var from = {};
		var toProps = step.props;
		for (var key in toProps) {
			if (Object.prototype.hasOwnProperty.call(toProps, key)) {
				var cur = target[key];
				from[key] = typeof cur === "number" ? cur : 0;
			}
		}
		var duration = step.ms;
		if (duration <= 0) {
			applyProps(toProps);
			runStep(index + 1);
			return;
		}
		var tweenStart = performance.now();
		function tweenFrame(now)
		{
			if (cancelled) return;
			var t = (now - tweenStart) / duration;
			if (t >= 1) {
				applyProps(toProps);
				rafId = 0;
				runStep(index + 1);
				return;
			}
			for (var k in toProps) {
				if (Object.prototype.hasOwnProperty.call(toProps, k)) {
					target[k] = from[k] + (toProps[k] - from[k]) * t;
				}
			}
			rafId = requestAnimationFrame(tweenFrame);
		}
		rafId = requestAnimationFrame(tweenFrame);
	}

	function ensureStart()
	{
		if (started) return;
		started = true;
		if (_activeTweens) _activeTweens.set(target, handle);
		// Defer so the full sync chain (.set/.wait/.to/.call) registers first.
		var schedule = typeof queueMicrotask === "function"
			? queueMicrotask
			: function (fn) { Promise.resolve().then(fn); };
		schedule(function () {
			if (cancelled) return;
			runStep(0);
		});
	}

	var api = {
		set: function (props) {
			steps.push({ type: "set", props: props });
			ensureStart();
			return api;
		},
		wait: function (ms) {
			steps.push({ type: "wait", ms: ms });
			ensureStart();
			return api;
		},
		to: function (props, ms) {
			steps.push({ type: "to", props: props, ms: ms });
			ensureStart();
			return api;
		},
		call: function (fn) {
			steps.push({ type: "call", fn: fn });
			ensureStart();
			return api;
		}
	};

	return api;
}
