  'petrobot testbed picomite VGA V50708RC10
  
  'in scan_units the AI now works for the whole map (at 20ms loop burden)
  'uncomment the limit test to get speed back
  
  ' system setup -----------------------------------------------------
  Game_Mite=0
  If Game_Mite Then
    init_game_ctrl ' Init Controller on Game*Mite
  Else
    MODE 2
  EndIf
  Option default integer
  FRAMEBUFFER layer 9 'color 9 is transparant
  Font 9
  
  'startup screen show on N
  init_map_support
  show_intro
  preload_sfx
  CLS
  
  'get world map
  loadworld
  loadindex
  
  
  
  'startup defines ---------------------------------------------------
  
  'heartbeat
  Const h_beat = 120 'ms
  
  'define some constants
  Const b_pus=32,b_see=16,b_dmg=8,b_mov=4,b_hov=2,b_wlk=1   'attribute flags
  Const p_w=0,p_s1=1,p_s2=2,p_m1=3,p_m2=4   'player modes walk, search, move1+2
  
  'defines
  Const hsize=128,vsize=64  'world map 128x64
  Const xm=5:ym=3           'view window on map # of tiles E-w and N-S
  Const xs=5*24:ys=4*24     'window centre with 24*24 tile reference
  
  'start positions player in map in # tiles
  xp=UX(0):yp=UY(0)   'xp and yp are used parallel to UX(0) and UY(0)
  
  'default text settings
  textc=RGB(green):bckgnd=0'black
  
  'write frame
  Load image "images/layerb.bmp"
  
  'start music/sfx modfile
  Play stop:Play modfile "Music\sfcmetallicbop2.mod"   'sfx combined with music
  
  
  'write initial world
  map_mode=0              'overview world map off
  writeworld_n(xm,ym)     'initialwold
  ani_timer=1             'world animations
  
  'initial player attributes
  pl_sp=0        'default player is facing you
  pl_mv=0        'walking move 0..4
  pl_wp=0        'weapon holding (0=none, 1=pistol, 2=plasma
  pl_md=0        'player mode (0=walk/fight, 1=search, 2,3=move)
  pl_it=0        'player item
  writeplayer_cls(0,0,pl_wp)
  
  'init inventory
  pl_ky=0         'player has all 3 keys
  Dim pl_pa(2)=(0,0,0)  'none,pistol ammo(1),plasma ammo(2)
  pl_ps=0         'plasma ammo
  pl_bo=0         '#bombs
  pl_em=0         '#EMP
  pl_mk=0         'medkit
  pl_ma=0         '#magnets
  
  UH(0)=5 'debug
  
  
  'main player input loop -----------------------------------------
  Do
    'player input through keyboard, clearing buffer, check loop time
    k$="":Text 290,0,Right$("00"+Str$(Timer,3,0),3)
    Do
      tmp$=Inkey$
      If tmp$<>"" Then k$=tmp$  'keep last valid key
    Loop Until Timer>h_beat
    Timer =0
    ky=Asc(k$)
    
    
    
    'update the world in the viewing window
    If map_mode=0 Then
      
      'the viewe modes animated in the main loop
      If pl_md=p_s1 Then show_mode(&h53)  'show viewer
      If pl_md=p_s2 Then anim_viewer
      If pl_md=p_m1 Then show_mode(&h55)  'show hand
      if pl_md=p_m2 then sprite_item(&h55,xs+24*hm,ys+24*vm) 'hand over object
      
      'the detailed world in N
      writeworld_n(xm,ym)                 'scroll world
      ani_tiles                           'change the animated Tiles
      
      'write UNITS from UNIT ATTRIB array to layer L
      writesprites
      
    Else
      
      anim_map
      
    EndIf
    
    
    
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
          writeplayer_cls(h,v,pl_wp)    'update player tile
          vp=v:hp=h
        EndIf
      EndIf
      
      'executing the search mode, player facing search direction
      If pl_md=p_s1 Then pl_md=p_s2
      
      'executing move mode
      If pl_md=p_m2 Then exec_move              'second stage
      If pl_md=p_m1 Then pl_md=p_m2:target_move 'first stage
      
    EndIf
    
    'update player
    update_player 'needs an update
    
    
    'change player mode
    If k$="z" Then pl_md=p_s1   'z initiates search mode
    If k$="m" Then pl_md=p_m1   'm initiates move mode
    
    'player changes items or weapons
    If ky=145 Then pl_wp=(pl_wp+1) Mod 3:show_weapon:writeplayer_cls(hp,vp,pl_wp)  'toggle weapon
    If ky=146 Then pl_it=(pl_it+1) Mod 5:show_item    'toggle ite,
    If k$=" " Then use_item                           'SPACE use item
    
    'switch map mode
    If ky=9 Then 'TAB key show map + toggle player/robots
      Select Case map_mode
        Case 0
          map_mode=1      'stop showing normal mode
          renderLiveMap   'show map mode
        Case 1
          map_mode=2
        Case 2
          map_mode=0
          FRAMEBUFFER write l:CLS  col%(5):FRAMEBUFFER write n 'clear layer
          writeplayer_cls(hp,vp,pl_wp)
      End Select
    EndIf
    
    'fire weapon
    if shot=1 then shot=0':writeplayer_cls(hp,vp,pl_wp)
    If k$="w" Then shot=1:fire_ns(-1)
    If k$="a" Then shot=1:fire_ew(-1)
    If k$="s" Then shot=1:fire_ns(1)
    If k$="d" Then shot=1:fire_ew(1)
    
    If k$="M" Then 'toggle music ON/OFF
      'do something
    EndIf
    
    'investigate AI UNITs status and activate and process
    scan_units
    
  Loop Until ky=27   'quit when <esc> is pressed
  
  MODE 1
  Memory
