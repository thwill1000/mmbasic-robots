  'petrobot testbed picomite VGA V50708RC4
  
  
  ' system setup -----------------------------------------------------
  
  MODE 2
  Option default integer
  FRAMEBUFFER layer
  
  'startup screen show on N
  '  Load image "images/introscreen.bmp"
  '  Pause 1000
  '  CLS
  
  'get world map
  loadworld
  loadindex
  
  
  
  'startup defines ---------------------------------------------------
  
  'heartbeat
  const h_beat = 120 'ms
  
  'define some constants
  const b_pus=32,b_see=16,b_dmg=8,b_mov=4,b_hov=2,b_wlk=1   'attribute flags
  const p_w=0,p_s1=1,p_m1=2,p_m2=3       'player modes walk, search, move1+2
  
  'defines
  const hsize=128,vsize=64  'world map 128x64
  const xm=5:ym=3           'view window on map # of tiles E-w and N-S
  const xs=5*24:ys=4*24     'window centre with 24*24 tile reference
  
  'start positions player in map in # tiles
  xp=UX(0):yp=UY(0)   'xp and yp are used parallel to UX(0) and UY(0)
  
  'default search/view mode = off
  view_ph=15          'nothing to search
  
  textc=RGB(green):bckgnd=RGB(myrtle)
  
  'write frame
  Load image "images/layer.bmp"
  
  'write initial world
  writeworld_m(xm,ym)
  
  'initial player attributes
  pl_sp=0        'default player is facing you
  pl_mv=0        'walking move 0..4
  pl_wp=0        'weapon holding (0=none, 1=pistol, 2=plasma
  pl_md=0        'player mode (0=walk/fight, 1=search, 2,3=move)
  pl_it=0        'player item
  writeplayer_m(0,0,pl_wp)
  
  'init inventory
  pl_ky=7'0        'player has all 3 keys
  pl_pa=0         'gun ammo
  pl_ps=0         'plasma ammo
  pl_bo=0         '#bombs
  pl_em=0         '#EMP
  pl_mk=0         'medkit
  pl_ma=0         '#magnets
  
  
  
  'main player input loop -----------------------------------------
  Do
    'check response
    text 290,0,right$("00"+str$(timer,3,0),3)
do:loop until timer>h_beat
    timer=0
    
    'player input through keyboard
    k$=Inkey$:ky=Asc(k$)
    
    'player controls movement of player character
    v=(ky=129)-(ky=128)
    h=(ky=131)-(ky=130)
    If h+v<>0 Then                    'when move key pressed
      
      If pl_md=p_w Then                 'in move mode, move
        'check if we can walk, then walk
        If (get_ta(xp+h,yp+v) And b_wlk) Then
          xp=xp+h:yp=yp+v             'new player position
          xp=Min(Max(xp,5),hsize-6)   'don't fall off the map
          yp=Min(Max(yp,3),vsize-4)
          store_unit_pos(0,xp,yp)     'store pos for future use
          writeplayer_m(h,v,pl_wp)    'update player tile
        EndIf
      EndIf
      
      'executing the search mode, player facing search direction
      If view_ph<4 Then view_ph=5:writeplayer_m(h,v,pl_wp)
      
      'If pl_md=p_m2 Then
      'Text 150,0," move2 ",,,,textc,bckgnd
      'exec_move
      'EndIf
      'If pl_md=p_m1 Then
      'Text 150,0," move1 ",,,,textc,bckgnd
      'show_move
      'pl_md=p_m2
      'EndIf
      
    EndIf
    
    'investigate AI UNITs status and activate and process
    scan_UNITS
    
    'update player
    update_player
    
    'animations
    if view_ph<14 then
      if view_ph<4 then show_viewer
      if view_ph>4 then anim_viewer
    end if
    
    'change player mode
    If k$="z" Then pl_md=p_s1:view_ph=0
    'If k$="m" Then pl_md=p_m1:show_move
    
    
    'development support, for debugging ---------------------------
    If ky=27 Then 'esc
      Save image "pet.bmp"
    EndIf
    If k$="o" Then
      show_keys
    EndIf
    If k$="p" Then
      pl_wp=(pl_wp+1) Mod 3
      writeplayer_m(h,v,pl_wp)  'to show weapon in hand of player
      show_weapon
    EndIf
    If k$="i" Then
      pl_it=(pl_it+1) Mod 5
      show_item
    EndIf
    'end debug commands ------------------------------------------
    
    'update the world in the viewing window
    writeworld_m(xm,ym)       'scroll world
    
    
  Loop Until k$="q"   'quit when q is pressed
  
  mode 1
  Memory
