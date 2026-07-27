var endingLoadFinish=0;
function loadEndingMusic()
{
	if(endingLoadFinish) return;
	soundLoadManifest([{ id: "endingMusic", src: "sound/ending/endingMusic.ogg" }]).then(function () {
		endingLoadFinish = 1;
	}).catch(function (err) {
		console.log("ending music load failed", err);
	});
}

function endingMusicPlay()
{
	if(endingLoadFinish) soundPlay("endingMusic");
}

function endingMusicStop()
{
	if(endingLoadFinish) soundStop("endingMusic");
}
