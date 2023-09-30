'petrobot testbed picomite VGA V50708RC1

  MODE 2

'add framebuffer
  FRAMEBUFFER layer

'get world map
  loadworld
  loadindex

'startup defines

'tile attribute flags
  b_pus=32: b_see=16: b_dmg=8: b_mov=4: b_hov=2: b_wlk=1

'world map 128x64
  hsize=128:vsize=64

'start positions player in map
  xp=Asc(Left$(ulx$,1)):yp=Asc(Left$(uly$,1))

'view window on map # of tiles E-W and N-S
  xsm=5:ysm=3

'window centre with 24*24 tile reference
  xs=5*24:ys=4*24

'write initial world
  writeworld_m

'write frame
  FRAMEBUFFER write L
  Load image "graphics/layer.bmp"

'initial player
  playersp=1        'for now a fixed sprite
  writeplayer_m



'main loop
  Do
    Do :k$=Inkey$:Loop While k$=""
    key=Asc(k$)

'player control
    v=(key=129)-(key=128)
    h=(key=131)-(key=130)
    If h+v<>0 Then  'when move key pressed
      x2=Min(Max(xp+h,0),hsize-1)
      y2=Min(Max(yp+v,0),vsize-1)
'check if we can walk, then walk
      Text 0,0,Hex$(get_ta(x2,y2))
      If (get_ta(x2,y2) And b_wlk) Then
        xp=xp+h:yp=yp+v
        xp=Min(Max(xp,5),hsize-6)
        yp=Min(Max(yp,3),vsize-4)
        writeworld_m    'scroll world
        writeplayer_m   'update player tile
      EndIf
    EndIf

'development support
    If key=27 Then 'esc
      FRAMEBUFFER write n
      Save image "pet.bmp"
    EndIf

    Pause 10
  Loop Until k$="q"

  Memory
End



'write player from sprites in library
Sub writeplayer_m
  FRAMEBUFFER write l
  Box xs,ys,24,24,1,0,0
'playersp=23-playersp        'toggle between 2 sprites 12 and 13
  Sprite compressed sprite_index%(playersp),xs,ys
End Sub


'test version using CSUB's to store tiles in library
Sub writeworld_m
  FRAMEBUFFER write n
  For xn=-xsm To xsm
    For yn=-ysm To ysm
      x=xs+xn*24
      y=ys+yn*24
'load tile from world map
      spn=Asc(Mid$(lv$(yp+yn),xp+xn+1,1))
      Sprite compressed tile_index%(spn),x,y
    Next
  Next
End Sub


'get tile attribute for this tile
Function get_ta(x,y)
  Local til
  til=Asc(Mid$(lv$(y),x+1,1))
  get_ta = Asc(Mid$(ta$,til+1,1))
End Function



Sub loadworld
'define variables
  Dim UT$ length 64       'unit type
  Dim ULX$ length 64      'unit X coordinate
  Dim ULY$ length 64      'unit X coordinate
  Dim UA$ length 64       'unit A parameter
  Dim UB$ length 64       'unit B parameter
  Dim UC$ length 64       'unit C parameter
  Dim UD$ length 64       'unit D parameter
  Dim UH$ length 64       'unit health

  Dim LV$(63) Length 128  'the map 128h x 64v with tile numbers
  Dim DP$                 '255(+1) destruct paths
  Dim TA$                 '255(+1) tile attributes

'load world map and attributes
  Open "data\level-a" For input As #1

'load UNIT attributes
  UT$=Input$(64,#1)
  ULX$=Input$(64,#1)
  ULY$=Input$(64,#1)
  UA$=Input$(64,#1)
  UB$=Input$(64,#1)
  UC$=Input$(64,#1)
  UD$=Input$(64,#1)
  UH$=Input$(64,#1)

'load world map
  dummy$=Input$(128,#1)  'hier zit geen zinvolle data in. Vreemd!
  dummy$=Input$(128,#1)
  For i=0 To 63:LV$(i)=Input$(128,#1):Next i
  Close #1

'load destruct paths and tile attributes
  Open "data\tileset.amiga" For input As #1
  dummy$=Input$(2,#1) 'offset
  DP$=Input$(255,#1)  '255 destruct paths
  dummy$=Input$(1,#1) '1 path ignored
  TA$=input$(255,#1)  '255 tile attributes
'  dummy$=Input$(1,#1) '1 attribute ignored
  close #1

End Sub


Sub loadindex
'get start addresses
  Local hlt%=Peek(cfunaddr health)
  Local spr%=Peek(cfunaddr SPRITES)
  Local til0%=Peek(cfunaddr TILE0)
  Local til1%=Peek(cfunaddr TILE1)
  Local til2%=Peek(cfunaddr TILE2)

'build global index file
  Dim sprite_index%(&h60)
  Dim health_index%(10)
  Dim tile_index%(&hff)

  Open "graphics/hltindex.txt" For input As #1
  For i=0 To 5
    Input #1,a$
    health_index%(i)=hlt%+Val(a$)
  Next
  Close #1

  Open "graphics/spindex.txt" For input As #1
  For i=0 To &h5f
    Input #1,a$
    sprite_index%(i)=spr%+Val(a$)
  Next
  Close #1

  Open "graphics/tile_index0.txt" For input As #1
  For i=0 To &h3f
    Input #1,a$
    tile_index%(i)=til0%+Val(a$)
  Next i
  Close #1

  Open "graphics/tile_index1.txt" For input As #1
  For i=&h40 To &h7f
    Input #1,a$
    tile_index%(i)=til1%+Val(a$)
  Next
  Close #1

  Open "graphics/tile_index2.txt" For input As #1
  For i=&h80 To &hff
    Input #1,a$
    tile_index%(i)=til2%+Val(a$)
  Next
  Close #1

End Sub