End
  
  
  
  ' screen oriented subs ------------------------------------------
  
  'write UNITS's for 0..31 to screen
sub writesprites
  local i,j,dx,dy
  framebuffer write l
  cls  col%(5)  'start with a clean sheet
  for i=0 to 31
    dx=UX(i)-UX(0):dy=UY(i)-UY(0)
    if ABS(dx)<=xm and ABS(dy)<=ym then 'is it visible ?
      select case UT(i)
        case 1  'player
          Sprite compressed sprite_index(UA(i)),xs,ys,9
        case 2,3,17,18
          Sprite compressed sprite_index(UA(i)),xs+24*dx,ys+24*dy,9
        case 12 'shoot up
          UT(i)=0 'shot fired -> clear
          for j=-1 to UC(i) step -1
            Sprite compressed tile_index(UA(i)),xs,ys+24*j,0
          next
        case 13 'shoot down
          UT(i)=0 'shot fired -> clear
          for j=1 to UC(i)
            Sprite compressed tile_index(UA(i)),xs,ys+24*j,0
          next
        case 14 'shoot left
          UT(i)=0 'shot fired -> clear
          for j=-1 to UC(i) step -1
            Sprite compressed tile_index(UA(i)),xs+24*j,ys,0
          next
        case 15 'shoot right
          UT(i)=0 'shot fired -> clear
          for j=1 to UC(i)
            Sprite compressed tile_index(UA(i)),xs+24*j,ys,0
          next
        case 70' a special case where UX and UY are absolute coordinates
          UT(i)=0 'free slot after use
          Sprite compressed sprite_index(UA(i)),UB(i),UC(i),9
      end select
    end if
  next i
  framebuffer write n
end sub
  
  'this adds a special UNIT sprite at absolute screen coordinates in UNIT array
sub sprite_item(sprt,xabs,yabs)
  '@harm: the UNIT TYPE = decimal 70, UB=x and UC=y are absolute, UA=sprite number
  local i
  i=findslot()
  If i<32 then
    UT(i)=70                          'the spcial case
    UA(i)=sprt:UB(i)=xabs:UC(i)=yabs  'the important data
    UX(i)=xp:UY(i)=yp                 'dummy entries inside view window
  end if
