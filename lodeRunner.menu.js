// Highest shipped playData id (custom levels use PLAY_DATA_USERDEF separately).
// Built once at boot; storage/main/demo gate on maxPlayId.
var maxPlayId;

function initMenuVariable()
{
	maxPlayId = 0;
	for(var i = 0; i < playVersionInfo.length; i++) {
		if(maxPlayId < playVersionInfo[i].id) maxPlayId = playVersionInfo[i].id;
	}
	// classic pack is sync-loaded from HTML
	markScriptLoaded("lodeRunner.v.classic.js");
}

function classicPlay(id, callbackFun)
{
	function beginClassic()
	{
		ensurePlayVersionLoaded(playData, function () {
			if(playMode == PLAY_EDIT) canvasReSize();
			playMode = PLAY_CLASSIC;
			if(callbackFun != null) callbackFun();

			soundStop(soundDig);
			soundStop(soundFall);
			disableStageClickEvent();
			setKeyHandler(handleKeyDown);
			setLastPlayMode();
			initShowDataMsg();
			startGame();
		});
	}
	if (playMode == PLAY_EDIT) leaveEditMode(beginClassic, callbackFun);
	else beginClassic();
}

function modernPlay(id, callbackFun)
{
	function beginModern()
	{
		ensurePlayVersionLoaded(playData, function () {
			if(playMode == PLAY_EDIT) canvasReSize();
			playMode = PLAY_MODERN;
			if(callbackFun != null) callbackFun();

			soundStop(soundDig);
			soundStop(soundFall);
			disableStageClickEvent();
			setKeyHandler(handleKeyDown);
			setLastPlayMode();
			initShowDataMsg();
			startGame();
		});
	}
	if (playMode == PLAY_EDIT) leaveEditMode(beginModern, callbackFun);
	else beginModern();
}

function editPlay(id, callbackFun)
{
	function beginEditPlay()
	{
		if(playMode == PLAY_EDIT) canvasReSize();
		playMode = PLAY_MODERN;
		playData = PLAY_DATA_USERDEF;
		if(callbackFun != null) callbackFun();

		disableStageClickEvent();
		setKeyHandler(handleKeyDown);
		setLastPlayMode();
		if (id < 0) { //id < 0 ==> means call from import custom levels
			initShowDataMsg(0); //no tips message
			startGame(1); // no cycle
		} else {
			initShowDataMsg();
			startGame();
		}
	}
	if (playMode == PLAY_EDIT) leaveEditMode(beginEditPlay, callbackFun);
	else beginEditPlay();
}

function editEdit(id, callbackFun)
{
	if(callbackFun != null) callbackFun();
	disableStageClickEvent();
	if (id < 0) { //id < 0 ==> means call from import custom levels
		initShowDataMsg(0);
	} else {
		initShowDataMsg();
	}
	startEditMode();
}
