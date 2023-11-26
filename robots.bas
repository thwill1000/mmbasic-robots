  'petrobot testbed picomite VGA V50708RC17 or later
  
  ' system setup -----------------------------------------------------
  Option default integer
  Const Game_Mite=1-(MM.Device$="PicoMiteVGA")
  Const nesPG1=0
  
  If Game_Mite Then
    sc$="f":init_game_ctrl ' Init Controller on Game*Mite
  Else
    sc$="n":MODE 2
  EndIf
  If nesPG1 Then
    config_nes
  EndIf
  
  'screen setup
  If Game_Mite Then FRAMEBUFFER Create 'f
  FRAMEBUFFER layer 9 'color 9 is transparant
  Font 9
  
  'startup screen show on N
  init_map_support
  show_intro
  preload_sfx
  CLS
  
  'get world map
  loadworld
  statistics(start_bots,start_hidden) 'to calculate end screen
  loadgraphics
  
  'adapt for difficulty level
  if Diff_level=2 then
    for i=1 to 27: UT(i)=4*(UT(i)<4):next 'aggro all hoverbots
  end if
  
  
  'startup defines ---------------------------------------------------
  
  'heartbeat
  Dim h_beat=120 'ms
  
  'define some constants
  Const b_hid=64,b_pus=32,b_see=16,b_dmg=8,b_mov=4,b_hov=2,b_wlk=1  'attrib flags
  Const p_w=0,p_s1=1,p_s2=2,p_m1=3,p_m2=4   'player modes walk, search, move1+2
  Const p_bo1=5,p_bo2=6,p_mg1=7,p_mg2=8,p_em1=9,p_em2=10 'place bomb,magnet,emp
  Const p_ele1=11,p_ele2=12,p_death=99 'elevator death
  
  'defines
  Const hsize=128,vsize=64  'world map 128x64
  Const xm=5:ym=3           'view window on map # of tiles E-w and N-S
  Const ys=4*24             'vert window centre with 24*24 tile reference
  Dim xs=5*24               'hor window centre with 24*24 tile reference
  
  'start positions player in map in # tiles
  xp=UX(0):yp=UY(0)         'xp and yp are used parallel to UX(0) and UY(0)
  UA(0)=0                   'UA=sprite number
  
  'default text settings
  textc=RGB(green):bckgnd=0'black
  
  'write frame
  FRAMEBUFFER Write sc$
  Load image "images/layerb.bmp"
  load image "images/strip.bmp"
  If Game_Mite Then FRAMEBUFFER Merge 9
  
  'start music/sfx modfile
  music=1
  '  Play stop:Play modfile "music/sfcmetallicbop2.mod"   'sfx combined with music
  select_music(map_nr mod 3)
  
  'write initial world
  map_mode=0              'overview world map off
  writeworld_n(xm,ym)     'initialwold
  ani_timer=1             'world animations
  
  'game play variables
  spn=0                   'sprite number
  em_on=0                 '1=is emp active
  mg_on=0                 '1=magent in use
  timer=0:playtime=0      'time played in ms
  
  'initial player attributes
  pl_sp=0        'default player is facing you
  pl_mv=0        'walking move 0..4
  pl_wp=0        'weapon holding (0=none, 1=pistol, 2=plasma
  pl_md=0        'player mode (0=walk/fight, 1=search, 2,3=move)
  pl_it=0        'player item
  pl_el=0        'player elevator floor level
  writeplayer(0,0,pl_wp)
  
  'init inventory
  pl_ky=0         'player found 0 keys
  Dim pl_pa(2)=(0,0,0)  'none,pistol ammo(1),plasma ammo(2)
  pl_bo=0         '#bombs
  pl_em=0         '#EMP
  pl_mk=0         'medkit
  pl_ma=0         '#magnets
  
  
  'main player input loop -----------------------------------------
  Do
    'player input through keyboard, clearing buffer, check loop time
    k$="":Text 290,0,Right$("00"+Str$(timer,3,0),3)
    Do
      tmp$=Inkey$
      If tmp$<>"" Then k$=tmp$  'keep last valid key
      If k$="" Then k$=c2k$()
    Loop Until Timer>h_beat
    playtime=playtime+timer:Timer=0
    ky=Asc(k$)
    
    
    If pl_md<p_death Then 'we are live, so let's play the game....
      
      'player controls movement of player character
      v=(ky=129)-(ky=128)
      h=(ky=131)-(ky=130)
      If h+v<>0 Then                        'any cursor key pressed
        
        Select Case pl_md
          Case p_w
            If (get_ta(xp+h,yp+v) And b_wlk) Then 'check if we can walk, then walk
              if has_unit(xp+h,yp+v)=255 then
                xp=xp+h:yp=yp+v               'new player position
                xp=Min(Max(xp,5),hsize-6)     'don't fall off the map
                yp=Min(Max(yp,3),vsize-4)
                store_unit_pos(0,xp,yp)       'store pos for future use
                writeplayer(h,v,pl_wp)        'update player tile
                vp=v:hp=h
              end if
            EndIf
          Case p_s1 'executing the search mode, player facing search direction
            pl_md=p_s2
            writecomment("Searching...")
          Case p_m2 'executing move mode stage 2
            exec_move
          Case p_m1 'executing move mode stage 1
            pl_md=p_m2:target_move
          Case p_mg1 'place magnet and walk away
            pl_md=p_w:place_magnet
          Case p_bo1 'place bomb and walk away
            pl_md=p_w:place_bomb
          case p_ele1
            if v=1 then pl_md=p_ele2 'go back to walking
            if v=0 then next_floor(h)
        End Select
      EndIf
      
      'align xp,yp,UX(0) and UY(0), show UH(0), decide when dead
      update_player
      
      
      'change player mode
      If k$="y" Or k$="z"  Then pl_md=p_s1   'z initiates search mode
      If k$="m" Then pl_md=p_m1   'm initiates move mode
      
      'player changes items or weapons
      Select Case ky
        Case 145 'F1 toggle weapon
          pl_wp=(pl_wp+1) Mod 3
          show_weapon
          writeplayer(hp,vp,pl_wp)
          Play modsample s_cycle_weapon,4
        Case 146 'F2 toggle item
          pl_it=(pl_it+1) Mod 5
          show_item
          Play modsample s_cycle_item,4
        Case 147 'F3 cheat key as long as you are alive
          if UH(0)>0 then
            UH(0)=12                      'full life
            pl_ky=7:show_keys             'all keys
            pl_pa(1)=100:pl_pa(2)=100     'much ammo
            pl_bo=100:pl_em=100:pl_ma=100 'all items
            pl_mk=100                     'full medkit
          end if
        Case 9 'TAB key show map + toggle player/robots
          Select Case map_mode
            Case 0
              map_mode=1      'stop showing normal mode
              renderLiveMap   'show map mode
            Case 1
              if diff_level<2 then map_mode=2 else map_mode=0
            Case 2
              if diff_level<1 then map_mode=3 else map_mode=0
            Case 3
              map_mode=0
              FRAMEBUFFER write l:CLS  col(5):FRAMEBUFFER write sc$ 'clear layer
              writeplayer(hp,vp,pl_wp)
          End Select
      End Select
      
      'fire weapon
      If shot=1 Then shot=0
      If k$="w" Then shot=1:fire_ns(-1):writeplayer(0,-1,pl_wp)
      If k$="a" Then shot=1:fire_ew(-1):writeplayer(-1,0,pl_wp)
      If k$="s" Then shot=1:fire_ns(1):writeplayer(0,1,pl_wp)
      If k$="d" Then shot=1:fire_ew(1):writeplayer(1,0,pl_wp)
      
      If k$=" " Then use_item  '<SPACE> = use item
      If k$="M" Then 'toggle music ON/OFF
        k$=""
        Play stop:music=1-music
        If music Then
          select_music(3) 'only sfx
        Else
          select_music(map_nr mod 3) 'any of 3 songs
        EndIf
      EndIf
      
      'investigate AI UNITs status and activate and process
      AI_units
      
      'update the world in the viewing window
      If map_mode=0 Then
        
        'the viewe modes animated in the main loop
        Select Case pl_md
          Case p_s1
            show_mode(&h53)  'show viewer
          Case p_s2
            anim_viewer
          Case p_m1
            show_mode(&h55)  'show hand
          Case p_bo1,p_mg1,p_em1
            show_mode(&h56)   'arrow cluster
        End Select
        
        'the detailed world in N
        writeworld_n(xm,ym)                 'scroll world
        ani_tiles                           'change the animated Tiles
        
        'write UNITS from UNIT ATTRIB array to layer L
        if Game_Mite=0 then framebuffer wait
        writesprites_l
        
      Else
        
        anim_map
        
      EndIf
      
    EndIf 'pl_md<p_death
    
    if ky=27 then
      writecomment("PAUSE, press <ESC> to quit")
      kill_kb
      do
        pause 100:k$=inkey$:if k$="" then k$=c2k$()
      loop while k$=""
      if k$<>chr$(27) then ky=28:writecomment("continue") 'any value that does not quit
    end if
    
    If Game_Mite Then FRAMEBUFFER merge 9,b
    
  Loop Until ky=27   'quit when <esc> is pressed
  
  game_end
  if Game_Mite then framebuffer copy f,n
  
  pause 5000:play stop:run
  
  '  if not Game_Mite then mode 1
  '  Memory
  
