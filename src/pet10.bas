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

  'defines
  hsize=128:vsize=64  'world map 128x64
  xsm=5:ysm=3         'view window on map # of tiles E-W and N-S
  xs=5*24:ys=4*24     'window centre with 24*24 tile reference

  'start positions player in map in # tiles
  xp=Asc(Left$(ulx$,1)):yp=Asc(Left$(uly$,1))
  'xp and yp are used parallel to ulx$(1) and uly$(1)



  'write initial world
  writeworld_m

  'write frame
  FRAMEBUFFER write L
  Load image "graphics/layer.bmp"

  'initial player
  playersp=0        'default player is facing you
  playermv=0        'walking move 0..4
  writeplayer_m(0,0)



  'main loop
  Do
    Do :k$=Inkey$:Loop While k$=""
    key=Asc(k$)

    'player control
    v=(key=129)-(key=128)
    h=(key=131)-(key=130)
    If h+v<>0 Then                  'when move key pressed
      'check if we can walk, then walk
      If (get_ta(xp+h,yp+v) And b_wlk) Then
        xp=xp+h:yp=yp+v             'new player position
        xp=Min(Max(xp,5),hsize-6)   'don't fall off the map
        yp=Min(Max(yp,3),vsize-4)
        store_unit_pos(1,xp,yp)     'store pos for future use
        writeworld_m                'scroll world
        writeplayer_m(h,v)          'update player tile
        'text 0,0,hex$(xp)+" "+hex$(yp)
      EndIf
    EndIf

    'investigate UNITs
    'this will happen under interrupt in future
    scan_UNITS

    'development support
    If key=27 Then 'esc
      FRAMEBUFFER write n
      Save image "pet.bmp"
    EndIf

    Pause 10
  Loop Until k$="q"

  Memory
End

sub scan_UNITS
  'this loop takes roughly 11ms now
  'timer=0
  local i%,dx,dy,nearx,neary
  for i%=2 to 64                      'UNIT 1 = player, skip player
    unit_type%=Asc(mid$(ut$,i%,1))

    'here we branch to different units

    'this section handles doors
    if unit_type%=10 then             'this is a door
      dx=Asc(mid$(ulx$,i%,1)):dy=Asc(mid$(uly$,i%,1))
      nearx=abs(dx-xp):neary=abs(dy-yp)
      if nearx+neary<3 then           'we are close to the door, ignore any other
        if nearx+neary=1 then         'operate door
          open_door(i%,dx,dy)
        else if nearx=0 and neary=0 then
          'do nothing
        else                          'we are far enough so close the door
          close_door(i%,dx,dy)
        end if
      end if
    end if

  next i%
  'text 150,0,str$(timer)
end sub

sub open_door(i%,dx,dy)
  'door is closed, and is open at the end of this section
  local unit_a%,unit_b%
  unit_a%=asc(mid$(ua$,i%,1))
  unit_b%=asc(mid$(ub$,i%,1))
  if unit_b%>2 then
    if unit_a%=1 then 'vertical door
      anim_v_door(dx,dy,69,73,77) 'remove for LCD
      anim_v_door(dx,dy,70,74,78) 'remove for LCD
      anim_v_door(dx,dy,27,9,15)
    else 'horizontal door
      anim_h_door(dx,dy,84,85,86) 'remove for LCD
      anim_h_door(dx,dy,88,89,86) 'remove for LCD
      anim_h_door(dx,dy,17,9,91)
    end if
    mid$(ub$,i%,1)=chr$(2)  'door is open
  end if
end sub

sub close_door(i%,dx,dy)
  'door is open, and is closed at the end of this section
  local unit_a%,unit_b%
  unit_a%=asc(mid$(ua$,i%,1))
  unit_b%=asc(mid$(ub$,i%,1))
  if unit_b%<3 then
    if unit_a%=1 then 'vertical door
      anim_v_door(dx,dy,70,74,78) 'remove for LCD
      anim_v_door(dx,dy,69,73,77) 'remove for LCD
      anim_v_door(dx,dy,68,72,76)
    else 'horizontal door
      anim_h_door(dx,dy,88,89,86) 'remove for LCD
      anim_h_door(dx,dy,84,85,86) 'remove for LCD
      anim_h_door(dx,dy,80,81,82)
    end if
    mid$(ub$,i%,1)=chr$(5)  'door is closed
  end if
end sub

sub anim_v_door (dx,dy,a,b,c)
  mid$(lv$(dy-1),dx+1,1)=chr$(a)
  mid$(lv$(dy),dx+1,1)=chr$(b)
  mid$(lv$(dy+1),dx+1,1)=chr$(c)
  writeworld_m
  pause 50
end sub

sub anim_h_door (dx,dy,a,b,c)
  mid$(lv$(dy),dx,1)=chr$(a)
  mid$(lv$(dy),dx+1,1)=chr$(b)
  mid$(lv$(dy),dx+2,1)=chr$(c)
  writeworld_m
  pause 50
end sub

  'write UNIT position back in UNIT attributes (also player)
sub store_unit_pos(unit%,x,y)
  mid$(ulx$,unit%,1)=chr$(x):mid$(uly$,unit%,1)=chr$(y)
end sub

  'write player from sprites in library
Sub writeplayer_m(h,v)
  FRAMEBUFFER write l
  Box xs,ys,24,24,1,0,0
  playersp=8*(v=-1)+4*(h=1)+12*(h=-1)
  Sprite compressed sprite_index%(playersp+playermv),xs,ys
  playermv=(playermv+1) Mod 4
End Sub

  'uses tiles stored in library to build up screen
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
  TA$=Input$(255,#1)  '255 tile attributes
  '  dummy$=Input$(1,#1) '1 attribute ignored
  Close #1

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
