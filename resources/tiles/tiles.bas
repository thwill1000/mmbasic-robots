cls
for x=0 to 15: text 32+x*32,1," "+Hex$(x,1):next
for y=0 to 15
text 0,32+y*32,Hex$(y,1)
for x= 0 to 15
   nr=y*16+x
   l$="TL"+hex$(nr,3)+".spr"
   sprite load l$,1
   sprite write 1,32+x*32,32+y*32
next x:next y