End
  
  
  
  ' screen oriented subs ------------------------------------------
sub show_viewer
  'show player phase 1,2,3 looking glass phase 0
  framebuffer write l
  select case view_ph
    case 0
      sprite compressed sprite_index(&h53),xs,ys  'over player
    case 1
      writeplayer_m(0,0,pl_wp)                    'restore player
  end select
  view_ph=(view_ph+1) mod 4
  framebuffer write n
end sub
  
  
sub anim_viewer
  framebuffer write l
  if view_ph=5 then
    v1=v:h1=h:v2=36*v1+ys:h2=36*h1+xs
  end if
  
  'use v2 and h2 to determine the search area
  select case view_ph
    case 8,12
      box h2+12,v2-12,24,24,1,0,0
      sprite compressed sprite_index(&h53),h2+12,v2+12
    case 7,11
      box h2-12,v2-12,24,24,1,0,0
      sprite compressed sprite_index(&h53),h2+12,v2-12
    case 6,10
      box h2-12,v2+12,24,24,1,0,0
      sprite compressed sprite_index(&h53),h2-12,v2-12
    case 5,9
      box h2+12,v2+12,24,24,1,0,0
      sprite compressed sprite_index(&h53),h2-12,v2+12
    case 13
      box h2+12,v2+12,24,24,1,0,0
  end select
  framebuffer write n
  inc view_ph,1
  if view_ph=14 then exec_viewer
end sub
  
sub show_move
end sub
  
Sub show_keys
  Local i
  For i=0 To 2
    If pl_ky And 1<<i Then
      Sprite compressed key_index(i),271+16*i,124
    EndIf
  Next
End Sub
  '  Dim hidden$(6) length 6 = ("key","bomb","emp","pistol","plasma","medkit","magnet")
  
Sub show_weapon
  If pl_wp>0 Then
    Sprite compressed item_index(pl_wp-1),272,38
    Text 272,32,hidden$(pl_wp+2),,,,textc,bckgnd
    select case pl_wp
      case 1
        Text 272,54,Str$(pl_pa,3,0),,,,textc,bckgnd
      case 2
        Text 272,54,Str$(pl_ps,3,0),,,,textc,bckgnd
    end select
  Else
    Box 272,32,48,30,1,bckgnd,bckgnd
  EndIf
End Sub
  
Sub show_item
  If pl_it>0 Then
    local a$,b$
    Sprite compressed item_index(pl_it+1),272,81
    select case pl_it
      case 1'medkit
        a$="medkit"
        b$=str$(pl_mk,3,0)
      case 2'emp
        a$="emp   "
        b$=str$(pl_em,3,0)
      case 3'magnet
        a$="magnet"
        b$=str$(pl_ma,3,0)
      case 4'bomb
        a$="bomb  "
        b$=str$(pl_bo,3,0)
    end select
    Text 272,72,a$,,,,textc,bckgnd
    Text 272,104,b$,,,,textc,bckgnd
  Else
    Box 272,72,48,39,1,bckgnd,bckgnd
  EndIf
End Sub
  
Sub update_player
  Local i
  UX(0)=xp:UY(0)=yp
  If oldhealth<>UH(0) Then
    Sprite compressed health_index(Int((12-UH(0))/2)),272,160
    oldhealth=UH(0)
    For i=1 To oldhealth
      If i > oldhealth Then
        Box 267+4*i,220,3,5,1,bckgnd
      Else
        Box 267+4*i,220,3,5,1,textc,textc
      EndIf
    Next
  EndIf
End Sub
  
  'write player from sprites in library
