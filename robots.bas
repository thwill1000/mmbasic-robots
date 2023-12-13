  'PETSCII ROBOTS for PicoMiteVGA needs MMBasic V50800b4 or later
  
  Option default Integer
  
  ' system setup -----------------------------------------------------
  
  Const NES_A_DATA = Mm.Info(PinNo GP1)
  Const NES_A_LATCH = Mm.Info(PinNo GP2)
  Const NES_A_CLOCK = Mm.Info(PinNo GP3)
  Const NES_PULSE! = 0.012 ' 12uS
  
  Const LCD_DISPLAY = Mm.Device$ = "PicoMite"
  Const SC$ = Choice(LCD_DISPLAY, "f", "n")
  
  Dim CTRL_DRIVER$ = Choice(LCD_DISPLAY, "ctrl_gamemite$", "ctrl_none$")
  ' Uncomment one of these to override controller:
  ' CTRL_DRIVER$ = "ctrl_atari_a$"      ' Atari Joystick on PicoGAME port A
  ' CTRL_DRIVER$ = "ctrl_nes_a$"        ' NES gamepad on PicoGAME port A
  ' CTRL_DRIVER$ = "ctrl_wii_classic$"  ' Wii Classic controller
  If Call(CTRL_DRIVER$, 1) <> "" Then Error
  
  'screen setup
  If LCD_DISPLAY Then FRAMEBUFFER Create Else Mode 2
  FRAMEBUFFER layer 9 'color 9 is transparant
  Font 9
  
  
  
  'game configuration screen show on N ------------------------
  init_map_support
  preload_sfx
  show_intro
  
  
  'start of the actual game -----------------------------------
  loading 'show message on L
  
  
  'get world map
  loadworld
  statistics(start_bots,start_hidden) 'to calculate end screen
  loadgraphics
  
  
  'adapt hoverbots for difficulty level
  if Diff_level=2 then
      for i=1 to 27: if UT(i)=2 or UT(i)=3 then UT(i)=4
    next 'aggro all hoverbots
  end if
  
  
  'startup defines --------------------------------------------
  
  'heartbeat
  Dim h_beat=100 'ms
  
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
  
  'write frame around playfield
  FRAMEBUFFER Write sc$
  Load image path$("images/layer_b.bmp")  'the actual frame
  If LCD_DISPLAY Then FrameBuffer Merge 9
  
  'start music/sfx modfile
  music=1
  select_music(map_nr mod 3)
  
  'write initial world
  map_mode=0              'overview world map off
  ani_timer=1             'world animations
  writeworld_n(xm,ym)     'initialwold
  writecomment("Welcome to PETSCII Robots")
  writecomment("Find and kill "+str$(start_bots)+" robots")
  framebuffer write L:fade_in:framebuffer write sc$
  
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
      tmp$=read_input$()
      If tmp$<>"" Then k$=tmp$  'keep last valid key
    Loop Until Timer>h_beat
    Inc playtime, Timer : Timer=0
    
    
    If pl_md<p_death Then 'we are live, so let's play the game....
      
      'player controls movement of player character
      v=(k$ = "down") - (k$ = "up")
      h=(k$ = "right") - (k$ = "left")
      If h+v<>0 And map_mode<2 Then               'any cursor key pressed
        
        Select Case pl_md
          Case p_w
            If (get_ta(xp+h,yp+v) And b_wlk) Then 'check if we can walk, then walk
              if has_unit(xp+h,yp+v)=255 then
                inc xp,h:inc yp,v             'new player position
                xp=Min(Max(xp,5),hsize-6)     'don't fall off the map
                yp=Min(Max(yp,3),vsize-4)
                UX(unit)=x:UY(unit)=y         'store pos for future use
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
      
      
      Select Case k$
        Case "search" ' Initiate search mode
          pl_md=p_s1
        Case "move" ' Initiate move mode
          pl_md=p_m1
        Case "toggle-weapon"
          pl_wp=(pl_wp+1) Mod 3
          show_weapon
          writeplayer(hp,vp,pl_wp)
          Play modsample s_cycle_weapon,4
        Case "toggle-item"
          pl_it=(pl_it+1) Mod 5
          show_item
          Play modsample s_cycle_item,4
        Case "cheat" 'F3 cheat key as long as you are alive
          if UH(0)>0 then
            UH(0)=12                      'full life
            pl_ky=7:show_keys             'all keys
            pl_pa(1)=100:pl_pa(2)=100     'much ammo
            pl_bo=100:pl_em=100:pl_ma=100 'all items
            pl_mk=100                     'full medkit
          end if
        Case "kill-all" 'F4 cheat key kills all bots
          for i=1 to 27:UT(i)=0:next
        Case "map" 'TAB key show map + toggle player/robots
          Select Case map_mode
            Case 0
              map_mode=1      'stop showing normal mode
              FRAMEBUFFER write l:CLS col(5):FRAMEBUFFER write sc$ 'clear layer
              renderLiveMap   'show map mode
            Case 1
              map_mode=Choice(diff_level<2,2,0)
            Case 2
              map_mode=Choice(diff_level<1,3,0)
            Case 3
              map_mode=0
              FRAMEBUFFER write l:CLS  col(5):FRAMEBUFFER write sc$ 'clear layer
              writeplayer(hp,vp,pl_wp)
          End Select
      End Select
      
      'fire weapon
      If shot=1 Then shot=0
      Select Case k$
        Case "fire-up"
          shot=1:fire_ns(-1):writeplayer(0,-1,pl_wp)
        Case "fire-left"
          shot=1:fire_ew(-1):writeplayer(-1,0,pl_wp)
        Case "fire-down"
          shot=1:fire_ns(1):writeplayer(0,1,pl_wp)
        Case "fire-right"
          shot=1:fire_ew(1):writeplayer(1,0,pl_wp)
        Case "use-item"
          use_item()
        Case "toggle-music"
          k$="" ' Do we need this ?
          Play stop:music=1-music
          If music Then
            select_music(3) 'only sfx
          Else
            select_music(map_nr mod 3) 'any of 3 songs
          EndIf
      End Select
      
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
        If Not LCD_DISPLAY Then FrameBuffer Wait
        writesprites_l
        
      Else
        
        anim_map
        
      EndIf
      
    EndIf 'pl_md<p_death
    
    If k$ = "escape" And pl_md<p_death Then
      writecomment("PAUSE, press <ESC> to quit")
      kill_kb
      do
        pause 100:k$=read_input$()
      loop while k$=""
      If k$ <> "escape" Then k$="":writecomment("continue") 'any value that does not quit
    end if
    
    If LCD_DISPLAY Then FrameBuffer Merge 9,b
    
  Loop Until k$ = "escape"   'quit when <esc> is pressed
  
  game_end
  play stop:run
  
