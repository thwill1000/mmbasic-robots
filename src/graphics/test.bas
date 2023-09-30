'scroll test
MODE 2
Dim LV$(64) Length 128
Open "Data\LEV-a.bin" For input As #1
For f=0 To 63:LV$(f)=Input$(128,#1):Next
Close #1
'prepare screen
path$="tiles\"
FRAMEBUFFER layer
FRAMEBUFFER write l
Load image "layer.bmp"
FRAMEBUFFER write n
ox=0:oy=0
For y=0 To 8
  For x=0 To 11
    vl=Asc(Mid$(lv$(y+oy),ox+x+1,1))
    Sprite load path$+"TL"+Hex$(vl,3)+".SPR",1
    Sprite write 1,x*24,y*24
  Next
Next
FRAMEBUFFER write l
ox=13
x=0:oy=32

'scroll left
 f=4:y=0
 Do
  fn$="sprites\SP"+Hex$(f,3)+".SPR"
  Sprite load fn$,1
  FRAMEBUFFER write l
  Sprite write 1,120,96,0
  vl=Asc(Mid$(lv$(y+oy),ox,1))
  Sprite load path$+"TL"+Hex$(vl,3)+".SPR",20+y
  FRAMEBUFFER write n
  nn=-2-(y Mod 2)
  Sprite scroll nn,0
  Inc y
  If y =9 Then
    'draw next column
    For y=0 To 8:Sprite write 20+y,264,y*24,0:Next
    y=0:Inc ox
  EndIf
Inc f:If f=8 Then f=4
Loop
