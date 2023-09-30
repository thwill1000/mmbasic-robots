  'petrobot testbed picomite VGA V50708RC1

  MODE 2
  option default integer

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
'  xp=Asc(Left$(ulx$,1)):yp=Asc(Left$(uly$,1))
  xp=ux(0):yp=uy(0)
  'xp and yp are used parallel to ux(0) and uy(0)



  'write initial world
  writeworld_m(xsm,ysm)

  'write frame
  FRAMEBUFFER write L
  Load image "graphics/layer.bmp"

  'initial player
  playersp=0        'default player is facing you
  playermv=0        'walking move 0..4
  pl_wp=0           'weapon holding (0=none, 1=pistol, 2=plasma
  writeplayer_m(0,0,pl_wp)



  'main player input loop
  Do

    'player input through keyboard
    k$=Inkey$:key=Asc(k$)


    'player controls movement of player character
    v=(key=129)-(key=128)
    h=(key=131)-(key=130)
    If h+v<>0 Then                  'when move key pressed
      'check if we can walk, then walk
      If (get_ta(xp+h,yp+v) And b_wlk) Then
        xp=xp+h:yp=yp+v             'new player position
        xp=Min(Max(xp,5),hsize-6)   'don't fall off the map
        yp=Min(Max(yp,3),vsize-4)
        store_unit_pos(0,xp,yp)     'store pos for future use
        writeworld_m(xsm,ysm)       'scroll world
        writeplayer_m(h,v,pl_wp)    'update player tile
        'text 0,0,hex$(xp)+" "+hex$(yp)
      EndIf
    EndIf

    'investigate AI UNITs status and activate and process
    scan_UNITS

    'development support, for debugging
    If key=27 Then 'esc
      FRAMEBUFFER write n
      Save image "pet.bmp"
    EndIf

    'debug weapen sprites
    if key=32 then
      pl_wp=(pl_wp+1) mod 3
      writeplayer_m(h,v,pl_wp)
    end if

    Pause 50
  Loop Until k$="q"   'quit when q is pressed

  Memory
End


  'this is the main AI loop where AI all units are processed
sub scan_UNITS
  'timer=0
  local i,dx,dy,nearx,neary
  for i=1 to 63                     'UNIT 0 = player, skip player
    unit_type=ut(i)

    'here we branch to different units

    'this section handles automatic doors
    if unit_type=10 then             'this is a door
      dx=ux(i):dy=uy(i)
      nearx=abs(dx-xp):neary=abs(dy-yp)
      if nearx+neary<3 then           'we are close to the door, ignore any other
        if nearx+neary=1 then         'operate door
          open_door(i,dx,dy)
        else if nearx=0 and neary=0 then
          'do nothing
        else                          'we are far enough so close the door
          close_door(i,dx,dy)
        end if
      end if
    end if

  next i
  'text 150,0,str$(timer)
end sub


  'door is closed, and is open at the end of this animation
sub open_door(i,dx,dy)
  local u_b=ub(i)
  if ua(i)=1 then 'vertical door
    if u_b=1 then anim_v_door(dx,dy,27,9,15):ub(i)=2
    if u_b=0 then anim_v_door(dx,dy,70,74,78):ub(i)=1
    if u_b=5 then anim_v_door(dx,dy,69,73,77):ub(i)=0
  else 'horizontal door
    if u_b=1 then anim_h_door(dx,dy,17,9,91):ub(i)=2
    if u_b=0 then anim_h_door(dx,dy,88,89,86):ub(i)=1
    if u_b=5 then anim_h_door(dx,dy,84,85,86):ub(i)=0
  end if
end sub


  'door is open, and is closed at the end of this animation
sub close_door(i,dx,dy)
  local u_b=ub(i)
  if ua(i)=1 then 'vertical door
    if u_b=4 then anim_v_door(dx,dy,dpm(uc(i),1),72,76):ub(i)=5
    if u_b=3 then anim_v_door(dx,dy,69,73,77):ub(i)=4
    if u_b=2 then anim_v_door(dx,dy,70,74,78):ub(i)=3
  else 'horizontal door
    if u_b=4 then anim_h_door(dx,dy,80,81,dpm(uc(i),0)):ub(i)=5
    if u_b=3 then anim_h_door(dx,dy,84,85,86):ub(i)=4
    if u_b=2 then anim_h_door(dx,dy,88,89,86):ub(i)=3
  end if
end sub


  'update the world map with the current vertical door tiles
sub anim_v_door (dx,dy,a,b,c)
  mid$(lv$(dy-1),dx+1,1)=chr$(a)
  mid$(lv$(dy),dx+1,1)=chr$(b)
  mid$(lv$(dy+1),dx+1,1)=chr$(c)
  writeworld_m(2,2)   'only repaint relevant section of screen
