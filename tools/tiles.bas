CLS
For x=0 To 15: Text 32+x*32,1," "+Hex$(x,1):Next
For y=0 To 15
Text 0,32+y*32,Hex$(y,1)
For x= 0 To 15
   nr=y*16+x
   l$="TL"+Hex$(nr,3)+".spr"
   Sprite load l$,1
   Sprite write 1,32+x*32,32+y*32
Next x:Next y
