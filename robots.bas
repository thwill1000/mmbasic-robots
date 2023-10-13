  'petrobot testbed picomite VGA V50708RC4


  ' system setup -----------------------------------------------------

  MODE 2
  Option default integer
  FRAMEBUFFER layer

  'startup screen show on N
  Play stop:Play modfile "Music\metal_heads.mod"
  Load image "images/introscreen.bmp",0,20   'startup screen show on N
  'to do --- the menu stuff and so on
  Do :Loop Until Inkey$=" "
  preload_SFX
  CLS

  'get world map
  loadworld
  loadindex



  'startup defines ---------------------------------------------------

  'heartbeat
  Const h_beat = 120 'ms

  'define some constants
  Const b_pus=32,b_see=16,b_dmg=8,b_mov=4,b_hov=2,b_wlk=1   'attribute flags
  Const p_w=0,p_s1=1,p_m1=2,p_m2=3       'player modes walk, search, move1+2

  'defines
  Const hsize=128,vsize=64  'world map 128x64
  Const xm=5:ym=3           'view window on map # of tiles E-w and N-S
  Const xs=5*24:ys=4*24     'window centre with 24*24 tile reference

  'start positions player in map in # tiles
  xp=UX(0):yp=UY(0)   'xp and yp are used parallel to UX(0) and UY(0)

  'default search/view mode = off
  view_ph=15          'nothing to search

  'default text settings
  Font 9
  textc=RGB(green):bckgnd=0'black

  'write frame
  Load image "images/layerb.bmp"

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
  pl_ky=0 '7        'player has all 3 keys
  pl_pa=0         'gun ammo
  pl_ps=0         'plasma ammo
  pl_bo=0         '#bombs
  pl_em=0         '#EMP
  pl_mk=0         'medkit
  pl_ma=0         '#magnets


ani_timer=1


  'main player input loop -----------------------------------------
  Do
    'check response
    Text 290,0,Right$("00"+Str$(Timer,3,0),3)
    Do :Loop Until Timer>h_beat
    Timer =0

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
    If view_ph<14 Then
      If view_ph<4 Then show_viewer
      If view_ph>4 Then anim_viewer
    EndIf

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
    Ani_Tiles     'change the animated Tiles

  Loop Until k$="q"   'quit when q is pressed

  MODE 1
  Memory
End



  ' screen oriented subs ------------------------------------------

'show player phase 1,2,3 looking glass phase 0
Sub show_viewer
  FRAMEBUFFER write l
  Select Case view_ph
    Case 0
      Sprite compressed sprite_index(&h53),xs,ys  'over player
    Case 1
      writeplayer_m(0,0,pl_wp)                    'restore player
  End Select
  view_ph=(view_ph+1) Mod 4
  FRAMEBUFFER write n
End Sub

  'show the looking glass over the search area
Sub anim_viewer
  FRAMEBUFFER write l
  If view_ph=5 Then
    v1=v:h1=h:v2=30*v1+ys:h2=30*h1+xs
  EndIf

  'use v2 and h2 to determine the search area
  Select Case view_ph
    Case 8,12
      Box h2+8,v2-8,24,24,1,0,0
      Sprite compressed sprite_index(&h53),h2+8,v2+8
    Case 7,11
      Box h2-8,v2-8,24,24,1,0,0
      Sprite compressed sprite_index(&h53),h2+8,v2-8
    Case 6,10
      Box h2-8,v2+8,24,24,1,0,0
      Sprite compressed sprite_index(&h53),h2-8,v2-8
    Case 5,9
      Box h2+8,v2+8,24,24,1,0,0
      Sprite compressed sprite_index(&h53),h2-8,v2+8
    Case 13
      Box h2+8,v2+8,24,24,1,0,0
  End Select
  FRAMEBUFFER write n
  Inc view_ph,1
  If view_ph=14 Then exec_viewer
End Sub