End
  
  
  
  ' screen oriented subs ------------------------------------------
  
  'write UNITS's for 0..31 to screen, this is only the graphical output
Sub writesprites_l
  Local i,j,dx,dy
  FRAMEBUFFER write l
  CLS  col(5)  'start with a clean sheet
  For i=0 To 27
    dx=UX(i)-UX(0):dy=UY(i)-UY(0)
    If Abs(dx)<=xm then
      if Abs(dy)<=ym Then 'is it visible ?
        Select Case UT(i)
          Case 0  'do nothing, but exit select faster
          Case 1  'player
            If UH(i)>0 Then
              Sprite memory sprite_index(UA(i)),xs,ys,9
            Else
              If UA(i)>&h52 Then
                game_over              'show end text
              Else
                Sprite memory sprite_index(UA(i)),xs,ys,9
                h_beat=min(h_beat+40,400):
                Inc UA(i),1 'slow down all, next sprite
              EndIf
            EndIf
          Case 2,3,4
            If UH(i)>0 Then
              Sprite memory sprite_index(UA(i)),xs+24*dx,ys+24*dy,9
            Else
              Sprite memory sprite_index(&h49),xs+24*dx,ys+24*dy,9  'dead bot
            EndIf
          case 5 'bot drowning
            Sprite memory tile_index(UA(i)),xs+24*dx,ys+24*dy,0
          Case 9
            If UH(i)>0 Then
              Sprite memory sprite_index(UA(i)),xs+24*dx,ys+24*dy,9
            Else
              Sprite memory sprite_index(&h4B),xs+24*dx,ys+24*dy,9  'dead bot
            EndIf
          Case 17,18
            If UH(i)>0 Then
              Sprite memory sprite_index(UA(i)),xs+24*dx,ys+24*dy,9
            Else
              Sprite memory sprite_index(&h4A),xs+24*dx,ys+24*dy,9  'dead bot
            EndIf
        End Select
      EndIf
    end if
  Next
  For i=28 To 31
    dx=UX(i)-UX(0):dy=UY(i)-UY(0)
    If Abs(dx)<=xm then
      if Abs(dy)<=ym Then 'is it visible ?
        Select Case UT(i)
          Case 11 'small explosion
            Sprite memory tile_index(UA(i)),xs+24*dx,ys+24*dy,0
          Case 12 'shoot up
            UT(i)=0 'shot fired -> clear
            For j=UD(i) To UC(i) Step -1
              Sprite memory tile_index(UA(i)),xs,ys+24*j,0
            Next
          Case 13 'shoot down
            UT(i)=0 'shot fired -> clear
            For j=UD(i) To UC(i)
              Sprite memory tile_index(UA(i)),xs,ys+24*j,0
            Next
          Case 14 'shoot left
            UT(i)=0 'shot fired -> clear
            For j=UD(i) To UC(i) Step -1
              Sprite memory tile_index(UA(i)),xs+24*j,ys,0
            Next
          Case 15 'shoot right
            UT(i)=0 'shot fired -> clear
            For j=UD(i) To UC(i)
              Sprite memory tile_index(UA(i)),xs+24*j,ys,0
            Next
          Case 70' a special case where UX and UY are absolute coordinates
            If pl_md<>p_m2 Then UT(i)=0             'free slot after use
            Sprite memory sprite_index(UA(i)),UB(i),UC(i),9
          Case 71 'bomb visible
            If UB(i)>0 Then
              Sprite memory sprite_index(UA(i)),xs+24*dx,ys+24*dy,9
            Else
              show_explosion(UA(i),dx,dy,UC(i)) 'explosions in radius < UC
            EndIf
          Case 72 'magnet visible
            If UB(i)>0 Then Sprite memory sprite_index(UA(i)),xs+24*dx,ys+24*dy,9
          case 73 'emp
            if UB(i)<2 then box 0,24,11*24,7*24,,rgb(lilac),rgb(lilac)
          Case 74
            show_explosion(UA(i),dx,dy,UC(i)) 'explosions in radius < UC
        end select
      end if
    end if
  next
  For i=32 To 47
    if UT(i)=19 then
      if UX(i)=UX(0) and UY(i)=UY(0)+1 then 'elevator
        ele_level(pl_el)
      end if
    end if
  next
  FRAMEBUFFER write sc$
End Sub
  
  'this adds a special UNIT sprite at absolute screen coordinates in UNIT array
  'this allows to put sprites off-grid
Sub sprite_item(sprt,xabs,yabs)
  '@harm: the UNIT TYPE = decimal 70, UB=x and UC=y are absolute, UA=sprite number
  Local i
  i=findslot()
  If i<32 Then
    UT(i)=70                          'the special case
    UA(i)=sprt:UB(i)=xabs:UC(i)=yabs  'the important data
    UX(i)=xp:UY(i)=yp                 'dummy entries inside view window
  EndIf
End Sub
  
Sub show_explosion(t,x,y,r) 'show explosion inside view window
  Local i,j,rr
  rr=r-1 'smaller than radius
  For i=-rr To rr
    For j=-rr To rr
      If Abs(i+x)<=xm then
        if Abs(j+y)<=ym Then
          If (get_ta(xp+i+x,yp+j+y) And (b_wlk+b_hov)) Then
            Sprite memory tile_index(t),xs+24*(i+x),ys+24*(j+y),0
          EndIf
        endif
      EndIf
    Next
  Next
End Sub
  
  'show player phase 2,3 looking_glass or hand in phase 0,1
Sub show_mode(tile)
  Static x
  'sprite_item(tile,xs,ys)             'over player
  If x<2 Then sprite_item(tile,xs,ys)  'over player
  'x=2,3 do nothing
  x=(x+1) And 3
End Sub
  
  'game over popup
Sub game_over
  Box xs-40,ys-8,104,1,bckgnd,bckgnd
  Box xs-32,ys,88,24,1,textc,bckgnd
  Text xs-24,ys+8,"GAME OVER",,,,textc,bckgnd
  pl_md=p_death
  framebuffer write sc$:writecomment("press <ESC>"):framebuffer write l
End Sub
  
  'game end screen and statitics
