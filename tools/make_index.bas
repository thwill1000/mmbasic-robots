'write tiles from library

'get start addresses
spr%=Peek(cfunaddr SPRITES)
til0%=Peek(cfunaddr TILE0)
til1%=Peek(cfunaddr TILE1)
til2%=Peek(cfunaddr TILE2)

'build index file
Dim sprite_index%(&h60)
Dim tile_index%(&hff)

Open "spr_index.txt" For input As #1
For i=0 To &h5a
  Input #1,a$
  sprite_index%(i)=spr%+Val(a$)
Next
Close #1

Open "tile_index0.txt" For input As #1
For i=0 To &h3f
  Input #1,a$
  tile_index%(i)=til0%+Val(a$)
Next i
Close #1

Open "tile_index1.txt" For input As #1
For i=&h40 To &h7f
  Input #1,a$
  tile_index%(i)=til1%+Val(a$)
Next
Close #1

Open "tile_index2.txt" For input As #1
For i=&h80 To &hff
  Input #1,a$
  tile_index%(i)=til2%+Val(a$)
Next
Close #1



MODE 2
Sprite compressed sprite_index%(20),70,100
Sprite compressed tile_index%(20),100,100
Sprite compressed tile_index%(70),130,100
Sprite compressed tile_index%(150),160,100