end sub
  
  'show player phase 1,2,3 looking_glass or hand in phase 0
Sub show_mode(tile)
  Static x
  sprite_item(tile,xs,ys) 'over player
  If x=0 Then sprite_item(tile,xs,ys) 'over player
  'x=1,2,3 do nothing
  x=(x+1) And 3
End Sub
  
  'animate map with player, or robots
Sub anim_map
  Static t
  Local i
  FRAMEBUFFER write l
  If t=0 Then CLS  col%(5) 'transparent layer
  If t=2 Then
    If map_mode=1 Then
      Box 6+2*UX(0),44+2*UY(0),2,2,,RGB(red)          'show player
    Else
      For i=1 To 27
        If UT(i)>0 Then
          Box 6+2*UX(i),44+2*UY(i),2,2,,RGB(fuchsia)    'show all 27 bots
        EndIf
      Next
    EndIf
  EndIf
  t=(t+1) And 3
  FRAMEBUFFER write n
End Sub
  
  'show the looking glass over the search area
Sub anim_viewer
  Static p
  If p=0 Then v1=v:h1=h:v2=30*v1+ys:h2=30*h1+xs
  Inc p,1
  
  'use v2 and h2 to determine the search area
  Select Case p
    Case 4,8
      sprite_item(&h53,h2+8,v2+8)
    Case 3,7
      sprite_item(&h53,h2+8,v2-8)
    Case 2,6
      sprite_item(&h53,h2-8,v2-8)
    Case 1,5
      sprite_item(&h53,h2-8,v2+8)
    Case 9
      p=0
  End Select
  If p=0 Then exec_viewer
End Sub
  
  'show hand over the tile that is to be moved
Sub target_move
  ox=xp+h:oy=yp+v             'map coordinates of object to be moved
  hm=h:vm=v                   'global for use later
  If (get_ta(ox,oy) And b_mov) = b_mov Then     'can object be moved?
    sprite_item(&h55,24*h+xs,24*v+ys)
  Else
    writecomment("Object cannot be moved")
    Play modsample s_error,4
    pl_md=pl_w  'get out of move mode
  EndIf
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
    Text 272,54,Str$(pl_pa(pl_wp),3,0),,,,textc,bckgnd
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
  Static oldhealth
  UX(0)=xp:UY(0)=yp
  If oldhealth<>UH(0) Then
    Sprite compressed health_index(Int((12-UH(0))/2)),272,160
    oldhealth=UH(0)
    For i=1 To 12
      If i > oldhealth Then
        Box 267+4*i,220,3,5,1,bckgnd,bckgnd
      Else
        Box 267+4*i,220,3,5,1,textc,textc
      EndIf
    Next
  EndIf
End Sub
  
  'write player ON LAYER l from sprites in library after clearing L
Sub writeplayer_cls(h,v,w)
  '@harm: use UA(i) as sprite number
  pl_sp=8*(v=-1)+4*(h=1)+12*(h=-1)      'sprite matching orientation
  UA(0)=pl_sp+pl_mv+16*w                'store in UNIT log
  pl_mv=(pl_mv+1) Mod 4                 'anime player
End Sub
  
  'blit only player from sprites in library, only in map_mode=0
Sub spriteplayer(h,v,w)
  '@harm: use UA(i) as sprite number
  pl_sp=8*(v=-1)+4*(h=1)+12*(h=-1)      'sprite matching orientation
  UA(0)=pl_sp+pl_mv+16*w                'store in UNIT log
End Sub
  
  'uses tiles stored in library to build up screen
Sub writeworld_n(xm,ym)
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
  