'show the hand tile over the player
Sub show_move
End Sub

  'show keys in frame
Sub show_keys
  Local i
  For i=0 To 2
    If pl_ky And 1<<i Then
      Sprite compressed key_index(i),271+16*i,124
    EndIf
  Next
End Sub

  'show weapon in frame
Sub show_weapon
  If pl_wp>0 Then
    Sprite compressed item_index(pl_wp-1),272,38
    Text 272,32,hidden$(pl_wp+2),,,,textc,bckgnd
    Select Case pl_wp
      Case 1
        Text 272,54,Str$(pl_pa,3,0),,,,textc,bckgnd
      Case 2
        Text 272,54,Str$(pl_ps,3,0),,,,textc,bckgnd
    End Select
  Else
    Box 272,32,48,30,1,bckgnd,bckgnd
  EndIf
End Sub

  'show item in frame
Sub show_item
  If pl_it>0 Then
    Local a$,b$
    Sprite compressed item_index(pl_it+1),272,81
    Select Case pl_it
      Case 1'medkit
        a$="medkit"
        b$=Str$(pl_mk,3,0)
      Case 2'emp
        a$="emp   "
        b$=Str$(pl_em,3,0)
      Case 3'magnet
        a$="magnet"
        b$=Str$(pl_ma,3,0)
      Case 4'bomb
        a$="bomb  "
        b$=Str$(pl_bo,3,0)
    End Select
    Text 272,72,a$,,,,textc,bckgnd
    Text 272,104,b$,,,,textc,bckgnd
  Else
    Box 272,72,48,39,1,bckgnd,bckgnd
  EndIf
End Sub

  'update player parameters in unit attributes
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

  'scan through units in the unit attributes
Sub scan_UNITS
  Local i,dx,dy,nearx,neary
  For i=1 To 47                       'unit 0 = player, skip player
    unit_type=UT(i)

    'here we branch to different units

    'this section handles automatic doors
    If unit_type=10 Then            'this is a door
      dx=UX(i):dy=UY(i)
      nearx=Abs(dx-xp):neary=Abs(dy-yp)
      If nearx<2 And neary<2 Then   'operate door
        If UC(i)=0 Then
          open_door(i,dx,dy)
        ElseIf (UC(i) And pl_ky) Then
          open_door(i,dx,dy)
        Else
          If once<>UC(i) Then
            once = UC(i)
            writecomment("You need a "+keyz$(UC(i))+" key")
          EndIf
        EndIf
      Else                          'we are far enough so close the door
        close_door(i,dx,dy)
      EndIf
    EndIf

  Next i
End Sub

  'door is closed, and is open at the end of this animation
Sub open_door(i,dx,dy)
  Local u_b=UB(i)
  If u_b=5 Then Play modsample s_door,4
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
  If u_b=2 Then Play modsample s_door,4
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

  'find the items in viewer area in the unit attributes
Sub exec_viewer
  'do things
  Local i,j,a$="Nothing found"
  For i=48 To 63 'hidden units
    If UT(i)>127 Then
      If UX(i)=xp+h1 Or UX(i)+UC(i)=xp+h1 Then
        If UY(i)=yp+v1 Or UY(i)+UD(i)=yp+v1 Then
          'found hidden item
          UT(i)=UT(i)-128   'mark it as found
          a$="found "+hidden$(UT(i))+" ammo "+Str$(UA(i))
          writecomment(a$):Play Modsample s_found_item,4
          'add it to the inventory
          Select Case UT(i)
            Case 0'key
              pl_ky=pl_ky Or UA(i)
              show_keys
            Case 1'bomb
              Inc pl_bo,UA(i)
              pl_it=4:show_item
            Case 2'emp
              Inc pl_emp,UA(i)
              pl_it=2:show_item
            Case 3'pistol
              Inc pl_pa,UA(i)
              pl_wp=1:show_weapon
            Case 4'plasma
              Inc pl_ps,UA(i)
              pl_wp=2:show_weapon
            Case 5'medkit
              Inc pl_mk,UA(i)
              pl_it=1:show_item
            Case 3'magnet
              Inc pl_ma,UA(i)
              pl_it=3:show_item
          End Select
          'if closed box, then open box
          j=Asc(Mid$(lv$(yp+v1),xp+h1+1,1))
          If j=&h29 Then j=&h2A
          If j=&hC7 Then j=&hC6
          MID$(lv$(yp+v1),xp+h1+1,1)=Chr$(j)
        EndIf
      EndIf
    EndIf
  EndIf