Sub writeplayer_m(h,v,w)
  'write player on layer L
  FRAMEBUFFER write l
  Box xs,ys,24,24,1,0,0
  pl_sp=8*(v=-1)+4*(h=1)+12*(h=-1)
  Sprite compressed sprite_index(pl_sp+pl_mv+16*w),xs,ys
  pl_mv=(pl_mv+1) Mod 4
  FRAMEBUFFER write n
End Sub
  
  'uses tiles stored in library to build up screen
Sub writeworld_m(xm,ym)
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
  
  
  
  
  'AI oriented sub ---------------------------------------------------
  'this is the main AI loop where AI all units are processed
Sub scan_UNITS
  Local i,dx,dy,nearx,neary
  For i=1 To 47                       'unit 0 = player, skip player
    unit_type=UT(i)
    
    'here we branch to different units
    
    'this section handles automatic doors
    If unit_type=10 Then              'this is a door
      dx=UX(i):dy=UY(i)
      nearx=Abs(dx-xp):neary=Abs(dy-yp)
      If nearx<2 and neary<2 Then   'operate door
        open_door(i,dx,dy)
      Else                          'we are far enough so close the door
        close_door(i,dx,dy)
      EndIf
    EndIf
    
  Next i
End Sub
  
  'door is closed, and is open at the end of this animation
Sub open_door(i,dx,dy)
  Local u_b=UB(i)
  If UA(i)=1 Then 'vertical door
    If u_b=1 Then anim_v_door(dx,dy,27,9,15):UB(i)=2
    If u_b=0 Then anim_v_door(dx,dy,70,74,78):UB(i)=1
    If u_b=5 Then anim_v_door(dx,dy,69,73,77):UB(i)=0
  Else 'horizontal door
    If u_b=1 Then anim_h_door(dx,dy,17,9,91):UB(i)=2
    If u_b=0 Then anim_h_door(dx,dy,88,89,86):UB(i)=1
    If u_b=5 Then anim_h_door(dx,dy,84,85,86):UB(i)=0
  EndIf
End Sub
  
  'door is open, and is closed at the end of this animation
Sub close_door(i,dx,dy)
  Local u_b=UB(i)
  If UA(i)=1 Then 'vertical door
    If u_b=4 Then anim_v_door(dx,dy,dpm(UC(i),1),72,76):UB(i)=5
    If u_b=3 Then anim_v_door(dx,dy,69,73,77):UB(i)=4
    If u_b=2 Then anim_v_door(dx,dy,70,74,78):UB(i)=3
  Else 'horizontal door
    If u_b=4 Then anim_h_door(dx,dy,80,81,dpm(UC(i),0)):UB(i)=5
    If u_b=3 Then anim_h_door(dx,dy,84,85,86):UB(i)=4
    If u_b=2 Then anim_h_door(dx,dy,88,89,86):UB(i)=3
  EndIf
End Sub
  
  'update the world map with the current vertical door tiles
Sub anim_v_door(dx,dy,a,b,c)
  MID$(lv$(dy-1),dx+1,1)=Chr$(a)
  MID$(lv$(dy),dx+1,1)=Chr$(b)
  MID$(lv$(dy+1),dx+1,1)=Chr$(c)
  writeworld_m(2,2)   'only repaint relevant section of screen
End Sub
  
  'update the world map with the current horizontal door tiles
Sub anim_h_door(dx,dy,a,b,c)
  MID$(lv$(dy),dx,1)=Chr$(a)
  MID$(lv$(dy),dx+1,1)=Chr$(b)
  MID$(lv$(dy),dx+2,1)=Chr$(c)
  writeworld_m(2,2)   'only repaint relevant section of screen
End Sub
  
  
  'subs to support player handling ------------------------------------