Sub walk_bot_h(i,dx,dy,hov)
  '@harm: for robots use UC(i) to determine walking direction (default 0)
  '@harm: use UD(i) for speed counters
  '@harm: use UA(i) as sprite number
  Local xy
  static s
  UD(i)=(UD(i)+1) Mod 3
  If UD(i)=0 Then
    s=(s+1) and 3
    xy=UX(i)+2*(UC(i))-1        'new position
    If (get_ta(xy,UY(i)) And (b_wlk+hov)) Then
      UX(i)=xy                  'go to new position
    Else
      UC(i)=1-UC(i)             'invert direction bit
    EndIf
  EndIf
  UA(i)=&h31+s+(hov=0)*4        'notify new sprite for drawing
End Sub
  
  
Sub walk_bot_v(i,dx,dy,hov)
  '@harm: for robots use UC(i) to determine walking direction (default 0)
  '@harm: use UD(i) for speed counters
  '@harm: use UA(i) as sprite number
  Local xy
  static s  'for sprite animation
  UD(i)=(UD(i)+1) Mod 3
  If UD(i)=0 Then
    s=(s+1) and 3
    xy=UY(i)+2*(UC(i))-1  'new position
    If (get_ta(UX(i),xy) And (b_wlk+hov)) Then
      UY(i)=xy            'go to new position
    Else
      UC(i)=1-UC(i)       'invert direction bit
    EndIf
  EndIf
  UA(i)=&h31+s+(hov=0)*4  'notify new sprite for drawing
End Sub
  
  
  'AI oriented sub ---------------------------------------------------
  'this is the main AI loop where AI all units are processed
  
  'scan through units in the unit attributes
  'this routine runs in layer L, only some UNITS revert to n
  
Sub scan_units
  Local i,dx,dy,nearx,neary,xy
  FRAMEBUFFER write l
  
  For i=1 To 47                       'unit 0 = player, skip player
    'here we branch to different units
    dx=UX(i)-xp:dy=UY(i)-yp
    nearx=Abs(dx):neary=Abs(dy)
    '    If nearx<=xm And neary<=ym Then   'withing viewing window
    Select Case UT(i)
      Case 2 'hoverbot_h
        walk_bot_h(i,dx,dy,b_hov)
      Case 3 'hoverbot_v
        walk_bot_v(i,dx,dy,b_hov)
      Case 4 'hoverbot attack
      Case 5 'hoverbot_chase
      Case 7 'transporter
      Case 9 'evilbot chase player
        Sprite compressed sprite_index(&h39),xs+24*dx,ys+24*dy
      Case 10 'automatic doors
        FRAMEBUFFER write n
        If nearx<2 And neary<2 Then   'operate door
          If UC(i)=0 Then
            open_door(i,UX(i),UY(i))
          ElseIf (UC(i) And pl_ky) Then
            open_door(i,UX(i),UY(i))
          Else
            If once<>UC(i) Then
              once = UC(i)
              writecomment("You need a "+keyz$(UC(i))+" key")
            EndIf
          EndIf
        Else                          'we are far enough so close the door
          close_door(i,UX(i),UY(i))
        EndIf
        FRAMEBUFFER write l
      Case 11 'small explosion
      Case 12 'pistol fire up
      Case 13 'pistol fire down
      Case 14 'pistol fire left
      Case 15 'pistol fire right
      Case 16 'trash compactor
      Case 17 'rollerbot_v
        walk_bot_v(i,dx,dy,0)
      Case 18 'rollerbot_h
        walk_bot_h(i,dx,dy,0)
    End Select
    '    EndIf
  Next i
  '  spriteplayer(hp,vp,pl_wp)
  FRAMEBUFFER write n
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
End Sub
  
  'update the world map with the current horizontal door tiles
Sub anim_h_door(dx,dy,a,b,c)
  MID$(lv$(dy),dx,1)=Chr$(a)
  MID$(lv$(dy),dx+1,1)=Chr$(b)
  MID$(lv$(dy),dx+2,1)=Chr$(c)