End
  
  
  
  ' screen oriented subs ------------------------------------------
  
  'uses tiles stored in library to build up playfield in layer N
Sub writeworld_n(xm,ym)
  local xsn,xpn,spn
  For xn=-xm To xm
    xsn=xs+xn*24:xpn=xp+xn+1+lva
    For yn=-ym To ym
      'load tile from world map
      spn=Peek(byte(yp+yn)*129+xpn)
      Blit memory tile_index(spn),xsn,ys+yn*24
    Next
  Next
End Sub
  
  
  'write UNITS's to screen on layer L, no AI, only graphics
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
              if UA(i)>&h4B then UA(i)=min(UA(i)+1,&h52)
            Else
              If UA(i)=&h52 Then
                game_over              'show end text
              Else
                Sprite memory sprite_index(UA(i)),xs,ys,9
                h_beat=min(h_beat+40,400):Inc UA(i) 'slow down all, next sprite
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
          Case 74 'canister or plasma
            show_explosion(UA(i),dx,dy,UC(i)) 'explosions in radius < UC
        end select
      end if
    end if
  next
  
  For i=32 To 47
    if UT(i)=19 then
      if UX(i)=UX(0) And UY(i)=UY(0)+1 then 'elevator
        ele_level(pl_el)
      end if
    end if
  next
  FRAMEBUFFER write sc$
End Sub
  
  
  'this adds a special UNIT sprite at absolute screen coordinates in UNIT array
  'this allows to put sprites off-grid
Sub sprite_item(sprt,xabs,yabs)
  'UT=decimal 70, UB=x and UC=y are absolute, UA=sprite number
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
  framebuffer write sc$
  writecomment(""):writecomment(""):writecomment("")
  writecomment("Game over, press <ESC>")
  framebuffer write l
End Sub
  
  
  'loading popup in L
Sub loading
  framebuffer write L
  Box 120,108,72,24,1,col(7),0
  Text 128,116,"LOADING",,,,col(7),0
  framebuffer write sc$
  cls
End Sub
  
  
  'game end screen and statitics
Sub game_end
  FRAMEBUFFER write l:fade_out:FRAMEBUFFER write sc$
  Load image path$("images/end.bmp")
  FRAMEBUFFER write l:fade_in:FRAMEBUFFER write sc$
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
  Play modfile path$("music/" + Choice(left_bots, "lose.mod", "win.mod"))
  pause 6000 'sufficient to have 1 win/loose sound
  play stop:kill_kb
  do
  loop while read_input$()=""
  FRAMEBUFFER write l:fade_out:FRAMEBUFFER write sc$
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
  
  
  ' animations ----------------------------------------------------------
  
  'animate compact world map with player, robots, or hidden items
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
  Inc p
  
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
    kill_kb
  Else
    writecomment("Object cannot be moved")
    Play modsample s_error,4
    pl_md=p_w  'get out of move mode
  EndIf
End Sub
  
  
Sub place_bomb
  'UA()=sprite,UB()=delay in loops (3 sec),UC()=radius,UD()=damage
  Local i=findslot()
  If i<32 Then
    UT(i)=71:UX(i)=xp+h:UY(i)=yp+v:UA(i)=&h57:UB(i)=30:UC(i)=3:UH(i)=11
    Inc pl_bo,-1:show_item
    writecomment("you placed a bomb")
  EndIf
End Sub
  
  
Sub blow_canister(x,y)
  'UA()=tile,UC()=radius,UH()=damage,UD()=direction
  Local i=findslot()
  If i<32 Then
    UT(i)=74:UX(i)=x:UY(i)=y:UA(i)=247:UC(i)=2:UD(i)=0:UH(i)=11
  EndIf
End Sub
  
  
Sub place_magnet
  'UA()=sprite,UB()=duration in loops (around 15 seconds)
  Local i=findslot()
  If i<32 Then
    UT(i)=72:UX(i)=xp+h:UY(i)=yp+v:UA(i)=&h58:UB(i)=150
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
  if UB(i)=0 And UH(0)=0 then game_over
end sub
  
  
  'replaces 4 tiles of the trash compactor
sub anim_tc(x,y,a,b,c,d)
  MID$(lv$(y-1),x+1,1)=Chr$(a)
  MID$(lv$(y-1),x+2,1)=Chr$(b)
  MID$(lv$(y),x+1,1)=Chr$(c)
  MID$(lv$(y),x+2,1)=Chr$(d)
End Sub
  
  
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
  
  
  'this animates the fans, flags, water and the servers in the world map
Sub ani_tiles '@added by Martin
  'changing the pointer for the Animated Tiles
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
  
  
  
  'AI oriented sub ---------------------------------------------------
  'this is the main AI loop where AI all units are processed
  'routine runs in layer L, only some UNITS revert to n
  