Next
If a$="Nothing found" Then Play Modsample s_error,4:writecomment(a$)
pl_md=p_w     'at the end, free player
End Sub

'move and return to walk mode
Sub exec_move
'do things
pl_md=p_w     'at the end, free player
End Sub


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
Sub writecomment(a$)
Local i
For i=0 To 2:comment$(i)=comment$(i+1):Next
comment$(3)=Left$(a$+Space$(30),30)
For i = 0 To 3
  Text 10,200+10*i,comment$(i),,,,textc,bckgnd
Next i
End Sub

'scale the world map to overview mode @Martin
Sub renderLiveMap
Local integer mx,my,mp,yy,CL(256)
Local t$
'Tile colors
T$="00077777977770777770000A0000B0006740694B66EB60E777E722B724B66070"
T$=T$+"0367000700770007770000700707077880000007776777077707770778888887"
T$=T$+"7067700770000007700400000000000000000730073000000000000000000000"
T$=T$+"0007700770898EEAAA233867772777677700A00AA0000000000000000000000"
For mx=1 To 255:CL(mx)=col%(Val("&H"+Mid$(T$,mx,1))):Next
  For my = 0 To 64:mp=Peek(varaddr lv$(my)):yy=44+(my<<1)
  For mx = 1 To 128:Box 4+2*mx,yy,2,2,,CL(Peek(BYTE mp+mx)):Next
Next
End Sub

'pre-load sound effects @Martin
Sub preload_SFX
Play stop:Play modfile "Sounds\sfx.mod"
s_dsbarexp=1:s_dspistol=2:s_beep=3:s_beep2=4:s_cycle_item=5:s_cycle_weapon=6
s_door=7:s_emp=8:S_error=9:s_found_item=10:s_magnet2=11:s_medkit=12:s_move=13
s_plasma=14:s_shock=15:s_dsbarexp=16
End Sub



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
Dim hidden$(6) length 6 = ("key","bomb","emp","pistol","plasma","medkit","magnet")
Dim keyz$(3) length 5 = (" ","SPADE","HEART","STAR")

'empty comment string
Dim comment$(3) length 30
For i=0 To 3:comment$(i)=Space$(30):Next

'read color values and MAP_NAME$
Dim Col%(15):Restore colors:For f=1 To 15:Read Col%(f):Next f
Dim map_nam$(13) length 16 :Restore map_names:For f=0 To 13:Read map_nam$(f):Next f

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

'@added by Martin ---------------------------------------
Sub Ani_tiles
'changing the Source adress for the Animated Tiles
If ani_timer=2 Then
 '196,197,200,201
  tile_index(196)=tla_index(8+a3)
  tile_index(197)=tla_index(10+a3)
  tile_index(200)=tla_index(12+a3)
  tile_index(201)=tla_index(14+a3)
  Inc a3:a3=a3 And 1
  ani_timer=0
 EndIf
Inc ani_timer
  ' WATER 204
  tile_index(204)= tla_index(20+a1)
  'FLAG 66
  tile_index(66) = tla_index(a1)
  Inc a1: a1=a1 And 3
  'TRASH COMPACTOR 148
  tile_index(148)=tla_index(4+a2)
  'SERVER 143
  tile_index(143)=tla_index(19+a2)
  Inc a2: a2=a2 And 3

