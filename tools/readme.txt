
file locations and function --------------------------------------------------

tiles\TL0*.SPR   			normal Tiles 24x24
tiles\TLA*.SPR   			Tiles for Animation 24x24

items\ITM*.SPR   			ITEMS 48x24
sprites\KEY*.SPR			3 Keycards 16x16
sprites\spr-Files\SP0*.spr  		Sprite Files that are included in the CSUB
sprites\Hlt.csub			6 Health Stages 48x48

Images\introscreen.bmp			Intro Screen (Startmenu)
Images\end.bmp				Game end, results
Images\layerb.bmp			Layer for the L Frame with black background


Using the library -------------------------------------------------------------
The library is used as massive binary storage.
LIBRARY DELETE to clear the library

for all the xxx_CSUB.BAS files in /sprites and /tiles (8 in total) do:
LOAD "xxx_CSUB.BAS"		to load into RAM
LIBRARY SAVE "xxx_CSUB.BAS"	to store in library

then save the library to disk
LIBRARY DISK SAVE "pet_lib.bin"

Before running the game, load the library in a new unit.
LIBRARY DELETE
LIBRARY DISK LOAD "pet_lib.bin"

note: in the folder where the CSUB's are, there are also xxx_INDEX.TXT files.
these files are used to locate every sprite in the library. They match the library.

When generating new CSUB files, also new INDEX files are generated.
use the "spr2csub.bas" located in the /tools folder. Manually edit lines 8,9,13 for each CSUB.

folder			line8			line9			line13
/tiles/tiles0_3f	tile0_csub.bas		tile0_index.txt	CSUB TILE0
/tiles/tiles40_7f	tile1_csub.bas		tile1_index.txt	CSUB TILE1
/tiles/tiles80_ff	tile2_csub.bas		tile2_index.txt	CSUB TILE2
/tiles/tla		tla_csub.bas		tla_index.txt		CSUB TLA
/sprites/health	hlt_csub.bas		hlt_index.txt		CSUB HEALTH
/sprites/items		item_csub.bas		item_index.txt		CSUB ITEM
/sprites/keys		key_csub.bas		key_index.txt		CSUB KEY
/sprites/spr-files	spr_csub.bas		spr_index.txt		CSUB SPRITES

note: the tiles "TLxxx.SPR" are split up in 3 groups to avoid memory problems on picomite





 
