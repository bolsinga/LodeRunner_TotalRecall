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
			worldDisplay.remove(map[x][y].bitmap); //remove old
			curTile.setTransform(x * tileW, y * tileH, 1, 1);
			worldDisplay.add(curTile);  //add new
			map[x][y].bitmap = curTile;   //replace bitmap
		}
	}
}

function clearGround()
{
	for (var i = 0; i < groundTile.length; i++)
		worldDisplay.remove(groundTile[i]);
}

function clearInfo()
{
	var i;

	if(playMode == PLAY_CLASSIC || playMode == PLAY_AUTO || playMode == PLAY_DEMO) {
		for(i = 0; i < scoreTxt.length; i++) worldDisplay.remove(scoreTxt[i]);
		for(i = 0; i < scoreTile.length; i++) worldDisplay.remove(scoreTile[i]);

		if(playMode == PLAY_DEMO) {
			for(i = 0; i < demoTxt.length; i++) worldDisplay.remove(demoTxt[i]);
		} else {
			for(i = 0; i < lifeTxt.length; i++) worldDisplay.remove(lifeTxt[i]);
			for(i = 0; i < lifeTile.length; i++) worldDisplay.remove(lifeTile[i]);
		}
	} else { //PLAY_MODERN, PLAY_DEMO_ONCE
		for(i = 0; i < goldTxt.length; i++) worldDisplay.remove(goldTxt[i]);
		for(i = 0; i < goldTile.length; i++) worldDisplay.remove(goldTile[i]);

		for(i = 0; i < guardTxt.length; i++) worldDisplay.remove(guardTxt[i]);
		for(i = 0; i < guardTile.length; i++) worldDisplay.remove(guardTile[i]);

		for(i = 0; i < timeTxt.length; i++) worldDisplay.remove(timeTxt[i]);
		for(i = 0; i < timeTile.length; i++) worldDisplay.remove(timeTile[i]);
	}
	
	for(i = 0; i < levelTxt.length; i++) worldDisplay.remove(levelTxt[i]);
	for(i = 0; i < levelTile.length; i++) worldDisplay.remove(levelTile[i]);	
}

//======================================
// END: Change Theme Screen real time