Sub game_end
  FRAMEBUFFER write l:CLS
  pause 100:FRAMEBUFFER write sc$:Load image "images/end.bmp"
  statistics(left_bots,left_hidden)
  playtime=playtime\1000
  hh=playtime\(3600):hhh$=right$("0"+str$(hh),2)
  mm=(playtime-hh*3600)\60:mmm$=right$("0"+str$(mm),2)
  ss=playtime-hh*3600-mm*60:sss$=right$("0"+str$(ss),2)
  Text 180,66,map_nam$(map_nr)
  Text 180,82,hhh$+":"+mmm$+":"+sss$
  Text 180,98,Str$(left_bots)+" / "+Str$(start_bots)
  Text 180,114,Str$(left_hidden)+" / "+Str$(start_hidden)
  Text 180,130,DIFF_LEVEL_WORD$(diff_level)
  Play stop
  If left_bots Then
    Play modfile "music/lose.mod"
  Else
    Play modfile "music/win.mod"
  EndIf
End Sub
  
sub select_music(a)
  Play stop
  select case a
    case 0,1
      Play modfile "music/sfcmetallicbop2.mod"   'sfx combined with music
    case 2
      Play modfile "music/rushin_in-sfx-c.mod"   'sfx combined with music
      '    case 0
      '      Play modfile "music/get psyched.mod"       'sfx combined with music ?
    case 3
      Play modfile "music/petsciisfx.mod"        'only sfx
  end select
end sub
  
  
  'animate map with player, or robots
Sub anim_map
  Static t
  Local i
  FRAMEBUFFER write l
  If t=0 Then CLS col(5) 'transparent layer
  If t=2 Then
    select case map_mode
      case 1
        Box 5+2*UX(0),43+2*UY(0),4,4,1,0,RGB(red)          'show player
      case 2
        For i=1 To 27
          If UT(i)>0 Then
            Box 6+2*UX(i),44+2*UY(i),2,2,,RGB(fuchsia)  'show all 27 bots
          EndIf
        Next
      case 3
        For i=48 To 63
          If UT(i)>127 Then
            Box 6+2*UX(i),44+2*UY(i),2,2,,RGB(black)  'show all hidden
          EndIf
        Next
    end select
  end if
  t=(t+1) And 3
  FRAMEBUFFER write sc$
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
  If (get_ta(ox,oy) And b_mov) Then     'can object be moved?
    sprite_item(&h55,24*h+xs,24*v+ys)
  Else
    writecomment("Object cannot be moved")
    Play modsample s_error,4
    pl_md=p_w  'get out of move mode
  EndIf
End Sub
  
  'show keys in frame
Sub show_keys
  Local i
  For i=0 To 2
    If pl_ky And 1<<i Then
      Sprite memory key_index(i),271+16*i,124
    EndIf
  Next
End Sub
  
  'show weapon in frame
Sub show_weapon
  If pl_wp>0 Then
    Sprite memory item_index(pl_wp-1),272,38
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
    Sprite memory item_index(pl_it+1),272,81
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
    Sprite memory health_index(Min(Int((12-UH(0))/2),5)),272,160
    oldhealth=UH(0)
    For i=1 To 12
      If i > oldhealth Then
        Box 267+4*i,220,3,5,1,bckgnd,bckgnd
      Else
        Box 267+4*i,220,3,5,1,textc,textc
      EndIf
    Next
    If UH(0)=0 Then
      UA(0)=&h4C 'dead sprite
    EndIf
  EndIf
End Sub
  
  
  'write player ON LAYER l from sprites in library after clearing L
Sub writeplayer(h,v,w)
  '@harm: use UA(i) as sprite number
  pl_sp=8*(v=-1)+4*(h=1)+12*(h=-1)        'sprite matching orientation
  IF UA(0)<48 THEN UA(0)=pl_sp+pl_mv+16*w 'store in UNIT log
  pl_mv=(pl_mv+1) Mod 4                   'anime player
End Sub
  
  
  'uses tiles stored in library to build up screen
Sub writeworld_n(xm,ym)
  For xn=-xm To xm
    For yn=-ym To ym
      'load tile from world map
      spn=Peek(byte(lva+(yp+yn)*129)+xp+xn+1)
      Blit memory tile_index(spn),xs+xn*24,ys+yn*24
    Next
  Next
End Sub
  
  'for hoverbot and evilbot use same tracing algorithm
Sub agro_bot(i,dx,dy,hov)
  '@harm: use UD(i) for speed counters
  '@harm: use UA(i) as sprite number
  Local x=dx,y=dy,d,mv=0
  static p
  
  'first try X direction
  if dx<0 then
    x=dx+1:d=&h3d
  elseif dx>0 then
    x=dx-1:d=&h45
  end if
  If (get_ta(xp+x,UY(i)) And (b_wlk+hov)) Then UX(i)=xp+x:mv=(x<>dx)
  
  'if X unseccesfull, try Y
  if mv=0 then
    if dy<0 then
      y=dy+1:d=&h39
    elseif dy>0 then
      y=dy-1:d=&h41
    end if
    If (get_ta(UX(i),yp+y) And (b_wlk+hov)) Then UY(i)=yp+y
  end if
  
  p=(p+1) and 3
  if hov=0 then 'evilbot
    UA(i)=d+p 'animated sprites for drawing
  else 'agro hoverbot
    UA(i)=&h31+p'notify new sprite for drawing
  end if
  
End Sub
  
  
Sub walk_bot_h(i,dx,dy,hov)
  '@harm: for robots use UC(i) to determine walking direction (default 0)
  '@harm: use UD(i) for speed counters
  '@harm: use UA(i) as sprite number
  Local xy
  UD(i)=(UD(i)+1) Mod (2+(hov=b_hov)) 'rollerbor runs faster
  If UD(i)=0 Then
    xy=UX(i)+2*(UC(i))-1        'new position when can walk and no player
    If (get_ta(xy,UY(i)) And (b_wlk+hov))>0 And Not(dy=0 And xy=xp) Then
      UX(i)=xy                  'go to new position
    Else
      UC(i)=1-UC(i)             'invert direction bit
    EndIf
  EndIf
  UA(i)=&h31+(hov=0)*4        'notify new sprite for drawing
End Sub
  
  
Sub walk_bot_v(i,dx,dy,hov)
  '@harm: for robots use UC(i) to determine walking direction (default 0)
  '@harm: use UD(i) for speed counters
  '@harm: use UA(i) as sprite number
  Local xy
  UD(i)=(UD(i)+1) Mod (2+(hov=b_hov)) 'rollerbot is faster
  If UD(i)=0 Then
    xy=UY(i)+2*(UC(i))-1      'new position when can walk and no player
    If (get_ta(UX(i),xy) And (b_wlk+hov))>0 And Not(dx=0 And xy=yp) Then
      UY(i)=xy                'go to new position
    Else
      UC(i)=1-UC(i)           'invert direction bit
    EndIf
  EndIf
  UA(i)=&h31+(hov=0)*4      'notify new sprite for drawing
End Sub
  
  
  'AI oriented sub ---------------------------------------------------
  'this is the main AI loop where AI all units are processed
  
  'scan through units in the unit attributes
  'this routine runs in layer L, only some UNITS revert to n
  
