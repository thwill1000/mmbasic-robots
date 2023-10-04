  'petrobot testbed picomite VGA V50708RC1
  
  MODE 2
  option default integer
  
  'startup screen show on N
  load image "images/introscreen.bmp"
  pause 1000
  cls

  
  'add framebuffer
  FRAMEBUFFER layer
  
  'get world map
  loadworld
  loadindex
  load_comments
  
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

  textc=rgb(green):bckgnd=rgb(myrtle)
  
  
  'write initial world
  writeworld_m(xsm,ysm)
  
  'write frame
  FRAMEBUFFER write L
  Load image "images/layer.bmp"


  'initial player
  pl_sp=0        'default player is facing you
  pl_mv=0        'walking move 0..4
  pl_wp=0        'weapon holding (0=none, 1=pistol, 2=plasma
  pl_md=0        'player mode (0=walk/fight, 1=search, 2=move)
  pl_it=0        'player item
  pl_ky=7        'player has all 3 keys
  writeplayer_m(0,0,pl_wp)
  
 
  'main player input loop
  Do
    
    'player input through keyboard
    k$=Inkey$:ky=Asc(k$)
    
    
    'player controls movement of player character
    v=(ky=129)-(ky=128)
    h=(ky=131)-(ky=130)
    If h+v<>0 Then                    'when move key pressed

      if pl_md=0 then                 'in move mode, move
        'check if we can walk, then walk
        If (get_ta(xp+h,yp+v) And b_wlk) Then
          xp=xp+h:yp=yp+v             'new player position
          xp=Min(Max(xp,5),hsize-6)   'don't fall off the map
          yp=Min(Max(yp,3),vsize-4)
          store_unit_pos(0,xp,yp)     'store pos for future use
'          writeworld_m(xsm,ysm)       'scroll world
          writeplayer_m(h,v,pl_wp)    'update player tile
        EndIf
      endif
      
    EndIf

    framebuffer write l   'this will be come part of the main items routine

    'just testing mode changes
    if pl_md=1 then
      text 150,0,"search",,,,textc,bckgnd 
      pl_md=0
    endif
      
    if pl_md=2 then
      text 150,0," move ",,,,textc,bckgnd
      pl_md=0
    endif

    
    'investigate AI UNITs status and activate and process
    scan_UNITS

    'update player
    update_player

    framebuffer write l   'this will be come part of the main items routine
    
    'development support, for debugging
    If ky=27 Then 'esc
      FRAMEBUFFER write n
      Save image "pet.bmp"
    EndIf
    
    'debug key sprites with o
    if k$="o" then
      show_keys
    end if

    'debug weapen sprites with p
    if k$="p" then
      pl_wp=(pl_wp+1) mod 3
      writeplayer_m(h,v,pl_wp)
      show_weapon
    end if

    'debug items sprites with i
    if k$="i" then
      pl_it=(pl_it+1) mod 5
      show_item
    end if
    
    'examine/search mode
    if k$="x" then pl_md=1
    
    'move object mode
    if k$="m" then pl_md=2

    show_comments(0)

    'after all processing, update the visible screen area
    writeworld_m(xsm,ysm)       
    
    Pause 50
  Loop Until k$="q"   'quit when q is pressed
  
  Memory
End

sub show_keys
  local i
  for i=0 to 2
    if pl_ky and 1<<i then
      Sprite compressed key_index(i),271+16*i,124
    end if
  next
end sub


sub show_weapon
      if pl_wp>0 then
        Sprite compressed item_index(pl_wp-1),272,38
        text 272,32,itemz$(pl_wp-1),,,,textc,bckgnd
        text 272,54,str$(100,3,0),,,,textc,bckgnd
      else  
        box 272,32,48,30,1,bckgnd,bckgnd
      end if
end sub

sub show_item
      if pl_it>0 then
        Sprite compressed item_index(pl_it+1),272,80+4
        text 272,72,itemz$(pl_it+1),,,,textc,bckgnd
      else  
        box 272,72,48,36,1,bckgnd,bckgnd
      end if
end sub
  
sub update_player
  local i
  ux(0)=xp:uy(0)=yp
  if oldhealth<>uh(0) then
    framebuffer write l
    Sprite compressed health_index(int((12-uh(0))/2)),272,160
    oldhealth=uh(0)
    for i=1 to oldhealth
      if i > oldhealth then
        box 267+4*i,220,3,5,1,bckgnd
      else 
        box 267+4*i,220,3,5,1,textc,textc
      end if
    next
  end if