End Sub
  
  
  'subs to support player handling ------------------------------------
  
  'find a free slot in the UNIT array (28...31)
function findslot()
  local i=28
  do
    if UT(i)=0 then
      exit do
    else
      inc i,1
    end if
  loop until i=32
  findslot=i
end function
  
  
  'weapon fire in horizontal direction
Sub fire_ew(p)
  '@harm: UD() is the tile of the target (or 0)
  '@harm: UC() is length of the fire line
  '@harm: UB() is the UNIT hit
  '@harm: UA() is the fire line sprite
  If pl_pa(pl_wp)>0 Then
    
    Local x=0,i,b=0,d=0
    i=findslot()      'find a weapon slot in UNIT array
    if i<32 then
      UX(i)=xp:UY(i)=yp 'default
      
      Do
        Inc x,p
        If (get_ta(xp+x,yp) And b_dmg) Then 'this tile gets the damage
          UX(i)=xp+x                'here the damage is actually done
          inc x,-p
          Exit
          'else if 0 then 'see if there is a unit
          'check_units
          'store gunshot in UNIT attributes target UNIT i @ (xp+x,yp)
        ElseIf (get_ta(xp+x,yp) And (b_wlk+b_hov+b_see))=0 Then
          inc x,-p
          Exit      'stopped by wall
        EndIf
      Loop Until Abs(x)=xm
      
      'register for screen
      if abs(x)>=1 then
        UT(i)=14+(x>0):UC(i)=x:UA(i)=249-4*pl_wp
        UB(i)=b:UD(i)=d
      end if
    end if
    
    'play sound
    if pl_wp=2 then play modsample s_plasma,4 else Play Modsample s_dspistol,4
    
    'reduce ammo
    Inc pl_pa(pl_wp),-1
    show_weapon
    
  EndIf
End Sub
  
  'weapon fire in vertical direction
Sub fire_ns(p)
  '@harm: UD() is the tile of the target (or 0)
  '@harm: UC() is length of the fire line
  '@harm: UB() is the UNIT hit
  '@harm: UA() is the sprite
  If pl_pa(pl_wp)>0 Then
    
    Local y=0,i,b=0,d=0
    i=findslot()      'find a weapon slot in UNITarray
    if i<32 then
      UX(i)=xp:UY(i)=yp 'default
      
      Do
        Inc y,p
        If (get_ta(xp,yp+y) And b_dmg) Then 'this tile gets the damage
          'store gunshot in UNIT attributes target object @ (xp,yp+y)
          UY(i)=yp+y
          inc y,-p
          Exit
          'else if 0 then 'see if there is a unit
          'check_units
          'store gunshot in UNIT attributes target UNIT i @ (xp,yp+y)
        ElseIf (get_ta(xp,yp+y) And (b_wlk+b_hov+b_see))=0 Then
          inc y,-p
          Exit 'stopped by wall
        EndIf
      Loop Until Abs(y)=ym
      
      'register for screen
      if abs(y)>=1 then
        UT(i)=12+(y>0):UC(i)=y:UA(i)=248-4*pl_wp
        UB(i)=b:UD(i)=d
      end if
    end if
    
    'play sound
    if pl_wp=2 then play modsample s_plasma,4 else Play Modsample s_dspistol,4
    
    'reduce ammo
    Inc pl_pa(pl_wp),-1
    show_weapon
    
  EndIf
