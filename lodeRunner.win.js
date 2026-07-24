var endingLoadFinish=0;
function loadEndingMusic()
{
	if(endingLoadFinish) return;
	soundLoadManifest([{ id: "win", src: "sound/ending/win.ogg" }]).then(function () {
		endingLoadFinish = 1;
	}).catch(function (err) {
		console.log("ending music load failed", err);
	});
}

function endingMusicPlay()
{
	if(endingLoadFinish) soundPlay("win");
}

function endingMusicStop()
{
	if(endingLoadFinish) soundStop("win");
}
