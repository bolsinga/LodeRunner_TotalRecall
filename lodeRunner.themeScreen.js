//======================================
// BEGIN: Change Theme Screen real time
//======================================

function changeThemeScreen()
{
	rebuildMap();
	
	//Change runner theme
	runner.sprite.spriteSheet = runnerData;
	
	//change guard theme
	for(var i = 0; i < guardCount; i++) {
		if(redhatMode && guard[i].hasGold > 0)
			guard[i].sprite.spriteSheet = redhatData;
		else
			guard[i].sprite.spriteSheet = guardData;
	}
	
	//change holeObj theme
	holeObj.sprite.spriteSheet = holeData;
	
	//change fillHoleObj theme
	for(var i = 0; i < fillHoleObj.length; i++) {
		fillHoleObj[i].spriteSheet = holeData;
	}
	
	moveSprite2Top();
	
	clearGround();
	clearInfo();
	initInfoVariable();
	buildGroundInfo();
}

function rebuildMap() 
{
	var curTile;
	
	for(var x = 0; x < NO_OF_TILES_X; x++) {
		for(var y = 0; y < NO_OF_TILES_Y; y++) {
			switch(map[x][y].base) {
			default:		
			case EMPTY_T: //empty		
				continue;
			case BLOCK_T: //Normal Brick		
				curTile = getThemeBitmap("brick");		
				if(map[x][y].bitmap.alpha < 1) curTile.set({alpha:0}); //hide brick digging
				break;	
			case SOLID_T: //Solid Brick		
				curTile = getThemeBitmap("solid");		
				break;	
			case LADDR_T: //Ladder
				curTile = getThemeBitmap("ladder");
				break;	
			case BAR_T: //Line of rope
				curTile = getThemeBitmap("rope");
				break;	
			case TRAP_T: //False brick
				curTile = getThemeBitmap("brick");
				if(map[x][y].bitmap.alpha < 1) curTile.set({alpha:0.5}); //show trap tile
				break;
			case HLADR_T: //Ladder appears at end of level
				curTile = getThemeBitmap("ladder");
				curTile.set({alpha:0});	//hide the laddr
				break;
			case GOLD_T: //Gold
				curTile = getThemeBitmap("gold");
				break;
			}
			mainStage.removeChild(map[x][y].bitmap); //remove old
			curTile.setTransform(x * tileWScale, y * tileHScale, tileScale, tileScale); //x,y, scaleX, scaleY
			mainStage.addChild(curTile);  //add new
			map[x][y].bitmap = curTile;   //replace bitmap
		}
	}
}

function clearGround()
{
	for (var i = 0; i < groundTile.length; i++)
		mainStage.removeChild(groundTile[i]);
}

function clearInfo()
{
	var i;

	if(playMode == PLAY_CLASSIC || playMode == PLAY_AUTO || playMode == PLAY_DEMO) {
		for(i = 0; i < scoreTxt.length; i++) mainStage.removeChild(scoreTxt[i]);
		for(i = 0; i < scoreTile.length; i++) mainStage.removeChild(scoreTile[i]);

		if(playMode == PLAY_DEMO) {
			for(i = 0; i < demoTxt.length; i++) mainStage.removeChild(demoTxt[i]);
		} else {
			for(i = 0; i < lifeTxt.length; i++) mainStage.removeChild(lifeTxt[i]);
			for(i = 0; i < lifeTile.length; i++) mainStage.removeChild(lifeTile[i]);
		}
	} else { //PLAY_MODERN, PLAY_DEMO_ONCE
		for(i = 0; i < goldTxt.length; i++) mainStage.removeChild(goldTxt[i]);
		for(i = 0; i < goldTile.length; i++) mainStage.removeChild(goldTile[i]);

		for(i = 0; i < guardTxt.length; i++) mainStage.removeChild(guardTxt[i]);
		for(i = 0; i < guardTile.length; i++) mainStage.removeChild(guardTile[i]);

		for(i = 0; i < timeTxt.length; i++) mainStage.removeChild(timeTxt[i]);
		for(i = 0; i < timeTile.length; i++) mainStage.removeChild(timeTile[i]);
	}
	
	for(i = 0; i < levelTxt.length; i++) mainStage.removeChild(levelTxt[i]);
	for(i = 0; i < levelTile.length; i++) mainStage.removeChild(levelTile[i]);	
}

//======================================
// END: Change Theme Screen real time