End Sub
  
  
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
          Play Modsample s_found_item,4
          'add it to the inventory
          Select Case UT(i)
            Case 0'key
              pl_ky=pl_ky Or 2^UA(i)
              show_keys
              a$="found "+keyz$(UA(i)+1)+" KEY"
            Case 1'bomb
              Inc pl_bo,UA(i)
              pl_it=4:show_item
              a$="found "+Str$(UA(i))+" TIME BOMBS"
            Case 2'emp
              Inc pl_em,UA(i)
              pl_it=2:show_item
              a$="found "+Str$(UA(i))+" EMP's"
            Case 3'pistol
              Inc pl_pa(1),UA(i)
              pl_wp=1:show_weapon
              a$="found PISTOL with "+Str$(UA(i))+" bullets"
            Case 4'plasma
              Inc pl_pa(2),UA(i)
              pl_wp=2:show_weapon
              a$="found PLASMA gun with "+Str$(UA(i))+" shots"
            Case 5'medkit
              Inc pl_mk,UA(i)
              pl_it=1:show_item
              a$="found MEDKIT healing "+Str$(UA(i))
            Case 3'magnet
              Inc pl_ma,UA(i)
              pl_it=3:show_item
              a$="found "+Str$(UA(i))+" MAGNETS"
          End Select
          writecomment(a$)
          'if closed box, then open box
          j=Asc(Mid$(lv$(yp+v1),xp+h1+1,1))
          If j=&h29 Then j=&h2A
          If j=&hC7 Then j=&hC6
          MID$(lv$(yp+v1),xp+h1+1,1)=Chr$(j)
        EndIf
      EndIf
    EndIf
  Next
  If a$="Nothing found" Then Play Modsample s_error,4:writecomment(a$)
  pl_md=p_w     'at the end, free player
End Sub
  
  'move and return to walk mode
Sub exec_move
  Local tl$
  tx=ox+h:ty=oy+v   'determine target coordinates
  
  'check if a move can be executed between object and target
  If (get_ta(tx,ty) And b_pus) Then     'you can push towards this position
    'if (is there not a unit on this tile) then
    'execute the move on the world map (swap tiles)
    tl$ = Mid$(lv$(ty),tx+1,1)
    MID$(lv$(ty),tx+1,1)=Mid$(lv$(oy),ox+1,1)
    If Asc(tl$)=148 Then tl$=Chr$(9)  'if trash compactor then floor
    MID$(lv$(oy),ox+1,1)=tl$
    'play sound
    Play modsample s_move,4
    'end if
  Else
    writecomment("Object cannot move here")
    Play modsample s_error,4
  EndIf
  
  ''erase hand and exit move mode
  'FRAMEBUFFER write l
  'Box xs+(ox-xp)*24,ys+(oy-yp)*24,24,24,,col%(5),col%(5)
  'FRAMEBUFFER write n
  pl_md=p_w                       'at the end, free player
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
  For my = 0 To 63
    mp=Peek(varaddr lv$(my)):yy=44+(my<<1)
    For mx = 1 To 128
      Box 4+2*mx,yy,2,2,,CL(Peek(BYTE mp+mx))
    Next
  Next
End Sub
  
  'pre-load sound effects @Martin
Sub preload_sfx
  'for sfcmetallicbop.mod
  s_dsbarexp=16:s_dspistol=17:s_beep=18:s_beep2=19:s_cycle_item=20:s_cycle_weapon=21
  s_door=22:s_emp=23:S_error=24:s_found_item=25:s_magnet2=26:s_medkit=27:s_move=28
  s_plasma=29:s_shock=30:s_dsbarexp=31
  
End Sub
  
  'this animates the fans, flags, water and the servers in the world map
Sub ani_tiles '@added by Martin
  'changing the Source adress for the Animated Tiles
  Static a1,a2,a3
  If ani_timer=2 Then   'change every second main loop
    tile_index(196)=tla_index(8+a3)   'large fan 196
    tile_index(197)=tla_index(10+a3)  'large fan 197
    tile_index(200)=tla_index(12+a3)  'large fan 200
    tile_index(201)=tla_index(14+a3)  'large fan 201
    Inc a3:a3=a3 And 1
    tile_index(204)= tla_index(20+a2) 'WATER 204
    Inc a2:a2=a2 And 3
    ani_timer=0
  EndIf
  
  'these animations change every main loop
  tile_index(66) = tla_index(a1)    'FLAG 66
  tile_index(148)=tla_index(4+a1)   'TRASH COMPACTOR 148
  tile_index(143)=tla_index(16+a1)  'SERVER 143
  Inc a1: a1=a1 And 3
  
  Inc ani_timer