Sub AI_units
  Local i,dx,dy,nearx,neary,xy,j,k
  
  For i=0 To 27 'units
    dx=UX(i)-xp:dy=UY(i)-yp
    nearx=Abs(dx):neary=Abs(dy)
    Select Case UT(i)
      Case 0,1 'player is animated through controls
      Case 2 'hoverbot_h
        If UH(i)>0 Then
          if UC(i)>1 then
            if em_on=0 then dazzle_bot(i)
          else
            if em_on=0 then walk_bot_h(i,dx,dy,b_hov)
          end if
        else  'sudden death" 2 seconds delay for dead body to vanish
          Inc UH(i),-1:If UH(i)<-30 Then UT(i)=0
        EndIf
      Case 3 'hoverbot_v
        If UH(i)>0 Then
          if UC(i)>1 then
            if em_on=0 then dazzle_bot(i)
          else
            if em_on=0 then walk_bot_v(i,dx,dy,b_hov)
          end if
        Else  'sudden death" 2 seconds delay for dead body to vanish
          Inc UH(i),-1:If UH(i)<-30 Then UT(i)=0
        EndIf
      Case 4 'hoverbot attack
        If UH(i)>0 Then
          UD(i)=(UD(i)+1) Mod 3 'adapt for agression level
          if UD(i)=0 then
            if nearx+neary=1 then 'next to player
              if UH(0)>0 then zap(0) 'show damage to player
              UH(0)=max(UH(0)-1,0)  'damage player
            else
              if UC(i)>1 then
                if em_on=0 then dazzle_bot(i)
              else
                if em_on=0 then agro_bot(i,dx,dy,b_hov) 'bot move closer
              end if
            end if
          end if
        Else  'create a 1-2 seconds delay for the dead robot to vanish
          Inc UH(i),-1:If UH(i)<-30 Then UT(i)=0
        EndIf
      Case 5 'hoverbot_drowning
        UD(i)=(UD(i)+1) Mod 6 'adapt for drowning speed
        if UD(i)=0 then
          UA(i)=UA(i)+1
          if UA(i)>&h8e then UT(i)=0
        end if
      Case 9 'evilbot chase player
        If UH(i)>0 Then
          UD(i)=(UD(i)+1) Mod 2 'adapt for agression level
          if UD(i)=0 then
            if nearx+neary=1 then 'next to player
              if UH(0)>0 then zap(0) 'show damage to player
              UH(0)=max(UH(0)-6,0)  'damage player
            else
              if UC(i)>1 then
                if em_on=0 then dazzle_bot(i)
              else
                if em_on=0 then agro_bot(i,dx,dy,0) 'bot move closer
              end if
            end if
          end if
        Else  'create a 1-2 seconds delay for the dead robot to vanish
          Inc UH(i),-1:If UH(i)<-30 Then UT(i)=0
        EndIf
      Case 17 'rollerbot_v
        If UH(i)>0 Then
          if UC(i)>1 then
            if em_on=0 then dazzle_bot(i)
          else
            if em_on=0 then walk_bot_v(i,dx,dy,0)
          end if
          UB(i)=Max(UB(i)-1,0)
          If UB(i)=0 And UH(0)>0 Then
            If dy=0 Then bot_shoot_h(i,dx)
            If dx=0 Then bot_shoot_v(i,dy)
          EndIf
        Else  'create a 1-2 seconds delay for the dead body to vanish
          Inc UH(i),-1:If UH(i)<-30 Then UT(i)=0
        EndIf
      Case 18 'rollerbot_h
        If UH(i)>0 Then
          if UC(i)>1 then
            if em_on=0 then dazzle_bot(i)
          else
            if em_on=0 then walk_bot_h(i,dx,dy,0)
          end if
          UB(i)=Max(UB(i)-1,0)
          If UB(i)=0 And UH(0)>0 Then
            If dy=0 Then bot_shoot_h(i,dx)
            If dx=0 Then bot_shoot_v(i,dy)
          EndIf
        Else  'create a 1-2 seconds delay for the dead body to vanish
          Inc UH(i),-1:If UH(i)<-30 Then UT(i)=0
        EndIf
    End Select
  Next
  
  For i=28 To 31 'tile animations, explosions
    dx=UX(i)-xp:dy=UY(i)-yp
    nearx=Abs(dx):neary=Abs(dy)
    Select Case UT(i)
      Case 11 'small explosion
        Inc UA(i),1:If UA(i)=253 Then UT(i)=0 'done exploding
      Case 71 'bomb
        Inc UB(i),-1
        If UB(i)=0 Then
          do_damage(UX(i),UY(i),UC(i),UD(i)) 'do damage UD in radius < UC
          UA(i)=247 'explosion tile
          Play modsample s_dsbarexp,4
        EndIf
        If UB(i)<0 Then
          xof=4-xof:xs=5*24 - xof 'shake screen
          Inc UA(i),1             'next tile in explosion sequence
          If UA(i)=253 Then xs=5*24:UT(i)=0 'done exploding
        EndIf
      Case 72 'magnet
        Inc UB(i),-1
        If UB(i)<0 Then
          UT(i)=0 'free slot
        Else
          if dx=0 and dy=0 then 'pick up magnet
            UT(i)=0:inc pl_ma,1:show_item
          else
            'check for robot contact with magnet
            j=has_unit(UX(i),UY(i))
            if j>0 and j<255 then 'mark robot
              UT(i)=0:UC(j)=2 'magnet used, bot move direction random
              play modsample s_magnet2,4
            end if
          EndIf
        endif
      Case 73 'emp
        if UB(i)<24 then  'freeze robots 3 seconds
          if em_on=0 then 'only once
            for j=1 to 27 'hoverbots within EMP range
              if UT(j)<5 then
                if abs(UX(j)-xp)<5 then
                  if abs(UY(j)-yp)<5 then
                    'if water then drawn
                    if ASC(MID$(lv$(UY(j)),UX(j)+1,1))=&hCC then UT(j)=5:UA(j)=&h8C
                  endif
                endif
              endif
            next
          end if
          em_on=1
        else
          em_on=0:UT(i)=0 'remove from list
        end if
        inc UB(i),1
      Case 74 'canister blow
        if UA(i)=247 then 'only once...
          do_damage(UX(i),UY(i),UC(i),UD(i)) 'do damage UD in radius < UC
          Play modsample s_dsbarexp,4
        end if
        Inc UA(i),1  'next tile in explosion sequence
        If UA(i)=253 Then UT(i)=0 'done exploding
    End Select
  Next
  
  For i=32 To 47  'door animations, raft, elevator
    dx=UX(i)-xp:dy=UY(i)-yp
    nearx=Abs(dx):neary=Abs(dy)
    Select Case UT(i)
      Case 7 'transporter
        UB(i)=UB(i)+1 and 3 'UB=delay counter
        if UB(i)=0 then
          if UA(i)=0 then 'transporter active
            UH(i)=&h1E+(UH(i)=&h1E) 'UH=tile toggle between &h1E and &h1F
            MID$(lv$(UY(i)),UX(i)+1,1)=Chr$(UH(i))  'active transporter
            if dx=0 and dy=0 then
              if UC(i)=0 then
                ky=27 'force game over by simulate pressing ESC
              else
                xp=UC(i):yp=UD(i) 'transport player
              end if
            end if
          else 'UA=1
            statistics(j,xy):if j=0 then UA(i)=0
          end if
        end if
      Case 10 'automatic doors
        If nearx<2 And neary<2 and UD(i)=0 Then   'operate door
          If UC(i)=0 Then
            open_door(i,UX(i),UY(i))
          ElseIf (UC(i) And pl_ky) Then
            open_door(i,UX(i),UY(i))
          Else
            If once<>UC(i) Then
              once=UC(i)
              writecomment("You need a "+keyz$(UC(i))+" key")
            EndIf
          EndIf
        Else 'we are far enough so close the door
          if UB(i)=2 then UD(i)=not(Asc(Mid$(lv$(UY(i)),UX(i)+1,1))=9)  'UD=1 if blocked
          if UD(i)=0 then close_door(i,UX(i),UY(i))
        EndIf
      case 16 'trash compactor
        if asc(mid$(lv$(UY(i)),UX(i)+1,1))=148 then 'no object, check for unit/robot
          j=has_unit(UX(i),UY(i))
          if j<255 then
            if UH(j)>0 then
              UB(i)=1:play modsample s_door,4 'start animation
              UH(j)=0:UT(j)=0 'kill item immediately, and remove from play
            end if
          end if
        else 'object in TC, crush it...
          if UB(i)=0 then UB(i)=1:play modsample s_door,4 'start animation
        end if
        if UB(i)>0 then crush(i,UX(i),UY(i))
      case 19 'elevator
        if dx=0 then
          if dy=0 or dy=-1 then
            open_elev(i,UX(i),UY(i))
          else
            close_elev(i,UX(i),UY(i))
          end if
          if dy=1 then
            if pl_md=p_w and UB(i)=5 then
              pl_md=p_ele1 'you are inside elevator door closed
              pl_el=UC(i)
              ele_instructions(i)
              writeplayer(0,1,pl_wp)
            end if
            if pl_md=p_ele2 then 'get out of the elevator
              open_elev(i,UX(i),UY(i))
              if UB(i)=2 then
                for j=0 to 3:writecomment(" "):next
                yp=yp+1:pl_md=p_w 'walk out
              end if
            end if
          end if
        else
          close_elev(i,UX(i),UY(i))
        end if
      case 22 'raft left-right
        'slow down
        IF UD(i)=0 then
          UD(i)=2
          'move raft
          MID$(lv$(UY(i)),UX(i)+1,1)=Chr$(&hCC) 'old becomes water
          if UA(i)=1 then 'move raft left
            inc UX(i),1:if UX(i)=UC(i) then UA(i)=0:UD(i)=16 'wait at dock
          else 'move right
            INC UX(i),-1:IF UX(i)=UB(i) then UA(i)=1:UD(i)=16
          end if
          MID$(lv$(UY(i)),UX(i)+1,1)=Chr$(&hF2) 'new is raft tile
          if dx=0 and dy=0 then xp=UX(i) 'if we where on the raft, stay on it
        end if
        inc UD(i),-1 'timer
    End Select
  Next