Sub AI_units
  Local i,dx,dy,nearx,neary,xy,j
  
  if em_on=0 then
    For i=0 To 27 'units
      dx=UX(i)-xp:dy=UY(i)-yp
      nearx=Abs(dx):neary=Abs(dy)
      Select Case UT(i)
        Case 0,1 'player is animated through controls
        Case 2 'hoverbot_h
          If UH(i)>0 Then
            if UC(i)>1 then
              dazzle_bot(i)
            else
              walk_bot_h(i,dx,dy,b_hov)
            end if
          else  'sudden death" 2 seconds delay for dead body to vanish
            inc UH(i),-1:if UH(i)<-30 then UT(i)=0:robot_end
          EndIf
        Case 3 'hoverbot_v
          If UH(i)>0 Then
            if UC(i)>1 then
              dazzle_bot(i)
            else
              walk_bot_v(i,dx,dy,b_hov)
            end if
          Else  'sudden death" 2 seconds delay for dead body to vanish
            inc UH(i),-1:if UH(i)<-30 then UT(i)=0:robot_end
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
                  dazzle_bot(i)
                else
                  agro_bot(i,dx,dy,b_hov) 'bot move closer
                end if
              end if
            end if
          Else  'create a 1-2 seconds delay for the dead robot to vanish
            inc UH(i),-1:if UH(i)<-30 then UT(i)=0:robot_end
          EndIf
        Case 5 'hoverbot_drowning
          UD(i)=(UD(i)+1) Mod 6 'adapt for drowning speed
          if UD(i)=0 then
            UA(i)=UA(i)+1
            if UA(i)>&h8e then UT(i)=0:robot_end
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
                  dazzle_bot(i)
                else
                  agro_bot(i,dx,dy,0) 'bot move closer
                end if
              end if
            end if
          Else  'create a 1-2 seconds delay for the dead robot to vanish
            inc UH(i),-1:if UH(i)<-30 then UT(i)=0:robot_end
          EndIf
        Case 17 'rollerbot_v
          If UH(i)>0 Then
            if UC(i)>1 then
              dazzle_bot(i)
            else
              walk_bot_v(i,dx,dy,0)
            end if
            UB(i)=Max(UB(i)-1,0)
            If UB(i)=0 And UH(0)>0 Then
              If dy=0 Then bot_shoot_h(i,dx)
              If dx=0 Then bot_shoot_v(i,dy)
            EndIf
          Else  'create a 1-2 seconds delay for the dead body to vanish
            inc UH(i),-1:if UH(i)<-30 then UT(i)=0:robot_end
          EndIf
        Case 18 'rollerbot_h
          If UH(i)>0 Then
            if UC(i)>1 then
              dazzle_bot(i)
            else
              walk_bot_h(i,dx,dy,0)
            end if
            UB(i)=Max(UB(i)-1,0)
            If UB(i)=0 And UH(0)>0 Then
              If dy=0 Then bot_shoot_h(i,dx)
              If dx=0 Then bot_shoot_v(i,dy)
            EndIf
          Else  'create a 1-2 seconds delay for the dead body to vanish
            inc UH(i),-1:if UH(i)<-30 then UT(i)=0:robot_end
          EndIf
      End Select
    Next
  endif
  
  For i=28 To 31 'tile animations, explosions
    dx=UX(i)-xp:dy=UY(i)-yp
    nearx=Abs(dx):neary=Abs(dy)
    Select Case UT(i)
      Case 11 'small explosion
        Inc UA(i):If UA(i)=253 Then UT(i)=0 'done exploding
      Case 71 'bomb
        Inc UB(i),-1
        If UB(i)=0 Then
          do_damage(UX(i),UY(i),UC(i),0,UH(i)) 'do damage UH in radius < UC
          UA(i)=247 'explosion tile
          Play modsample s_dsbarexp,4
        EndIf
        If UB(i)<0 Then
          xof=4-xof:xs=5*24 - xof 'shake screen
          Inc UA(i)             'next tile in explosion sequence
          If UA(i)=253 Then xs=5*24:UT(i)=0 'done exploding
        EndIf
      Case 72 'magnet
        Inc UB(i),-1
        If UB(i)<0 Then
          UT(i)=0 'free slot
        Else
          if dx=0 And dy=0 then 'pick up magnet
            UT(i)=0:inc pl_ma:show_item
          else
            'check for robot contact with magnet
            j=has_unit(UX(i),UY(i))
            if j>0 And j<255 then 'mark robot
              UT(i)=0:UC(j)=2 'magnet used, bot move direction random
              play modsample s_magnet2,4
            end if
          EndIf
        endif
      Case 73 'emp
        if UB(i)<30 then  'freeze robots 3 seconds
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
        inc UB(i)
      Case 74 'canister blow or plasma blow
        if UA(i)=247 then 'only once...
          do_damage(UX(i),UY(i),UC(i),UD(i),UH(i)) 'do damage UH in radius < UC
          Play modsample s_dsbarexp,4
        end if
        Inc UA(i)  'next tile in explosion sequence
        If UA(i)=253 Then UT(i)=0 'done exploding
    End Select
  Next
  
  For i=32 To 47  'door animations, raft, elevator
    dx=UX(i)-xp:dy=UY(i)-yp
    nearx=Abs(dx):neary=Abs(dy)
    Select Case UT(i)
      Case 7 'transporter
        UB(i)=UB(i)+1 And 3 'UB=delay counter
        if UB(i)=0 then
          if UA(i)=0 then 'transporter active
            UH(i)=&h1E+(UH(i)=&h1E) 'UH=tile toggle between &h1E and &h1F
            MID$(lv$(UY(i)),UX(i)+1,1)=Chr$(UH(i))  'active transporter
            if dx=0 And dy=0 then
              if UA(0)<48 then UA(0)=&h4C 'if active player -> first tile of animation
              if UA(0)=&h52 then 'end of animation
                if UC(i)=0 then
                  UH(0)=0
                  'k$ = "escape" 'force game over by simulate pressing ESC
                else
                  xp=UC(i):yp=UD(i):UA(0)=pl_sp   'transport player
                endif
              endif
            endif
          else 'UA=1
            statistics(j,xy):if j=0 then UA(i)=0
          end if
        end if
      Case 10 'automatic doors
        If nearx<2 And neary<2 And UD(i)=0 Then   'operate door
          If UC(i)=0 Then
            open_door(i,UX(i),UY(i))
          ElseIf (2^(UC(i)-1) And pl_ky) Then 'bugfix untested
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
              if j=0 then
                writecomment("Player terminated")
              else
                writecomment("Robot terminated")
              end if
            end if
          end if
        else 'object in TC, crush it...
          if UB(i)=0 then
            UB(i)=1
            play modsample s_door,4 'start animation
            writecomment("Object crushed")
          endif
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
            if pl_md=p_w And UB(i)=5 then
              pl_md=p_ele1 'you are inside elevator door closed
              pl_el=UC(i)
              ele_instructions(i)
              writeplayer(0,1,pl_wp)
            end if
            if pl_md=p_ele2 then 'get out of the elevator
              open_elev(i,UX(i),UY(i))
              if UB(i)=2 then
                for j=0 to 3:writecomment(" "):next
                inc yp:pl_md=p_w 'walk out
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
            inc UX(i):if UX(i)=UC(i) then UA(i)=0:UD(i)=16 'wait at dock
          else 'move right
            INC UX(i),-1:IF UX(i)=UB(i) then UA(i)=1:UD(i)=16
          end if
          MID$(lv$(UY(i)),UX(i)+1,1)=Chr$(&hF2) 'new is raft tile
          if dx=0 And dy=0 then xp=UX(i) 'if we are on the raft, stay on it
        end if
        inc UD(i),-1 'timer
    End Select
  Next