end sub

  
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
      if nearx<4 and neary<4 then           'we are close to the door, ignore any other
        if nearx<2 and neary<2 then         'operate door
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
'  writeworld_m(2,3)   'only repaint relevant section of screen
end sub
  
  
  'update the world map with the current horizontal door tiles
sub anim_h_door (dx,dy,a,b,c)
  mid$(lv$(dy),dx,1)=chr$(a)
  mid$(lv$(dy),dx+1,1)=chr$(b)
  mid$(lv$(dy),dx+2,1)=chr$(c)
'  writeworld_m(3,2)   'only repaint relevant section of screen
end sub
  
  
  'write UNIT position back in UNIT attributes (also player)
sub store_unit_pos(unit,x,y)
  ux(unit)=x:uy(unit)=y
end sub
  
  
  'write player from sprites in library
Sub writeplayer_m(h,v,w)
  FRAMEBUFFER write l
  Box xs,ys,24,24,1,0,0
  pl_sp=8*(v=-1)+4*(h=1)+12*(h=-1)
  Sprite compressed sprite_index(pl_sp+pl_mv+16*w),xs,ys
  pl_mv=(pl_mv+1) Mod 4
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

sub load_comments
  'dummy for now
  dim txt$(1,3)
  txt$(0,0)="press p to cycle weapons"
  txt$(0,1)="press i to cycle items"
  txt$(0,2)="press o to show cards"
  txt$(0,3)="cursor keys to move"
end sub

sub show_comments(x)
  local i
  for i=0 to 3
    text 20,200+10*i,txt$(x,i),,,,textc,bckgnd
  next
end sub  
  
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

  'item names
  dim itemz$(5) length 6 = ("pistol","plasma","medkit"," emp  ","magnet"," bomb ")
  
End Sub
  
  
  'load tile and sprite indexes for locations in the library
Sub loadindex
  'get start addresses
  Local hlt=Peek(cfunaddr HEALTH)
  Local spr=Peek(cfunaddr SPRITES)
  Local til0=Peek(cfunaddr TILE0)
  Local til1=Peek(cfunaddr TILE1)
  Local til2=Peek(cfunaddr TILE2)
  local itemx=Peek(cfunaddr ITEM)
  local tlx=Peek(cfunaddr TLA)
  local keys=Peek(cfunaddr KEY)

'print hex$(hlt),hex$(spr),hex$(til0),hex$(til1),hex$(til2),hex$(itemx),hex$(tlx),hex$(keys):end

  
  'build global index file
  Dim sprite_index(&h60)
  Dim health_index(5)
  Dim tile_index(&hff)
  dim item_index(5)
  dim tla_index(&h17)
  dim key_index(2)
  
  Open "sprites/health/hlt_index.txt" For input As #1
  For i=0 To 5
    Input #1,a$
    health_index(i)=hlt+Val(a$)
  Next
  Close #1
  
  Open "sprites/spr-files/spr_index.txt" For input As #1
  For i=0 To &h5f
    Input #1,a$
    sprite_index(i)=spr+Val(a$)
  Next
  Close #1
  
  Open "tiles/tiles0_3f/tile0_index.txt" For input As #1
  For i=0 To &h3f
    Input #1,a$
    tile_index(i)=til0+Val(a$)
  Next i
  Close #1
  
  Open "tiles/tiles40_7f/tile1_index.txt" For input As #1
  For i=&h40 To &h7f
    Input #1,a$
    tile_index(i)=til1+Val(a$)
  Next
  Close #1
  
  Open "tiles/tiles80_ff/tile2_index.txt" For input As #1
  For i=&h80 To &hff
    Input #1,a$
    tile_index(i)=til2+Val(a$)
  Next
  Close #1

  Open "tiles/tla/tla_index.txt" For input As #1
  For i=0 To &h17
    Input #1,a$
    tla_index(i)=tlx+Val(a$)
  Next
  Close #1

  Open "sprites/keys/key_index.txt" For input As #1
  For i=0 To 2
    Input #1,a$
    key_index(i)=keys+Val(a$)
  Next
  Close #1

  Open "sprites/items/item_index.txt" For input As #1
  For i=0 To 5
    Input #1,a$
    item_index(i)=itemx+Val(a$)
  Next
  Close #1
  
End Sub
  
  >