End Sub
  
sub dazzle_bot(i)
  UD(i)=(UD(i)+1) and 3 'walking speed
  if UD(i)=0 then
    local r=int(rnd()*5),xy
    inc UC(i),1 'time count 3,4...
    if UC(i)<32 then '30=15 seconds, counter starts at 2
      'new random location bot
      select case r
        case 0 'nothing
        case 1
          xy=UX(i)+1
          If (get_ta(xy,UY(i)) And b_wlk)>0 then
            if Not(dy=0 And xy=xp) Then inc UX(i),1
          endif
        case 2
          xy=UX(i)-1
          If (get_ta(xy,UY(i)) And b_wlk)>0 then
            if Not(dy=0 And xy=xp) Then inc UX(i),-1
          end if
        case 3
          xy=UY(i)+1
          If (get_ta(UX(i),xy) And b_wlk)>0 then
            if Not(xy=yp And dx=0) Then inc UY(i),1
          end if
        case 4
          xy=UY(i)-1
          If (get_ta(UX(i),xy) And b_wlk)>0 then
            if Not(xy=yp And dx=0) Then inc UY(i),-1
          end if
      end select
    else 'end of dazzle
      UC(i)=0 'notmal walking direction
    end if
  end if
end sub
  
  
Sub bot_shoot_h(i,dx)
  'UB()=counter, only shoot 1x per second
  Local t,j,x,p=1-2*(dx<0)  'if dx<0 then p=-1 if dx>0 then p=+1
  
  If Abs(dx)<=xm then
    'a shot is possible
    j=findslot() 'fire line
    If j<32 Then
      UX(j)=UX(i):UY(j)=UY(i):UA(j)=245:UT(j)=14+(dx<0)
      
      'for now calculate fireline from bot to player
      x=xp+dx 'location bot
      Do
        Inc x,-p:t=get_ta(x,yp):UX(j)=x    'next tile e/w
        
        If (t And (b_wlk+b_hov)) Then      'pass fire, next tile
          
        ElseIf Asc(Mid$(lv$(yp),x+1,1))=&h83 Then 'canister
          blow_canister(x,yp)
          Inc x,p:Exit
          
        ElseIf (t And (b_see))=0 Then      'stopped by wall or plant
          small_explosion(j)
          Inc x,p:Exit
          
        EndIf
        
      Loop Until x=xp
      
      Play Modsample s_dspistol,4
      UD(j)=dx-p:UC(j)=x-xp+p:UX(j)=xp:UY(j)=yp 'align vector to player
      UB(i)=4 'cause delay of 4x120ms
      
    EndIf
    If x=xp Then 'player hit
      j=findslot()
      If j<32 Then
        UX(j)=xp:UY(j)=yp:UA(j)=247:UT(j)=11
        UH(0)=Max(UH(0)-1,0)  'loose life
      EndIf
    EndIf
  EndIf
End Sub
  
Sub bot_shoot_v(i,dy)
  'UB()=counter, only shoot 1x per second
  Local t,j,y,p=1-2*(dy<0)  'if dy<0 then p=-1 if dy>0 then p=+1
  
  If Abs(dy)<=ym then
    'a shot is possible
    j=findslot() 'fire line
    If j<32 Then
      UX(j)=UX(i):UY(j)=UY(i):UA(j)=244:UT(j)=12+(dy<0)
      
      'for now calculate fireline from bot to player
      y=yp+dy 'location bot
      Do
        Inc y,-p:t=get_ta(xp,y):UY(j)=y    'next tile n/s
        
        If (t And (b_wlk+b_hov)) Then      'pass fire, next tile
          
        ElseIf Asc(Mid$(lv$(y),xp+1,1))=&h83 Then 'canister
          blow_canister(xp,y)
          Inc y,p:Exit
          
        ElseIf (t And (b_see))=0 Then       'stopped by wall or plant
          small_explosion(j)
          Inc y,p:Exit
          
        EndIf
        
      Loop Until y=yp
      
      Play Modsample s_dspistol,4
      UD(j)=dy-p:UC(j)=y-yp+p:UX(j)=xp:UY(j)=yp 'align to player pos
      UB(i)=4 'cause delay of 4x120ms
      
    EndIf
    If y=yp Then 'player hit
      j=findslot()
      If j<32 Then
        UX(j)=xp:UY(j)=yp:UA(j)=247:UT(j)=11
        UH(0)=Max(UH(0)-1,0)  'loose life
      EndIf
    EndIf
  EndIf
End Sub
  
  
Sub do_damage(x,y,r,d)
  Local i,j,a,rr
  
  For i=0 To 27 'all units
    If Abs(UX(i)-x)<r then
      if Abs(UY(i)-y)<r Then UH(i)=Max(UH(i)-d,0)
    endif
  Next
  
  For i=48 To 63  'hidden content
    If Abs(UX(i)-x)<r then
    if Abs(UY(i)-y)<r Then UT(i)=0 'remove hidden item
    endif
  Next
  
  rr=r-1 'tiles only inside radius
  For i=-rr To rr
    For j=-rr To rr
      a=Asc(Mid$(lv$(y+j),x+i+1,1))
      Select Case a
        Case &h83
          MID$(lv$(y+j),x+i+1,1)=Chr$(&h87) 'canister
          If i<>0 Or j<>0 Then blow_canister(x+i,y+j) 'not yourself
          'blow_canister(x+i,y+j)
        Case &h29
          MID$(lv$(y+j),x+i+1,1)=Chr$(&h2A) 'carton box
        Case &hC7
          MID$(lv$(y+j),i+x+1,1)=Chr$(&hC6) 'wooden box
        Case &h2D
          MID$(lv$(y+j),i+x+1,1)=Chr$(&h2E) 'small box
        Case &hCD
          MID$(lv$(y+j),i+x+1,1)=Chr$(&hCC) 'bridge
        case &h18
          MID$(lv$(y+j),i+x+1,1)=Chr$(9) 'plant
      End Select
    Next
  Next
End Sub
  
Sub place_bomb
  'UA()=sprite,UB()=delay in loops (around 3 seconds),UC()=radius,UD()=damage
  Local i=findslot()
  If i<32 Then
    UT(i)=71:UX(i)=xp+h:UY(i)=yp+v:UA(i)=&h57:UB(i)=24:UC(i)=3:UD(i)=11
    Inc pl_bo,-1:show_item
    writecomment("you placed a bomb")
  EndIf
End Sub
  