end sub


  'update the world map with the current horizontal door tiles
sub anim_h_door (dx,dy,a,b,c)
  mid$(lv$(dy),dx,1)=chr$(a)
  mid$(lv$(dy),dx+1,1)=chr$(b)
  mid$(lv$(dy),dx+2,1)=chr$(c)
  writeworld_m(2,2)   'only repaint relevant section of screen
end sub


  'write UNIT position back in UNIT attributes (also player)
sub store_unit_pos(unit,x,y)
  ux(unit)=x:uy(unit)=y
end sub


  'write player from sprites in library
Sub writeplayer_m(h,v,w)
  FRAMEBUFFER write l
  Box xs,ys,24,24,1,0,0
  playersp=8*(v=-1)+4*(h=1)+12*(h=-1)
  Sprite compressed sprite_index(playersp+playermv+16*w),xs,ys
  playermv=(playermv+1) Mod 4
End Sub


  'uses tiles stored in library to build up screen
Sub writeworld_m(xm,ym)
  FRAMEBUFFER write n
  For xn=-xm To xm
    For yn=-ym To ym
      x=xs+xn*24
      y=ys+yn*24
      'load tile from world map
      spn=Asc(Mid$(lv$(yp+yn),xp+xn+1,1))
      Sprite compressed tile_index(spn),x,y
    Next
  Next
End Sub


  'get tile attribute for this tile
Function get_ta(x,y)
  Local til
  til=Asc(Mid$(lv$(y),x+1,1))
  get_ta = Asc(Mid$(ta$,til+1,1))
End Function


  'loads the world map and tile attributes and unit attributes
Sub loadworld

  'UNIT attributes in integer arrays for speed
  Dim UT(63)       'unit type
  Dim UX(63)      'unit X coordinate
  Dim UY(63)      'unit X coordinate
  Dim UA(63)       'unit A parameter
  Dim UB(63)       'unit B parameter
  Dim UC(63)       'unit C parameter
  Dim UD(63)       'unit D parameter
  Dim UH(63)       'unit health

  Dim LV$(63) Length 128  'the map 128h x 64v with tile numbers
  Dim DP$                 '255(+1) destruct paths
  Dim TA$                 '255(+1) tile attributes

  'load world map and attributes
  Open "data\level-a" For input As #1

  'load UNIT attributes in arrays
  for i=0 to 63: ut(i)=asc(input$(1,#1)):next
  for i=0 to 63: ux(i)=asc(input$(1,#1)):next
  for i=0 to 63: uy(i)=asc(input$(1,#1)):next
  for i=0 to 63: ua(i)=asc(input$(1,#1)):next
  for i=0 to 63: ub(i)=asc(input$(1,#1)):next
  for i=0 to 63: uc(i)=asc(input$(1,#1)):next
  for i=0 to 63: ud(i)=asc(input$(1,#1)):next
  for i=0 to 63: uh(i)=asc(input$(1,#1)):next


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

  'door post markings
  '0=unlocked, 1=spades, 2=heart, 3=star
  'h/v=closed     h0 h1 h2 h3  v0 v1 v2 v3
  dim dpm(3,1) = (82,92,93,94, 68,71,75,79)

End Sub


  'load tile and sprite indexes for locations in the library
Sub loadindex
  'get start addresses
  Local hlt=Peek(cfunaddr health)
  Local spr=Peek(cfunaddr SPRITES)
  Local til0=Peek(cfunaddr TILE0)
  Local til1=Peek(cfunaddr TILE1)
  Local til2=Peek(cfunaddr TILE2)

  'build global index file
  Dim sprite_index(&h60)
  Dim health_index(10)
  Dim tile_index(&hff)

  Open "graphics/hltindex.txt" For input As #1
  For i=0 To 5
    Input #1,a$
    health_index(i)=hlt+Val(a$)
  Next
  Close #1

  Open "graphics/spindex.txt" For input As #1
  For i=0 To &h5f
    Input #1,a$
    sprite_index(i)=spr+Val(a$)
  Next
  Close #1

  Open "graphics/tile_index0.txt" For input As #1
  For i=0 To &h3f
    Input #1,a$
    tile_index(i)=til0+Val(a$)
  Next i
  Close #1

  Open "graphics/tile_index1.txt" For input As #1
  For i=&h40 To &h7f
    Input #1,a$
    tile_index(i)=til1+Val(a$)
  Next
  Close #1

  Open "graphics/tile_index2.txt" For input As #1
  For i=&h80 To &hff
    Input #1,a$
    tile_index(i)=til2+Val(a$)
  Next
  Close #1

End Sub