End Sub
  
Sub use_item
  Local a
  Select Case pl_it
    Case 1  'medkit
      a=12-UH(0)  'how many lives we lost
      a=Min(a,pl_mk)
      Inc pl_mk,-a:Inc UH(0),a
      Play modsample s_medkit,4
      writecomment("you gained "+Str$(a)+" life")
  End Select
  show_item
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
  Open "data\level-"+Chr$(97+Map_Nr) For input As #1
  'Open "data\level-a" For input As #1
  
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
  
End Sub
  
  'read color values and MAP_NAME$
Sub init_map_support
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
  
  Open "sprites/hlt_index.txt" For input As #1
  For i=0 To 5
    Input #1,a$
    health_index(i)=hlt+Val(a$)
  Next
  Close #1
  
  Open "sprites/spr_index.txt" For input As #1
  For i=0 To &h5f
    Input #1,a$
    sprite_index(i)=spr+Val(a$)
  Next
  Close #1
  
  Open "tiles/tile0_index.txt" For input As #1
  For i=0 To &h3f
    Input #1,a$
    tile_index(i)=til0+Val(a$)
  Next i
  Close #1
  
  Open "tiles/tile1_index.txt" For input As #1
  For i=&h40 To &h7f
    Input #1,a$
    tile_index(i)=til1+Val(a$)
  Next
  Close #1
  
  Open "tiles/tile2_index.txt" For input As #1
  For i=&h80 To &hff
    Input #1,a$
    tile_index(i)=til2+Val(a$)
  Next
  Close #1
  
  Open "tiles/tla_index.txt" For input As #1
  For i=0 To &h17
    Input #1,a$
    tla_index(i)=tlx+Val(a$)
  Next
  Close #1
  
  Open "sprites/key_index.txt" For input As #1
  For i=0 To 2
    Input #1,a$
    key_index(i)=keys+Val(a$)
  Next
  Close #1
  
  Open "sprites/item_index.txt" For input As #1
  For i=0 To 5
    Input #1,a$
    item_index(i)=itemx+Val(a$)
  Next
  Close #1
  
End Sub
  
  
  'startup Menu-------------------------------------@Martin