Sub blow_canister(x,y)
  'UA()=tile,UC()=radius,UD()=damage
  Local i=findslot()
  If i<32 Then
    UT(i)=74:UX(i)=x:UY(i)=y:UA(i)=247:UC(i)=2:UD(i)=11
    '    writecomment("you blew a canister")
  EndIf
End Sub
  
  
Sub place_magnet
  'UA()=sprite,UB()=duration in loops (around 15 seconds)
  Local i=findslot()
  If i<32 Then
    UT(i)=72:UX(i)=xp+h:UY(i)=yp+v:UA(i)=&h58:UB(i)=120
    Inc pl_ma,-1:show_item
    writecomment("you placed a magnet")
  EndIf
End Sub
  
  'animates the trash compactor
sub crush(i,x,y)
  static c
  c=1-c 'slow down
  if c then
    if UB(i)=4 then anim_tc(x,y,&h90,&h91,&h94,&h94):UB(i)=0
    if UB(i)=3 then anim_tc(x,y,&h92,&h93,&h96,&h97):UB(i)=4
    if UB(i)=2 then anim_tc(x,y,&h98,&h99,&h9C,&h9D):UB(i)=3
    if UB(i)=1 then anim_tc(x,y,&h92,&h93,&h96,&h97):UB(i)=2
  end if
end sub
  
  'replaces 4 tiles of the trash compactor
sub anim_tc(x,y,a,b,c,d)
  MID$(lv$(y-1),x+1,1)=Chr$(a)
  MID$(lv$(y-1),x+2,1)=Chr$(b)
  MID$(lv$(y),x+1,1)=Chr$(c)
  MID$(lv$(y),x+2,1)=Chr$(d)
End Sub
  
end sub
  
Sub open_elev(i,dx,dy)
  Local u_b=UB(i)
  If u_b=5 Then Play modsample s_door,4
  If u_b=1 Then anim_h_door(dx,dy,182,9,&hAC):UB(i)=2
  If u_b=0 Then anim_h_door(dx,dy,181,89,&hAD):UB(i)=1
  If u_b=5 Then anim_h_door(dx,dy,84,85,&hAE):UB(i)=0
End Sub
  
Sub close_elev(i,dx,dy)
  Local u_b=UB(i)
  If u_b=2 Then Play modsample s_door,4
  If u_b=4 Then anim_h_door(dx,dy,80,81,&hAE):UB(i)=5
  If u_b=3 Then anim_h_door(dx,dy,84,85,&hAD):UB(i)=4
  If u_b=2 Then anim_h_door(dx,dy,181,89,&hAC):UB(i)=3
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
  '  if Asc(Mid$(lv$(dy),dx+1,1))<>9 then UB(i)=5 'skip close when blocked
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
Function findslot()
  Local i=28
  Do
    If UT(i)=0 Then
      Exit
    Else
      Inc i,1
    EndIf
  Loop Until i=32
  findslot=i
End Function
  
  'create a small explosion at location
Sub small_explosion(i)
  Local j
  j=findslot()
  If j<32 Then
    UT(j)=11:UX(j)=UX(i):UY(j)=UY(i):UA(j)=247  'explosion
    Play modsample s_dsbarexp,4
  EndIf
End Sub
  
sub zap(i)
  Local j
  j=findslot()
  If j<32 Then
    UT(j)=11:UX(j)=UX(i):UY(j)=UY(i):UA(j)=250  'short zap...
    Play modsample s_shock,4
  EndIf
end sub
  
sub explosion(i)
  if pl_wp=2 then 'plasma explosion 11 dmg radius 2
    Local j=findslot()
    If j<32 Then UT(j)=74:UX(j)=UX(i):UY(j)=UY(i):UA(j)=247:UB(j)=24:UC(j)=3:UD(j)=11
  else
    small_explosion(i) 'pistol explosion
  end if
end sub
  
  
  'weapon fire in horizontal direction
Sub fire_ew(p)
  'UD() is the start of the fire line
  'UC() is length of the fire line
  'UB() is the UNIT hit
  'UA() is the fire line sprite
  If pl_pa(pl_wp)>0 Then
    
    Local x=0,i,j,b=0,d=0,t
    
    i=findslot()      'find a weapon slot in UNIT array
    If i<32 Then
      
      UT(i)=127:UX(i)=xp:UY(i)=yp 'default claim array slot
      Do
        Inc x,p:t=get_ta(xp+x,yp):UX(i)=xp+x 'next tile n/s
        
        j=has_unit(UX(i),UY(i))
        If j<255 Then' if robot then damage it
          explosion(i)
          if pl_wp=1 then Inc UH(j),-1
          if UT(j)<4 then UT(j)=4 'hoverbot become aggressive
          Inc x,-p:Exit
          
        ElseIf (t And (b_wlk+b_hov)) Then   'pass fire, next tile
          
        ElseIf Asc(Mid$(lv$(yp),xp+x+1,1))=&h83 Then 'canister
          blow_canister(xp+x,yp)
          Inc x,-p:Exit
          
        ElseIf (t And (b_see))=0 Then  'stopped by wall or plant
          explosion(i)
          Inc x,-p:Exit
          
        EndIf
        
      Loop Until Abs(x)=xm
      
      'register for screen
      If Abs(x)>=1 Then
        UT(i)=14+(x>0):UC(i)=x:UA(i)=249-4*pl_wp
        UB(i)=b:UD(i)=p
      Else
        UT(i)=0 'free slot
      EndIf
    EndIf
    
    'play sound
    If pl_wp=2 Then Play modsample s_plasma,4 Else Play Modsample s_dspistol,4
    
    'reduce ammo
    Inc pl_pa(pl_wp),-1
    show_weapon
    
  EndIf
End Sub
  
  'weapon fire in vertical direction
Sub fire_ns(p)
  'UD() is the start of the fire line
  'UC() is length of the fire line
  'UB() is the UNIT (robot) hit
  'UA() is the sprite
  If pl_pa(pl_wp)>0 Then
    
    Local y=0,i,j,b=0,d=0,t
    
    i=findslot()      'find a weapon slot in UNIT array
    If i<32 Then
      
      UT(i)=127:UX(i)=xp:UY(i)=yp   'default claim array slot
      Do
        
        Inc y,p:t=get_ta(xp,yp+y):UY(i)=yp+y 'next tile n/s
        
        j=has_unit(UX(i),UY(i))
        If j<255 Then 'if robot then damage it
          explosion(i)
          if pl_wp=1 then Inc UH(j),-1
          if UT(j)<4 then UT(j)=4 'hoverbot become aggressive
          Inc x,-p:Exit
          
        ElseIf (t And (b_wlk+b_hov)) Then   'pass fire, next tile
          
        ElseIf Asc(Mid$(lv$(yp+y),xp+1,1))=&h83 Then 'canister
          blow_canister(xp,yp+y)
          Inc y,-p:Exit
          
        ElseIf (t And (b_see))=0 Then  'stopped by wall or plant
          explosion(i)
          Inc y,-p:Exit
          
        EndIf
        
      Loop Until Abs(y)=ym
      
      'register for screen
      If Abs(y)>=1 Then
        UT(i)=12+(y>0):UC(i)=y:UA(i)=248-4*pl_wp
        UB(i)=b:UD(i)=p
      Else
        UT(i)=0 'free slot
      EndIf
      
    EndIf
    
    'play sound
    If pl_wp=2 Then Play modsample s_plasma,4 Else Play Modsample s_dspistol,4
    
    'reduce ammo
    Inc pl_pa(pl_wp),-1
    show_weapon
    
  EndIf
End Sub
  
  'is there a robot on this location in the map
Function has_unit(x,y)
  Local i=0
  has_unit=255
  Do
    If UT(i)>0 Then
      If UX(i)=x Then
        If UY(i)=y Then has_unit=i
      end if
    end if
    Inc i,1
  Loop Until i=28