sub exec_viewer
  'do things
  local i,j,a$="Nothing found"
  for i=48 to 63 'hidden units
    if UT(i)>127 then
      if UX(i)=xp+h1 or UX(i)+UC(i)=xp+h1 then
        if UY(i)=yp+v1 or UY(i)+UD(i)=yp+v1 then
          'found hidden item
          UT(i)=UT(i)-128   'mark it as found
          a$="found "+hidden$(UT(i))+" ammo "+str$(UA(i))
          writecomment(a$)
          'add it to the inventory
          select case UT(i)
            case 0'key
              pl_ky=pl_ky or UA(i)
            case 1'bomb
              inc pl_bo,UA(i)
            case 2'emp
              inc pl_emp,UA(i)
            case 3'pistol
              inc pl_pa,UA(i)
            case 4'plasma
              inc pl_ps,UA(i)
            case 5'medkit
              inc pl_mk,UA(i)
            case 6'magnet
              inc pl_ma,UA(i)
          end select
          'if closed box, then open box
          j=asc(mid$(lv$(yp+v1),xp+h1+1,1))
          if j=&h29 then j=&h2A
          if j=&hC7 then j=&hC6
          mid$(lv$(yp+v1),xp+h1+1,1)=chr$(j)
        end if
      end if
    end if
  end if
next
if a$="Nothing found" then writecomment(a$)
pl_md=p_w     'at the end, free player
end sub

sub exec_move
'do things
pl_md=p_w     'at the end, free player
end sub


'generic subs for gameplay -------------------------------------------
'write unit position back in unit attributes (also player)
Sub store_unit_pos(unit,x,y)
UX(unit)=x:UY(unit)=y
End Sub

'get tile attribute for this tile
Function get_ta(x,y)
Local til
til=Asc(Mid$(lv$(y),x+1,1))
get_ta = Asc(Mid$(ta$,til+1,1))
End Function

'write text in the comment area at bottom screen rolling upwards
sub writecomment (a$)
local i
for i=0 to 2:comment$(i)=comment$(i+1):next
comment$(3)=left$(a$+space$(30),30)
for i = 0 to 3
  text 10,200+10*i,comment$(i),,,,textc,bckgnd
next i
end sub




' subs for game setup -------------------------------------------------
'loads the world map and tile attributes and unit attributes
Sub loadworld

'unit attributes in integer arrays for speed
Dim UT(63)       'unit type
Dim UX(63)       'unit x coordinate
Dim UY(63)       'unit x coordinate
Dim UA(63)       'unit a parameter
Dim UB(63)       'unit b parameter
Dim UC(63)       'unit c parameter
Dim UD(63)       'unit D parameter
Dim UH(63)       'unit health

Dim LV$(63) Length 128  'the map 128h x 64v with tile numbers
Dim DP$                 '255(+1) destruct paths
Dim TA$                 '255(+1) tile attributes

'load world map and attributes
Open "data\level-a" For input As #1

'load unit attributes in arrays
For i=0 To 63: UT(i)=Asc(Input$(1,#1)):Next
For i=0 To 63: UX(i)=Asc(Input$(1,#1)):Next
For i=0 To 63: UY(i)=Asc(Input$(1,#1)):Next
For i=0 To 63: UA(i)=Asc(Input$(1,#1)):Next
For i=0 To 63: UB(i)=Asc(Input$(1,#1)):Next
For i=0 To 63: UC(i)=Asc(Input$(1,#1)):Next
For i=0 To 63: UD(i)=Asc(Input$(1,#1)):Next
For i=0 To 63: UH(i)=Asc(Input$(1,#1)):Next


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
Dim dpm(3,1) = (82,92,93,94, 68,71,75,79)

'item names
Dim itemz$(5) length 6 = ("pistol","plasma","medkit"," emp  ","magnet"," bomb ")
Dim hidden$(6) length 6 = ("key","bomb","emp","pistol","plasma","medkit","magnet")

'empty comment string
dim comment$(3) length 30
for i=0 to 3:comment$(i)=space$(30):next

End Sub


'load tile and sprite indexes for locations in the library
Sub loadindex
'get start addresses
Local hlt=Peek(cfunaddr HEALTH)
Local spr=Peek(cfunaddr SPRITES)
Local til0=Peek(cfunaddr TILE0)
Local til1=Peek(cfunaddr TILE1)
Local til2=Peek(cfunaddr TILE2)
Local itemx=Peek(cfunaddr ITEM)
Local tlx=Peek(cfunaddr TLA)
Local keys=Peek(cfunaddr KEY)

'build global index file
Dim sprite_index(&h60)
Dim health_index(5)
Dim tile_index(&hff)
Dim item_index(5)
Dim tla_index(&h17)
Dim key_index(2)

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