End Sub

colors:
'--Colorscheme accordung to Spritecolors
Data RGB(BLUE),RGB(GREEN),RGB(CYAN),RGB(RED)
Data RGB(MAGENTA),RGB(YELLOW),RGB(WHITE),RGB(MYRTLE)
Data RGB(COBALT) ,RGB(MIDGREEN),RGB(CERULEAN),RGB(RUST)
Data RGB(FUCHSIA),RGB(BROWN),RGB(LILAC)
'
map_names:
Data "01-research lab","02-headquarters","03-the village","04-the islands"
Data "05-downtown","06-pi university","07-more islands","08-robot hotel"
Data "09-forest moon","10-death tower","11-river death","12-bunker"
Data "13-castle robot","14-rocket center"

' C64_PetsciiRobotsFont  Martin Herhaus
' Font type    : Full (96 Characters)
' Font size    : 8x8 pixels
' Memory usage : 768
DefineFont #9
60200808
00000000 00000000 38383838 00380038 8844EEEE 00000000 62FF6200 0062FF62
FEC0F61C 0070DE06 381CEEE6 00CEEE70 7EE0E4FC 00FEE4E4 20103838 00000000
10100804 00040810 08081020 00201008 3C7E1800 0000187E FE383800 00003838
00000000 20103838 7E000000 00000000 00000000 00383800 381C0E06 00C0E070
C6C2C2FE 00FE8686 10101030 007C7C10 FE0202FE 00FEC0C0 FE0404FC 00FE0606
C6C6C0C0 000606FE FE8080FE 00FE0606 FE808CFC 00FE8686 3E0202FE 00303030
FE4C4C7C 00FEC6C6 FE8686FE 00060606 00383800 00003838 00383800 20103838
70381C0E 000E1C38 007E0000 0000007E 0E1C3870 0070381C 3E0ECEFE 00300030
41899576 36494122 FE46467E 00868686 FE8C8CFC 00FE8686 808686FE 00FE8282
C68484FC 00FEC6C6 FE8080FE 00FEC0C0 FEC080FE 00C0C0C0 9E8082FE 00FE8686
FE868686 00868686 1810107E 007E1818 06040404 00FE8686 F8848282 0086868C
C0404040 00FEC0C0 8696AEC6 00868686 9EB6E6C6 0086868E 868282FE 00FE8686
FE8282FE 00C0C0C0 C4C4C4FC 00F6CECC FE8C8CFC 00C6C6C6 FEC0C2FE 00FEC202
1818187E 00181818 86868686 00FE8686 86868686 00385C8E 86868686 00C6AE96
7CC2C2C2 00868686 7E464646 00181818 380C06FE 00FEC060 10100804 00040810
3870E0C0 00060E1C 08081020 00201008 38381010 0000006C 00000000 FF000000
FC40623C 00FEE0E0 86FE0000 00F68E86 C2FEC0C0 00FEE2C2 C2FE0000 00FEE2C0
86FE0606 00FE8E86 C2FE0000 00FEE0FE C0C03E00 00E0E0F8 86FE0000 FE0EFE86
C2FEC0C0 00E2E2C2 1838001C 001C1C18 0C0C000C FE8E0E0C 86868080 008E8EFC
18181838 001C1C18 C2FE0000 00EAEACA C2FE0000 00E2E2C2 86FE0000 00FE8E86
C2FE0000 E0E0FEC2 8EFE0000 0E0EFE8E C2FE0000 00E0E0C0 C0FE0000 00FE0EFE
C0F8C0C0 00FEE2C0 86860000 00FE8E86 C2C20000 0070E8C4 CACA0000 00FEE2CA
74E20000 008E5C38 86860000 FE0EFE86 06FE0000 00FEE0FE B838383A 003A3838
38383838 00383838 3E3838B8 00B83838 AA55AA55 AA55AA55 B195423C 3C4295B1
End DefineFont
