//=============================================================================
// Game lifecycle: the boundary between the game and anything that interrupts it.
//
// The game and the UI chrome are peers. Neither holds a reference to the other;
// they talk through DOM events on `document`:
//
//     "menu-open"  -> game.suspend(false)
//     "menu-close" -> game.suspend(true)
//=============================================================================

var game = (function() {

	var wasRunning = true; // what the game was doing when an interruption began

	return {
		// Pause is a state change, not a teardown: gameState = GAME_PAUSE is what
		// freezes the world, and the ticker keeps running (as it does under Esc).
		//
		// The guard reads gameState rather than a flag of its own, because
		// gamePause stashes gameState in lastGameState -- pausing an already
		// paused game would stash GAME_PAUSE and nothing could resume it.
		run: function(on) {
			if(!!on === this.isRunning()) return;
			if(on) { gameResume(); focusGame(); }
			else   { gamePause(); }
		},

		// Pause for an interruption, then put the game back the way it was found.
		// Not run(false)/run(true): if the player had already paused with Esc,
		// resuming here would strand the PAUSE banner, which only the Esc handler
		// clears.
		suspend: function(on) {
			if(!on) { wasRunning = this.isRunning(); this.run(false); }
			else if(wasRunning) this.run(true);
			else focusGame(); // still paused, but the game owns the keyboard again
		},

		isRunning: function() { return gameState != GAME_PAUSE; },

		// One fixed simulation step. A pass-through for now; the game loop will
		// drive the sim through here.
		tick: function(event) { mainTick(event); }
	};
})();

// The game subscribes; the menu fires into the void and never calls it directly.
document.addEventListener("menu-open",  function() {
	if(playMode == PLAY_AUTO || idleTimer) stopDemoAndPlay();
	game.suspend(false);
});
document.addEventListener("menu-close", function() { game.suspend(true); });