End Function
  
  
  'find the items in viewer area in the unit attributes
Sub exec_viewer
  'do thingsEnd Function
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
  If (get_ta(tx,ty) And b_pus) Then 'you can push towards this position
    if has_unit(tx,ty)=255 then 'no unit here
      'execute the move on the world map (swap tiles)
      tl$ = Mid$(lv$(ty),tx+1,1)
      MID$(lv$(ty),tx+1,1)=Mid$(lv$(oy),ox+1,1)
      If Asc(tl$)=148 Then tl$=Chr$(9)  'if trash compactor then floor
      MID$(lv$(oy),ox+1,1)=tl$
      'play sound
      Play modsample s_move,4
    end if
  Else
    writecomment("Object cannot move here")
    Play modsample s_error,4
  EndIf
  pl_md=p_w                       'at the end, free player
End Sub
  
  'generic subs for gameplay -------------------------------------------
  'write unit position back in unit attributes (also player)
Sub store_unit_pos(unit,x,y)
  UX(unit)=x:UY(unit)=y
End Sub
  
Sub show_ta(x,y)
  Text 0,0,Right$("0000000"+Bin$(get_ta(x,y)),8)
End Sub
  
  'calculate achievements
Sub statistics(b,h)
  Local ii,jj=0
  For ii=1 To 27   'check bots
    If UT(ii)>0 Then Inc jj,1
  Next
  b=jj:jj=0
  For ii=48 To 63  'check secrets
    If UT(ii)>127 Then Inc jj,1
  Next
  h=jj
End Sub
  
  'get tile attribute for this tile
Function get_ta(x,y)
  spn=Peek(byte lva+y*129+x+1)+1
  get_ta=Peek(byte taa+spn)
End Function
  
  'write text in the comment area at bottom screen rolling upwards
Sub writecomment(a$)
  Local i
  For i=0 To 2:comment$(i)=comment$(i+1):Next
  comment$(3)=Left$(a$+Space$(30),30)
  For i = 0 To 3
    Text 10,200+10*i,comment$(i),,,,textc,bckgnd
  Next
End Sub
  
  'elevator instructions on layer N
sub ele_instructions(i)
  le$=left$("|     123456",6+UD(i))+right$("             | DOOR",17-UD(i))
  writecomment(" ")
  writecomment("| ELEVATOR PANEL | DOWN")
  writecomment("|  SELECT LEVEL  | OPENS")
  writecomment(le$)
end sub
  
  'highlight actual floor layer L
sub ele_level(i)
  text 50+8*i,230,str$(i),,,,rgb(white),rgb(magenta)
end sub
  
sub next_floor(h)
  local i
  for i=32 to 47 'range where elevators live
    if UT(i)=19 and UC(i)=pl_el+h then
      xp=UX(i):yp=UY(i)-1:pl_el=pl_el+h 'go inside this elevator
      UX(0)=xp:UY(0)=yp
      exit for 'found new floor
    endif
  next
end sub
  
  'scale the world map to overview mode @Martin
