'--------------------
'Information of Source here
FN$="spritesMix_bearbeitet.bmp"
W=24
H=24
num=86
'--------------------
'
Dim Col(15):Restore colors:For f%=1 To 15:Read Col(f%):Next f%
cls
load bmp FN$
 x=0
 y=0
For TNR=0 to num-1

  tn$="sprites3\SP3"+hex$(tnr,3)+".SPR"
  open tn$ for output as #1
  print #1,str$(W);",1,";STR$(H)
  for y1=y to y+H-1
     WT$=""
       for x1=x to x+W-1
         C=Pixel(x1,y1):cl=0
         for n= 0 to 15:if C=col(n) then cl=n
         Next
         wt$=wt$+hex$(cl,1)
       Next
     ?#1, wt$
   next
   box x,y,w,h,,rgb (white)
 close #1
inc y,h:if y>383 then y=0:inc x,w
next TNR


colors:
'--Colorscheme accordung to Spritecolors
Data RGB(BLUE),RGB(GREEN),RGB(CYAN),RGB(RED)
Data RGB(MAGENTA),RGB(YELLOW),RGB(WHITE),RGB(MYRTLE)
Data RGB(COBALT) ,RGB(MIDGREEN),RGB(CERULEAN),RGB(RUST)
Data RGB(FUCHSIA),RGB(BROWN),RGB(LILAC)