End Sub
  
  
sub robot_end
  local j,k
  statistics(j,k)
  if j>0 then
    writecomment("Target destroyed, "+str$(j)+" remain")
  else
    writecomment("All robots destroyed")
    writecomment("Proceed to the teleporter")
  end if
end sub
  
  
  'for hoverbot and evilbot use same tracing algorithm
Sub agro_bot(i,dx,dy,hov)
  'UD(i) for speed counters
  'UA(i) as sprite number
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
  
  p=(p+1) And 3
  if hov=0 then 'evilbot
    UA(i)=d+p 'animated sprites for drawing
  else 'agro hoverbot
    UA(i)=&h31+p'notify new sprite for drawing
  end if
End Sub
  
  
Sub walk_bot_h(i,dx,dy,hov)
  'UC(i) = walking direction (default 0)
  'UD(i) for speed counters
  'UA(i) as sprite number
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
  'UC(i) = walking direction (default 0)
  'UD(i) for speed counters
  'UA(i) as sprite number
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
  
  
sub dazzle_bot(i)
  UD(i)=(UD(i)+1) And 3 'walking speed
  if UD(i)=0 then
    local r=int(rnd()*5),xy
    inc UC(i) 'time count 3,4...
    if UC(i)<32 then '30=15 seconds, counter starts at 2
      'new random location bot
      select case r
        case 0 'nothing
        case 1
          xy=UX(i)+1
          If (get_ta(xy,UY(i)) And b_wlk)>0 then
            if Not(dy=0 And xy=xp) Then inc UX(i)
          endif
        case 2
          xy=UX(i)-1
          If (get_ta(xy,UY(i)) And b_wlk)>0 then
            if Not(dy=0 And xy=xp) Then inc UX(i),-1
          end if
        case 3
          xy=UY(i)+1
          If (get_ta(UX(i),xy) And b_wlk)>0 then
            if Not(xy=yp And dx=0) Then inc UY(i)
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
  
  
  'applies d damage to all units and objects in a radius
Sub do_damage(x,y,r,s,d)
  Local i,j,a,rr,xm,xp,ym,yp
  
  rr=r-1 'tiles only inside radius
  xm=choice(s=-1,x,x-rr):xp=choice(s=1,x,x+rr)
  ym=choice(s=-2,y,y-rr):yp=choice(s=2,y,y+rr)
  
  For i=0 To 27 'all units
    If UX(i)>=xm And UX(i)<=xp then
      if UY(i)>=ym And UY(i)<=yp Then UH(i)=Max(UH(i)-d,0) 'do damage
    endif
  Next
  
  For i=48 To 63  'hidden content
    If UX(i)>=xm And UX(i)<=xp then
      if UY(i)>=ym And UY(i)<=yp Then UT(i)=0 'remove hidden item
    endif
  Next
  
  'depending the source s result of an explosion differs
  For i=xm To xp
    For j=ym To yp
      a=Asc(Mid$(lv$(j),i+1,1))
      Select Case a
        case &h80,&H81 'pi-paintings
          'do nothing
        Case &h83
          MID$(lv$(j),i+1,1)=Chr$(&h87) 'canister blown
          If i<>x Or j<>y Then blow_canister(i,j) 'not itself
        Case &h29 'carton box, empty
          MID$(lv$(j),i+1,1)=Chr$(&h2A)
        Case &hC7 'wooden box, empty
          MID$(lv$(j),i+1,1)=Chr$(&hC6)
        Case &h2D 'small box, empty
          MID$(lv$(j),i+1,1)=Chr$(&h2E)
        Case &hCD 'bridge. empty
          MID$(lv$(j),i+1,1)=Chr$(&hCC)
        case <&hCD 'indoor plant or empty boxes -> destroy
          if (get_ta(i,j) And b_dmg) then
            MID$(lv$(j),i+1,1)=Chr$(9)
          end if
        case >&hCD 'outdoor -> destroy
          if (get_ta(i,j) And b_dmg) then
            MID$(lv$(j),i+1,1)=Chr$(&hD0)
          end if
      End Select
    Next
  Next
End Sub
  
  
  'create a small explosion
Sub small_explosion(i)
  Local j
  j=findslot()
  If j<32 Then
    UT(j)=11:UX(j)=UX(i):UY(j)=UY(i):UA(j)=247  'explosion
    Play modsample s_dsbarexp,4
  EndIf
End Sub
  
  
  'small animation, uses part of the explosion tiles
sub zap(i)
  Local j
  j=findslot()
  If j<32 Then
    UT(j)=11:UX(j)=UX(i):UY(j)=UY(i):UA(j)=250  'short zap...
    Play modsample s_shock,4
  EndIf