Sub show_intro
  'load screen
  FRAMEBUFFER write l:CLS :FRAMEBUFFER write n
  Load image "images/introscreen.bmp",0,10
  FRAMEBUFFER write l: fade_in: :FRAMEBUFFER write n
  'set Map to 0, Menu State to 1
  Local Message$(4) length 40
  Message$(1)="...use UP & DOWN, Space or 'A' to select"
  Message$(2)="   ...use LEFT & RIGHT to select Map    "
  Message$(3)="  ...use LEFT & RIGHT cange Difficulty  "
  
  Map_Nr=0:MS=1:Difficulty=1
  ' get space for the 4th Menu entry
  Sprite 28,18,28,10,88,24:Box 32,21,80,34,,0,0
  ' start playing the intro Music
  Play Modfile "music\metal_heads.mod"
  show_menu 1
  
  'Display Map Name
  Text 12,70,UCase$(map_nam$(Map_Nr))
  'sl=1 'set menu slot to top
  '--- copyright notices etc
  Text 0,224,Message$(1),,,,Col%(3)
  MSG$=String$(36,32)
  MSG$=MSG$+"This could be a nice place for some greetings, thanks, "
  MSG$=MSG$+"copyright notices and anything else that you "
  MSG$=MSG$+"absolutely have to tell to annoy the users - "
  MSG$=MSG$+"Keep in mind that a string cannot be longer than 255 chracters ;-) "
  flip=0
  MT=0
  
  'check player choice
  kill_kb
  Do
    tp$=Mid$(MSG$,1+MT,41)
    If flip Then Inc MT:If mt>Len(MSG$) Then MT=0
    cs$ = "" : k$=Inkey$: cs$=contr_input$()
    
    If k$<>"" And cs$="" Then
      If k$=Chr$(129) Or Instr(cs$,"DOWN") Then Inc MS,(MS<4)
      If k$=Chr$(128) Or Instr(cs$,"UP")   Then Inc MS,-(MS>1)
      If k$=" " Or Instr(cs$,"BUT-A") Then
        Select Case MS
          Case 1
            FRAMEBUFFER write L:fade_out:FRAMEBUFFER write n
            Exit 'intro and go on with the Program
          Case 2
            'select map
            kill_kb
            Text 0,224,message$(2),,,,Col%(3)
            Do
              k$=Inkey$: cs$=contr_input$()
              If  k$<>"" And cs$="" Then
                If k$=Chr$(130) Or Instr(cs$,"LEFT") Then Inc Map_Nr,-(Map_Nr>0)
                If k$=Chr$(131) Or Instr(cs$,"RIGHT")Then Inc Map_Nr,(Map_Nr<13)
                If k$=" " Or Instr(cs$,"BUT-A") Then
                  Text 0,224,message$(1),,,,Col%(3): Exit
                EndIf
                Text 12,70,UCase$(map_nam$(Map_Nr))
              EndIf
            Loop
          Case 3
            'select DIFFICULTY
            Text 0,224,message$(3),,,,Col%(3)
          Case 4
            'select CONTROLS
        End Select
      EndIf
    EndIf
    
    show_menu MS
    Text 0-(4*Flip),0,tp$,,,,Col%(2):Flip=Not(FLIP)
    Pause 50: 'Contr_input$() is to fast to see what position you are in
  Loop
  Play stop
End Sub
  
  'remove duplicate keys and key repeat
Sub kill_kb
  Do :Loop Until Inkey$="": ' empty keyboard buffer (just in case)
End Sub
  
  'start menu selection list
Sub show_menu(n1)
  Local FC=col%(14),BG=0,f2=col%(3),b2=col%(9)
  Colour FC,BG :If n1=1 Then Colour f2,b2
  Text 32,22,"START     "
  Colour FC,BG :If n1=2 Then Colour f2,b2
  Text 32,30,"SELECT MAP"
  Colour FC,BG :If n1=3 Then Colour f2,b2
  Text 32,38,"DIFFICULTY"
  Colour FC,BG :If n1=4 Then Colour f2,b2
  Text 32,46,"CONTROLS  "
  Colour FC,BG
End Sub
  
Sub fade_in
  Local n,x,y
  For n=0 To 7
    For x=n To 320 Step 8:Line x,0,x,240,,col%(5):Next
    For y=n To 240 Step 8:Line 0,y,320,y,,col%(5):Next
    Pause 80
  Next
End Sub
  
Sub fade_out
  Local n,x,y
  For n=0 To 7
    For x=n To 320 Step 8:Line x,0,x,240,,0:Next
    For y=n To 240 Step 8:Line 0,y,320,y,,0:Next
    Pause 80
  Next
End Sub
  
  
  
  '---joystick/Gamepad specific settings
  '   Settings for Game*Mite
Sub init_game_ctrl
  Local i%
  ' Initialise GP8-GP15 as digital inputs with PullUp resistors
  For i% = 8 To 15
    SetPin MM.Info(PinNo "GP" + Str$(i%)), Din, PullUp
  Next
End Sub
  
Function contr_input$()
  If Not gamemite Then Contr_input$="":Exit Function
  Local  n,ix% = Port(GP8, 8) Xor &h7FFF,cs$="",bit
  Local m$(7)=("DOWN","LEFT","UP","RIGHT","SELECT","START","BUT-B","BUT-A")
  ' which buttons are currently pressed
  For n=0 To 7
    bit=2^n:If ix% And bit Then Inc cs$,m$(n)+" "
  Next
  Contr_input$=cs$
End Function
  
  
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