Sub renderLiveMap
  Local integer mx,my,mp,yy,CL(256)
  Local t$
  box 0,24,11*24,7*24,1,0,0 'clear screen
  'Tile colors
  T$="00077777977770777770000A0000B0006740694B66EB60E777E722B724B66070"
  T$=T$+"0367000700770007770000700707077880000007776777077707770778888887"
  T$=T$+"7067700770000007700400000000000000000730073000000000000CCC0C0C0C"
  T$=T$+"CC07700770898EEAAA2338677727776777EAAEEAAEE00000000000000000000"
  For mx=1 To 255:CL(mx)=col(Val("&H"+Mid$(T$,mx,1))):Next
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
  s_plasma=29:s_shock=30
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
    tile_index(204)=tla_index(20+a2) 'WATER 204
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
    Case 2 'emp
      if pl_em>0 then
        a=findslot()
        if a<32 then
          UT(a)=73:UX(a)=xp:UY(a)=yp:UB(a)=0  'start emp
          pl_em=max(pl_em-1,0)                'lower inventory
          writecomment("you placed an EMP")
          writecomment("ROBOTS near you will reboot")
          play modsample s_emp,4  'emp sound
        end if
      end if
    Case 3 'magnet
      pl_md=p_mg1
      'writecomment("3")
    Case 4 'bomb
      pl_md=p_bo1
      'writecomment("4")
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
  lva=Peek(varaddr LV$())
  taa=Peek(varaddr TA$)
  
  'load world map and attributes
  pause 100: Open "data\level-"+Chr$(97+Map_Nr) For input As #1
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
  For i=0 To 63:LV$(i)=Input$(128,#1):Next
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
  '0=unlocked, 1=spades, 2=heart, 3=star, 4=elev
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
  Dim col(15):Restore colors:For f=1 To 15:Read col(f):Next
  Dim map_nam$(13) length 16 :Restore map_names:For f=0 To 13:Read map_nam$(f):Next
End Sub
  
  
  'load tile and sprite indexes for locations in the library
Sub loadgraphics
  local fl_adr=mm.info(flash address 3) 'load flash start adress
  
  'copy the sprites into a picomite flash slot #4
  'flash slot #4 has the exact same start address as the old library
  'so the same index applies
  flash disk load 3,"lib/pet_lib23.bin",o
  
  'load global index file
  Dim sprite_index(&h60)
  Dim health_index(5)
  Dim tile_index(&hff)
  Dim item_index(5)
  Dim tla_index(&h17)
  Dim key_index(2)
  
  Open "lib/flash_index.txt" For input As #1
  
  For i=0 To &hff
    Input #1,a$:tile_index(i)=Val(a$)+fl_adr
  Next
  
  For i=0 To &h17
    Input #1,a$:tla_index(i)=Val(a$)+fl_adr
  Next
  
  For i=0 To 2
    Input #1,a$:key_index(i)=Val(a$)+fl_adr
  Next
  
  For i=0 To 5
    Input #1,a$:item_index(i)=Val(a$)+fl_adr
  Next
  
  For i=0 To 5
    Input #1,a$:health_index(i)=Val(a$)+fl_adr
  Next
  
  For i=0 To &h5f
    Input #1,a$:sprite_index(i)=Val(a$)+fl_adr
  Next
  Close #1
  
End Sub
  
  
  'startup Menu-------------------------------------@Martin
Sub show_intro
  'load screen
  FRAMEBUFFER write l:CLS :FRAMEBUFFER write sc$
  Load image "images/introscreen.bmp",0,10
  ' get space for the 4th Menu entry
  Sprite 28,18,28,10,88,24:Box 32,21,80,34,,0,0
  
  FRAMEBUFFER write l: fade_in: :FRAMEBUFFER write sc$
  Local integer puls(11)=(0,1,9,11,3,6,7,6,5,11,9,1),t
  Local Message$(4) length 40
  
  'set Map to 0, Menu State to 1
  Message$(1)="...use UP & DOWN, Space or 'Start'      "
  Message$(2)="   ...use LEFT & RIGHT to select Map    "
  Message$(3)="  ...use LEFT & RIGHT cange Difficulty  "
  dim DIFF_LEVEL_WORD$(2) length 6 =("EASY  ","NORMAL","HARD  ")
  Map_Nr=0:MS=1:Difficulty=1
  
  ' start playing the intro Music
  Play Modfile "music\metal_heads.mod"
  show_menu 1
  
  'Display Map Name
  Text 9,70,UCase$(map_nam$(Map_Nr))
  'sl=1 'set menu slot to top
  '--- copyright notices etc
  Text 0,224,Message$(1),,,,col(3)
  MSG$=String$(36,32)
  MSG$=MSG$+"original Game by David Murray - "
  MSG$=MSG$+"Port to Mite and MM-Basic by Volhout, Martin H and thebackshed-"
  MSG$=MSG$+"Community - Music by Noelle Aman, Graphic by "
  MSG$=MSG$+"Piotr Radecki - MMBasic by Geoff Graham and Peter Mather "
  flip=0
  MT=0
  
  'check player choice
  kill_kb
  Do
    If flip=0 Then Inc MT:If mt>Len(MSG$) Then MT=0
    tp$=Mid$(MSG$,1+MT,41)
    'If flip Then Inc MT:If mt>Len(MSG$) Then MT=0
    k$=Inkey$:If k$="" Then k$=c2k$()
    If k$<>"" Then
      If k$=Chr$(129) Then Inc MS,(MS<4)
      If k$=Chr$(128) Then Inc MS,-(MS>1)
      If k$=" " Then
        Select Case MS
          Case 1
            FRAMEBUFFER write L:fade_out:FRAMEBUFFER write sc$
            Exit 'intro and go on with the Program
          Case 2
            'select map
            kill_kb
            Text 0,224,message$(2),,,,col(3)
            Do
              k$=Inkey$:If k$="" Then k$=c2k$()
              If  k$<>""  Then
                If k$=Chr$(130) Then Inc Map_Nr,-(Map_Nr>0)
                If k$=Chr$(131) Then Inc Map_Nr,(Map_Nr<13)
                If k$=" "  Then
                  Text 0,224,message$(1),,,,col(3): Exit
                EndIf
                Text 9,70,UCase$(map_nam$(Map_Nr))
                If Game_Mite Then FRAMEBUFFER merge 9,b
              EndIf
              Pause 200
            Loop
            kill_kb
          Case 3
            'select DIFFICULTY
            kill_kb
            Text 0,224,message$(3),,,,col(3)
            Do
              k$=Inkey$:If k$="" Then k$=c2k$()
              If  k$<>"" Then
                If k$=" " Then
                  Text 0,224,message$(1),,,,col(3)
                  Text 0,232,"      "
                  
                  Exit
                EndIf
                If k$=Chr$(130) Then
                  Inc Diff_Level,-(Diff_Level>0)
                EndIf
                If k$=Chr$(131) Then
                  Inc Diff_Level,(Diff_Level<2)
                EndIf
                Text 0,232,DIFF_LEVEL_WORD$(Diff_Level)
                Load image "images\face_"+Str$(Diff_Level)+".bmp",234,85
                save image "images\strip.bmp",0,85,320,16
                If Game_Mite Then FRAMEBUFFER Merge 9,b
              EndIf
              Pause 200
            Loop
            kill_kb
          Case 4
            'select CONTROLS
        End Select
      EndIf
    EndIf
    
    show_menu MS,col(puls(t))
    
    Text 8-(2*flip),0,tp$,,,,col(2):flip=(flip+1) and 3
    'Text 0-(4*Flip),0,tp$,,,,col(2):Flip=Not(FLIP)
    Inc t: t=t Mod 12
    If Game_Mite Then FRAMEBUFFER Merge 9,b
    Pause 50: 'Contr_input$() is to fast to see what position you are in
  Loop
  Play stop
End Sub
  
  
  'remove duplicate keys and key repeat
Sub kill_kb
  Local k$
  Do
    k$=Inkey$:If k$="" Then k$=c2k$()
  Loop Until k$=""
End Sub
  
  
  'start menu selection list
Sub show_menu(n1,FC)
  Local tc,BG=0,f2=col(10)
  tc=f2 :If n1=1 Then tc=FC
  Text 32,22,"START GAME",,,,tc
  tc=f2 : :If n1=2 Then tc=FC
  Text 32,30,"SELECT MAP",,,,tc
  tc=f2 : :If n1=3 Then tc=FC
  Text 32,38,"DIFFICULTY",,,,tc
  tc=f2 : :If n1=4 Then tc=FC
  Text 32,46,"CONTROLS  ",,,,tc
End Sub
  
  
Sub fade_in
  Local n,x,y
  For n=0 To 7
    For x=n To 320 Step 8:Line x,0,x,240,,col(5):Next
    For y=n To 240 Step 8:Line 0,y,320,y,,col(5):Next
    If Game_Mite Then FRAMEBUFFER merge 9,b
    Pause 50+130*Game_Mite
  Next
End Sub
  
  
Sub fade_out
  Local n,x,y
  For n=0 To 7
    For x=n To 320 Step 8:Line x,0,x,240,,0:Next
    For y=n To 240 Step 8:Line 0,y,320,y,,0:Next
    If Game_Mite Then FRAMEBUFFER merge 9,b
    Pause 50+130*Game_Mite
  Next
End Sub
  
  
  
  '---joystick/Gamepad specific settings
  
  'settings for NES on PicoGameVGA platform port A
sub config_nes
  DIM a_dat=2   'GP1
  DIM a_latch=4 'GP2
  DIM a_clk=5   'GP3
  DIM pulse_len!=0.012 '12uS
  SetPin a_dat, din
  SetPin a_latch, dout
  SetPin a_clk, dout
  setpin gp14,dout:pin(gp14)=1 'power for the NES controller
end sub
  
  'Settings for Game*Mite
Sub init_game_ctrl
  Local i%
  ' Initialise GP8-GP15 as digital inputs with PullUp resistors
  For i% = 8 To 15
    SetPin MM.Info(PinNo "GP" + Str$(i%)), Din, PullUp
  Next
End Sub
  
  'this is for the parallel key layout of the game_mite
Function contr_input$()
  If Not Game_Mite Then Contr_input$="":Exit Function
  Local  n,ix% = Port(GP8, 8) Xor &h7FFF,cs$="",bit
  Local m$(7)=("DOWN","LEFT","UP","RIGHT","SELECT","START","BUT-B","BUT-A")
  ' which buttons are currently pressed
  For n=0 To 7
    bit=2^n:If ix% And bit Then Inc cs$,m$(n)+" "
  Next
  Contr_input$=cs$
End Function
  
  'This is for serial 74HC4021 in a NES controller on PicoGameVGA
Function nes_input$()
  Local m$(7)=("BUT-A","BUT-B","SELECT","START","UP","DOWN","LEFT","RIGHT"),bit
  Pulse a_latch, pulse_len!
  out=0:cs$=""
  For i=0 To 7
    If Not Pin(a_dat) Then out=out Or 2^i
    Pulse a_clk, pulse_len!
  Next
  For n=0 To 7
    bit=2^n:If out And bit Then Inc cs$,m$(n)+" "
  Next
  nes_input$=cs$
End Function
  
  'Controller to Keyboard translation
Function c2k$()
  Local c$,tmp$
  If nesPG1 Then
    c$=nes_input$()
  Else
    c$=contr_input$()
  EndIf
  If c$<>"" Then
    Select Case c$
        Case "DOWN "       : c2k$=Chr$(129)'down
        Case "UP "         : c2k$=Chr$(128)'up
        Case "LEFT "       : c2k$=Chr$(130)'left
        Case "RIGHT "      : c2k$=Chr$(131)'right
        Case "BUT-A "      : c2k$="m"      'A
        Case "BUT-B "      : c2k$="z"      'B
        Case "START "      : c2k$=" "      'Start
        Case "BUT-B BUT-A ","BUT-A BUT-B ": c2k$=Chr$(9)  'Tab
        Case "DOWN BUT-A " ,"BUT-A DOWN " : c2k$="s"      'Fire Down
        Case "UP BUT-A "   ,"BUT-A UP "   : c2k$="w"      'Fire Up
        Case "LEFT BUT-A " ,"BUT-A LEFT " : c2k$="a"      'Fire Left
        Case "RIGHT BUT-A ","BUT-A RIGHT ": c2k$="d"      'Fire Right
        Case "UP BUT-B "   ,"BUT-B UP "   : c2k$=Chr$(145)'F1
        Case "DOWN BUT-B " ,"BUT-B DOWN " : c2k$=Chr$(146)'F2
        Case "SELECT "     : c2k$=Chr$(27) 'ESC
    End Select
  EndIf
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