end sub
  
  
  'starts animation showing explosion
sub explosion(i,s)
  if pl_wp=2 then 'plasma explosion 11 dmg radius 2
    Local j=findslot()
    If j<32 Then UT(j)=74:UX(j)=UX(i):UY(j)=UY(i):UA(j)=247:UB(j)=24:UC(j)=3:UD(j)=s:UH(j)=11
  else
    small_explosion(i) 'pistol explosion
  end if
end sub
  
  
  'find a free slot in the UNIT array (28...31)
Function findslot()
  Local i=28
  Do
    If UT(i)=0 Then
      Exit
    Else
      Inc i
    EndIf
  Loop Until i=32
  findslot=i
End Function
  
  
  'is there a robot/player on this location in the map (255=fail)
Function has_unit(x,y)
  Local i=0
  has_unit=255
  Do
    If UT(i)>0 Then
      If UX(i)=x Then
        If UY(i)=y Then has_unit=i
      end if
    end if
    Inc i
  Loop Until i=28
End Function
  
  
  
  
  'subs to support player handling ------------------------------------
  
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
  
  
  'update player sprites to be used on layer L, depending weapon and direction
Sub writeplayer(h,v,w)
  'UA(i) as sprite number
  pl_sp=8*(v=-1)+4*(h=1)+12*(h=-1)        'sprite matching orientation
  IF UA(0)<48 THEN UA(0)=pl_sp+pl_mv+16*w 'store in UNIT log
  pl_mv=(pl_mv+1) Mod 4                   'anime player
End Sub
  
  
  'weapon fire in horizontal direction
Sub fire_ew(p)
  'UD() is the start of the fire line
  'UC() is length of the fire line
  'UB() is the UNIT hit
  'UA() is the fire line sprite
  If pl_pa(pl_wp)>0 Then
    
    Local x=0,i,j,b=0,d=0,t,xip,typ
    
    i=findslot()      'find a weapon slot in UNIT array
    If i<32 Then
      
      UT(i)=127:UX(i)=xp:UY(i)=yp 'default claim array slot
      Do
        Inc x,p:xip=xp+x
        t=get_ta(xip,yp):UX(i)=xip      'next tile n/s
        typ=Asc(Mid$(lv$(yp),xip+1,1))
        
        j=has_unit(UX(i),UY(i))
        If j<255 Then 'if robot then damage it
          explosion(i,0)
          if pl_wp=1 then Inc UH(j),-1
          if UT(j)<4 then UT(j)=4 'hoverbot become aggressive
          Inc x,-p:Exit
          
        ElseIf typ=&h83 Then 'canister
          blow_canister(xip,yp)
          Inc x,-p:Exit
          
        elseif typ=&h81 Then 'vertical pi-sign
          Mid$(lv$(yp),xip+1,1)=chr$(8)
          explosion(i,p)
          Inc x,-p:Exit
          
        ElseIf (t And (b_see+b_wlk+b_hov)) Then  'pass fire, next tile
          
        Else'If (t And (b_see))=0 Then  'stopped by wall
          explosion(i,p)
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
    
    Local y=0,i,j,b=0,d=0,t,yip,typ
    
    i=findslot()      'find a weapon slot in UNIT array
    If i<32 Then
      
      UT(i)=127:UX(i)=xp:UY(i)=yp   'default claim array slot
      Do
        
        Inc y,p:yip=yp+y
        t=get_ta(xp,yip):UY(i)=yip 'next tile n/s
        typ=Asc(Mid$(lv$(yip),xp+1,1))
        
        j=has_unit(UX(i),UY(i))
        If j<255 Then 'if robot then damage it
          explosion(i,0)
          if pl_wp=1 then Inc UH(j),-1
          if UT(j)<4 then UT(j)=4 'hoverbot become aggressive
          Inc x,-p:Exit
          
        ElseIf typ=&h83 Then 'canister
          blow_canister(xp,yip)
          Inc y,-p:Exit
          
        ElseIf typ=&h80 Then 'horizontal pi-sign
          Mid$(lv$(yip),xp+1,1)=chr$(5)
          explosion(i,2*p)
          Inc y,-p:Exit
          
        ElseIf (t And (b_see+b_wlk+b_hov)) Then   'pass fire, next tile
          
        Else'If (t And (b_see))=0 Then  'stopped by wall
          explosion(i,2*p)
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
  
  
  'find the items in viewer area in the unit attributes
Sub exec_viewer
  'do thingsEnd Function
  Local i,j,a$="Nothing found",b
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
              b=choice(diff_level=0,2*UA(i),UA(i))
              Inc pl_pa(1),b
              pl_wp=1:show_weapon
              a$="found PISTOL with "+Str$(b)+" bullets"
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
        EndIf
      EndIf
    EndIf
  Next
  
  'if closed box, then open box
  j=Asc(Mid$(lv$(yp+v1),xp+h1+1,1))
  If j=&h29 Then j=&h2A
  If j=&h2D Then j=&h2E
  If j=&hC7 Then j=&hC6
  MID$(lv$(yp+v1),xp+h1+1,1)=Chr$(j)
  
  If a$="Nothing found" Then Play Modsample s_error,4:writecomment(a$)
  pl_md=p_w     'at the end, free player
End Sub
  
  
  'move object and return to walk mode
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
      move_hidden
      Play modsample s_move,4
    end if
  Else
    writecomment("Object cannot move here")
    Play modsample s_error,4
  EndIf
  pl_md=p_w                       'at the end, free player
End Sub
  
  
  'check if a hidden object should move with the box it is in
sub move_hidden
  local i
  for i=48 to 63
    if UX(i)=ox then
      if UY(i)=oy then
        UX(i)=tx:UY(i)=ty
      endif
    endif
  next
