//=============================================================================
// Pure sticky/repeat key-state helpers (CreateJS-free).
// Input stop-on-release must work even when recordMode == RECORD_NONE.
// Demo capture (playRecord pushes) is optional via capture flag.
//=============================================================================

/**
 * One tick of sticky-key (!repeatAction) processing.
 *
 * @param {object} state { keyPressed, recordKeyCode, lastKeyCode, keyAction, alwaysRecord }
 * @param {boolean} capture when true, append [recordCount, code] to outRecord
 * @param {number} recordCount
 * @param {number[]} outRecord playRecord array (mutated when capture)
 * @param {number} keycodeSpace KEYCODE_SPACE
 * @param {number} actStop ACT_STOP
 * @returns {object} next state (same shape)
 */
function advanceStickyKeyState(state, capture, recordCount, outRecord, keycodeSpace, actStop)
{
	var keyPressed = state.keyPressed;
	var recordKeyCode = state.recordKeyCode;
	var lastKeyCode = state.lastKeyCode;
	var keyAction = state.keyAction;
	var alwaysRecord = state.alwaysRecord;

	switch (keyPressed) {
	case 1: // pressed
		if (recordKeyCode != lastKeyCode || alwaysRecord) {
			if (capture) {
				outRecord.push(recordCount);
				outRecord.push(recordKeyCode);
			}
			lastKeyCode = recordKeyCode;
		}
		if (alwaysRecord) keyPressed = -1; // floating (dig): ignore release
		break;
	case 0: // released
		if (recordKeyCode != keycodeSpace) {
			if (capture) {
				outRecord.push(recordCount);
				outRecord.push(keycodeSpace);
			}
			lastKeyCode = recordKeyCode = keycodeSpace;
			keyAction = actStop;
		}
		break;
	}

	return {
		keyPressed: keyPressed,
		recordKeyCode: recordKeyCode,
		lastKeyCode: lastKeyCode,
		keyAction: keyAction,
		alwaysRecord: alwaysRecord
	};
}

/**
 * One tick of repeat-action-on processing (no stop-on-release).
 */
function advanceRepeatKeyState(state, capture, recordCount, outRecord)
{
	var keyPressed = state.keyPressed;
	var recordKeyCode = state.recordKeyCode;
	var lastKeyCode = state.lastKeyCode;
	var alwaysRecord = state.alwaysRecord;

	if (!keyPressed) {
		return {
			keyPressed: keyPressed,
			recordKeyCode: recordKeyCode,
			lastKeyCode: lastKeyCode,
			keyAction: state.keyAction,
			alwaysRecord: alwaysRecord
		};
	}

	if (recordKeyCode != lastKeyCode || alwaysRecord) {
		if (capture) {
			outRecord.push(recordCount);
			outRecord.push(recordKeyCode);
		}
		lastKeyCode = recordKeyCode;
	}
	keyPressed = 0;

	return {
		keyPressed: keyPressed,
		recordKeyCode: recordKeyCode,
		lastKeyCode: lastKeyCode,
		keyAction: state.keyAction,
		alwaysRecord: alwaysRecord
	};
}
