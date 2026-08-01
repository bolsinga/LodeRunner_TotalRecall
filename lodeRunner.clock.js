//=============================================================================
// Owned game clock: rAF + fixed-step accumulator (replaces createjs.Ticker).
//
// Listeners are called once per sim step with { delta, time } (ms), matching the
// CreateJS Ticker event shape mainTick already consumes. FPS is the sim rate
// (speedMode / demoSpeed / cover 30); display refresh is decoupled via rAF.
//
// When the last listener leaves, stopClock clears clockAcc. ensureClockRunning
// then resets acc + clockLast on restart — intentional: drop fractional phase at
// cover↔play boundaries so a hitch while idle cannot burst into the next mode.
//=============================================================================

var clockFps = 30;
var clockAcc = 0;
var clockLast = 0;
var clockTime = 0; // ms since clock start (CreateJS event.time analogue)
var clockRafId = 0;
var clockListeners = [];
var CLOCK_MAX_STEPS = 5;

function setClockFps(fps)
{
	if(fps > 0) clockFps = fps;
}

function addClockListener(fn)
{
	removeClockListener(fn);
	clockListeners.push(fn);
	ensureClockRunning();
}

function removeClockListener(fn)
{
	var i = clockListeners.indexOf(fn);
	if(i >= 0) clockListeners.splice(i, 1);
	if(!clockListeners.length) stopClock();
}

function ensureClockRunning()
{
	if(clockRafId) return;
	// Fresh phase on (re)start — see file header. Do not carry idle hitch debt.
	clockAcc = 0;
	clockLast = performance.now();
	function frame(now)
	{
		if(!clockListeners.length) {
			clockRafId = 0;
			return;
		}
		clockRafId = requestAnimationFrame(frame);
		var step = 1000 / clockFps;
		clockAcc += now - clockLast;
		clockLast = now;
		var n = 0;
		while(clockAcc >= step && n < CLOCK_MAX_STEPS) {
			clockTime += step;
			var list = clockListeners.slice();
			var evt = { delta: step, time: clockTime };
			for(var i = 0; i < list.length; i++) {
				if(clockListeners.indexOf(list[i]) >= 0) list[i](evt);
			}
			clockAcc -= step;
			n++;
		}
		if(n === CLOCK_MAX_STEPS) clockAcc = 0;
	}
	clockRafId = requestAnimationFrame(frame);
}

function stopClock()
{
	if(clockRafId) {
		cancelAnimationFrame(clockRafId);
		clockRafId = 0;
	}
	clockAcc = 0;
}