end sub
  
  
  'use item visible in frame (bomb/emp etc..)
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
      if pl_ma>0 then pl_md=p_mg1
    Case 4 'bomb
      if pl_bo>0 then pl_md=p_bo1
  End Select
  show_item
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
  
  
  'move player to the next floor (different location on the flat MAP)
sub next_floor(h)
  local i
  for i=32 to 47 'range where elevators live
    if UT(i)=19 And UC(i)=pl_el+h then
      xp=UX(i):yp=UY(i)-1:inc pl_el,h 'go inside this elevator
      UX(0)=xp:UY(0)=yp
      exit for 'found new floor
    endif
  next
end sub
  
  
  
  'generic subs for gameplay -------------------------------------------
  
  'for debugging
Sub show_ta(x,y)
  Text 0,0,Right$("0000000"+Bin$(get_ta(x,y)),8)
End Sub
  
  
  'calculate achievements
Sub statistics(b,h)
  Local ii,jj=0
  For ii=1 To 27   'check bots
    If UT(ii)>0 Then Inc jj
  Next
  b=jj:jj=0
  For ii=48 To 63  'check secrets
    If UT(ii)>127 Then Inc jj
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
  
  
sub select_music(a)
  Play stop
  select case a
    case 0
      Play modfile path$("music/get_psyched-sfx.mod")   'sfx combined with music
    case 1
      Play modfile path$("music/sfcmetallicbop2.mod")   'sfx combined with music
    case 2
      Play modfile path$("music/rushin_in-sfx.mod")     'sfx combined with music
    case 3
      Play modfile path$("music/petsciisfx.mod")        'only sfx
  end select
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
  lva=Peek(varaddr LV$())
  taa=Peek(varaddr TA$)
  
  'load world map and attributes
  pause 100: Open path$("data/level-"+Chr$(97+Map_Nr)) For input As #1
  
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
  dummy$=Input$(128,#1)  '256 empty bytes
  dummy$=Input$(128,#1)
  For i=0 To 63:LV$(i)=Input$(128,#1):Next
  Close #1
  
  'load destruct paths and tile attributes
  Open path$("data/tileset.amiga") For input As #1
  dummy$=Input$(2,#1) 'offset
  DP$=Input$(255,#1)  '255 destruct paths
  dummy$=Input$(1,#1) '1 path ignored
  TA$=Input$(255,#1)  '255 tile attributes
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
  
  
  'assign sound effects names
Sub preload_sfx
  'for all combined MOD files by Martin.H
  s_dsbarexp=16:s_dspistol=17:s_beep=18:s_beep2=19:s_cycle_item=20:s_cycle_weapon=21
  s_door=22:s_emp=23:S_error=24:s_found_item=25:s_magnet2=26:s_medkit=27:s_move=28
  s_plasma=29:s_shock=30
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
  'flash slot #3 has the exact same start address as the library
  flash disk load 3, path$("lib/pet_lib23.bin"),o
  
  'load global index file
  Dim sprite_index(&h60)
  Dim health_index(5)
  Dim tile_index(&hff)
  Dim item_index(5)
  Dim tla_index(&h17)
  Dim key_index(2)
  
  'read index file. the order must not be changed
  Open path$("lib/flash_index.txt") For input As #1
  
  For i=0 To &hFF
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
 Load image path$("images/introscreen.bmp"),0,10
 FRAMEBUFFER write l: fade_in: :FRAMEBUFFER write sc$
 Local integer puls(11)=(0,1,9,11,3,6,7,6,5,11,9,1),t,t2
 Local Message$(4) length 40

 'set Map to 0, Menu State to 1
 Message$(1)="...use UP & DOWN, Space or 'Start'      "
 Message$(2)="   ...use LEFT & RIGHT to select Map    "
 Message$(3)="  ...use LEFT & RIGHT cange Difficulty  "
 Dim DIFF_LEVEL_WORD$(2) length 6 =("EASY  ","NORMAL","HARD  ")
 Map_Nr=0:MS=1:Diff_level=1

 ' start playing the intro Music
 Play Modfile path$("music/metal_heads-sfx.mod")
 show_menu 1

 'Display Map Name
 Text 9,70,UCase$(map_nam$(Map_Nr))

 '--- copyright notices etc
 Text 0,224,Message$(1),,,,col(3)
 Local msg$ = String$(36,32)
 '  Cat msg$, sys.get_config$("device", "Generic " + Mm.Device$) + " - "
 Inc msg$, "Original Game by David Murray - "
 Inc msg$, "Port to Mite and MM-Basic by Volhout, Martin H and thebackshed-"
 Inc msg$, "Community - Music by Noelle Aman, Graphic by "
 Inc msg$, "Piotr Radecki - MMBasic by Geoff Graham and Peter Mather "
 flip=0
 MT=0

 'check player choice
 kill_kb
 Do
   If flip=0 Then Inc MT:If mt>Len(msg$) Then MT=0
   tp$=Mid$(msg$,1+MT,41)
   If t2=0 Then 'once every 4 cycles
     k$=read_input$()
     If k$<>"" Then
       Play modsample s_beep-2,4
       If k$="down" Then Inc MS,(MS<3)
       If k$="up" Then Inc MS,-(MS>1)
       If k$="use-item" Then
         Select Case MS
           Case 1
             FRAMEBUFFER write L:fade_out:FRAMEBUFFER write sc$
             Exit 'intro and go on with the Program
           Case 2
             'select map
             kill_kb
             Text 0,224,message$(2),,,,col(3)
             Do
               k$=read_input$()
               If k$<>"" Then
                 Play modsample s_beep-2,4
                 If k$="left" Then Inc Map_Nr,-(Map_Nr>0)
                 If k$="right" Then Inc Map_Nr,(Map_Nr<13)
                 If k$="use-item" Then
                   Text 0,224,message$(1),,,,col(3): Exit
                 EndIf
                 Text 9,70,"                "
                 Text 9,70,UCase$(map_nam$(Map_Nr))
                 If LCD_DISPLAY Then FRAMEBUFFER Merge 9,b
               EndIf
               Pause 200
             Loop
             kill_kb
           Case 3
             'select DIFFICULTY
             kill_kb
             Text 0,224,message$(3),,,,col(3)
             Do
               k$=read_input$()
               If k$<>"" Then
                 Play modsample s_beep-2,4
                 If k$="use-item" Then
                   Text 0,224,message$(1),,,,col(3)
                   Text 0,232,"      "
                   Exit
                 EndIf
                 If k$="left" Then
                   Inc Diff_Level,-(Diff_Level>0)
                 EndIf
                 If k$="right" Then
                   Inc Diff_Level,(Diff_Level<2)
                 EndIf
                 Text 0,232,DIFF_LEVEL_WORD$(Diff_Level)
                 Load image path$("images/face_"+Str$(Diff_Level)+".bmp"),234,85
                 If LCD_DISPLAY Then FRAMEBUFFER Merge 9,b
               EndIf
               Pause 200
             Loop
             kill_kb
            End Select
       EndIf
     EndIf
   EndIf

   show_menu MS,col(puls(t))

   Text 8-(2*flip),0,tp$,,,,col(2):flip=(flip+1) And 3
   Inc t: t=t Mod 12 'color change
   Inc t2: t2=t2 Mod 3 'reponse time keys
   If LCD_DISPLAY Then FRAMEBUFFER Merge 9,b
   Pause 50
 Loop
 Play stop
End Sub


 'remove duplicate keys and key repeat
Sub kill_kb
 Do While read_input$() <> "" : Loop
End Sub


 'start menu selection list
Sub show_menu(n1,FC)
 Local tc,BG=0,f2=col(10)
 tc=f2 :If n1=1 Then tc=FC
 Text 32,30,"START GAME",,,,tc
 tc=f2 : :If n1=2 Then tc=FC
 Text 32,38,"SELECT MAP",,,,tc
 tc=f2 : :If n1=3 Then tc=FC
 Text 32,46,"DIFFICULTY",,,,tc
End Sub

  
  
Sub fade_in
  Local n,x,y
  For n=0 To 7
    For x=n To 320 Step 8:Line x,0,x,240,,col(5):Next
    For y=n To 240 Step 8:Line 0,y,320,y,,col(5):Next
    If LCD_DISPLAY Then FrameBuffer Merge 9,b
    Pause 50+130*LCD_DISPLAY
  Next
End Sub
  
  
Sub fade_out
  Local n,x,y
  For n=0 To 7
    For x=n To 320 Step 8:Line x,0,x,240,,0:Next
    For y=n To 240 Step 8:Line 0,y,320,y,,0:Next
    If LCD_DISPLAY Then FrameBuffer Merge 9,b
    Pause 50+130*LCD_DISPLAY
  Next
End Sub
  
Function read_input$()
  Static last$
  read_input$ = read_inkey$()
  If Len(read_input$) Then Exit Function
  read_input$ = Call(CTRL_DRIVER$)
  
  ' Suppress auto-repeat except for movement.
  If last$ = read_input$ Then
    If Not InStr("up,down,left,right", last$) Then
      read_input$ = ""
      Exit Function
    EndIf
  Else
    last$ = read_input$
  EndIf
End Function
  
Function read_inkey$()
  Select Case Asc(Inkey$)
      Case 0   : Exit Function
      Case 9   : read_inkey$ = "map"          ' Tab
      Case 27  : read_inkey$ = "escape"
      Case 32  : read_inkey$ = "use-item"     ' Space
      Case 77  : read_inkey$ = "toggle-music" ' M
      Case 97  : read_inkey$ = "fire-left"    ' a
      Case 100 : read_inkey$ = "fire-right"   ' d
      Case 109 : read_inkey$ = "move"         ' m
      Case 115 : read_inkey$ = "fire-down"    ' s
      Case 119 : read_inkey$ = "fire-up"      ' w
      Case 121, 122 : read_inkey$ = "search"  ' y, z
      Case 128 : read_inkey$ = "up"
      Case 129 : read_inkey$ = "down"
      Case 130 : read_inkey$ = "left"
      Case 131 : read_inkey$ = "right"
      Case 145 : read_inkey$ = "toggle-weapon" ' F1
      Case 146 : read_inkey$ = "toggle-item"   ' F2
      Case 147 : read_inkey$ = "cheat"         ' F3
      Case 148 : read_inkey$ = "kill-all"      ' F4
  End Select
End Function
  
  '---joystick/Gamepad specific settings
  
  
  ' Dummy controller driver.
Function ctrl_none$(init)
End Function
  
  
  ' Controller driver for Game*Mite.
Function ctrl_gamemite$(init)
  If Not init Then
    Local bits = Inv Port(GP8, 8) And &hFF, s$
    
    Select Case bits
        Case 0    : Exit Function
        Case &h01 : s$ = "down"
        Case &h02 : s$ = "left"
        Case &h04 : s$ = "up"
        Case &h08 : s$ = "right"
        Case &h10 : s$ = "escape"        ' Select
        Case &h20 : s$ = "use-item"      ' Start
        Case &h40 : s$ = "search"        ' Fire B
        Case &h41 : s$ = "toggle-item"   ' Down + Fire B
        Case &h44 : s$ = "toggle-weapon" ' Up + Fire B
        Case &h80 : s$ = "move"          ' Fire A
        Case &h81 : s$ = "fire-down"     ' Down + Fire A
        Case &h82 : s$ = "fire-left"     ' Left + Fire A
        Case &h84 : s$ = "fire-up"       ' Up + Fire A
        Case &h88 : s$ = "fire-right"    ' Right + Fire A
        Case &hC0 : s$ = "map"           ' Fire A + Fire B
    End Select
    
    ctrl_gamemite$ = s$
    Exit Function
  Else
    ' Initialise GP8-GP15 as digital inputs with PullUp resistors
    Local i
    For i = 8 To 15
      SetPin MM.Info(PinNo "GP" + Str$(i)), Din, PullUp
    Next
  EndIf
End Function
  
  
  ' Controller driver for NES gamepad connected to PicoGAME VGA port A.
Function ctrl_nes_a$(init)
  If Not init Then
    Local bits, i, s$
    
    Pulse NES_A_LATCH, NES_PULSE!
    For i = 0 To 7
      If Not Pin(NES_A_DATA) Then bits=bits Or 2^i
      Pulse NES_A_CLOCK, NES_PULSE!
    Next
    
    Select Case bits
        Case 0    : Exit Function
        Case &h01 : s$ = "move"          ' Fire A
        Case &h02 : s$ = "search"        ' Fire B
        Case &h03 : s$ = "map"           ' Fire A + Fire B
        Case &h04 : s$ = "escape"        ' Select
        Case &h08 : s$ = "use-item"      ' Start
        Case &h10 : s$ = "up"
        Case &h11 : s$ = "fire-up"       ' Up + Fire A
        Case &h12 : s$ = "toggle-weapon" ' Up + Fire B
        Case &h20 : s$ = "down"
        Case &h21 : s$ = "fire-down"     ' Down + Fire A
        Case &h22 : s$ = "toggle-item"   ' Down + Fire B
        Case &h40 : s$ = "left"
        Case &h41 : s$ = "fire-left"     ' Left + Fire A
        Case &h80 : s$ = "right"
        Case &h81 : s$ = "fire-right"    ' Right + Fire A
    End Select
    
    ctrl_nes_a$ = s$
    Exit Function
  Else
    SetPin NES_A_DATA, DIn
    SetPin NES_A_LATCH, DOut
    SetPin NES_A_CLOCK, DOut
    SetPin GP14, DOut
    Pin(GP14) = 1 ' Power for the NES controller - unnecessary ?
  EndIf
End Function
  
  
  ' Controller driver for Atari joystick connected to PicoGAME VGA port A.
Function ctrl_atari_a$(init)
  If Not init Then
    Local bits, s$
    Inc bits, Not Pin(GP14)       ' Fire
    Inc bits, Not Pin(GP0) * &h02 ' Up
    Inc bits, Not Pin(GP1) * &h04 ' Down
    Inc bits, Not Pin(GP2) * &h08 ' Left
    Inc bits, Not Pin(GP3) * &h10 ' Right
    
    Select Case bits
        Case 0    : Exit Function
        Case &h02 : s$ = "up"
        Case &h03 : s$ = "fire-up"
        Case &h04 : s$ = "down"
        Case &h05 : s$ = "fire-down"
        Case &h08 : s$ = "left"
        Case &h09 : s$ = "fire-left"
        Case &h10 : s$ = "right"
        Case &h11 : s$ = "fire-right"
    End Select
    
    ctrl_atari_a$ = s$
    Exit Function
  Else
    SetPin GP0, DIn : SetPin GP1, DIn : SetPin GP2, DIn : SetPin GP3, DIn : SetPin GP14, DIn
  EndIf
End Function
  
  
  ' Controller driver for Wii Classic gamepad.
Function ctrl_wii_classic$(init)
  If Not init Then
    Local bits, i, s$
    bits = Device(Wii b)
    If bits Then
      Select Case bits
          Case &h0001 : s$ = "toggle-item"   ' R shoulder button
          Case &h0002 : s$ = "use-item"      ' Start
          Case &h0004 : s$ = "map"           ' Home
          Case &h0008 : s$ = "escape"        ' Select
          Case &h0010 : s$ = "toggle-weapon" ' L shoulder button
          Case &h0020 : s$ = "fire-down"     ' Cursor down
          Case &h0040 : s$ = "fire-right"    ' Cursor right
          Case &h0080 : s$ = "fire-up"       ' Cursor up
          Case &h0100 : s$ = "fire-left"     ' Cursor left
          Case &h0800 : s$ = "move"          ' Button A
          Case &h2000 : s$ = "search"        ' Button B
      End Select
    Else
      ' Right analog joystick.
      Select Case Device(Wii RY)
          Case < 50  : s$ = "down"
          Case > 205 : s$ = "up"
      End Select
      Select Case Device(Wii RX)
          Case < 50  : s$ = "left"
          Case > 205 : s$ = "right"
      End Select
    EndIf
    
    ctrl_wii_classic$ = s$
    Exit Function
  Else
    Device Wii Open
  EndIf
End Function
  
  
  ' Use a function to save 256 bytes of heap that a string would take.
Function path$(f$)
  Select Case Mm.Info(path)
      Case "", "NONE" : path$ = Cwd$
      Case Else: path$ = Mm.Info(path)
  End Select
  If Len(f$) Then Cat path$, "/" + f$
End Function
  
  
  ' Reads property from config (.ini) file.
  '
  ' @param  key$      case-insensitive key for property to lookup.
  ' @param  default$  value to return if property or file is not present.
  ' @param  file$     file to read. If empty then read "A:/.spconfig", or
  '                   if that is not present "A:/.config".
Function sys.get_config$(key$, default$, file$)
  sys.get_config$ = default$
  If file$ = "" Then
    Const file_$ = Choice(Mm.Info(Exists file "A:/.spconfig"), "A:/.spconfig", "A:/.config")
  Else
    Const file_$ = file$
  EndIf
  If Not Mm.Info(Exists file file_$) Then Exit Function
  
  Local key_$ = LCase$(key$), s$, v$
  Open file_$ For Input As #1
  Do While Not Eof(#1)
    Line Input #1, s$
    If LCase$(Field$(Field$(s$, 1, "=", Chr$(34)),1, "#;", Chr$(34))) = key_$ Then
      v$ = Field$(Field$(s$, 2, "=", Chr$(34)), 1, "#;", Chr$(34))
      If Left$(v$, 1) = Chr$(34) Then v$ = Mid$(v$, 2)
      If Right$(v$, 1) = Chr$(34) Then v$ = Mid$(v$, 1, Len(v$) - 1)
      sys.get_config$ = v$
      Exit Do
    EndIf
  Loop
  Close #1
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
