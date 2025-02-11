'program to convert all the sprite files in a directory to a CSUB using compression where appropriate
Option explicit
Option default none
Const separatesubs% = 0
Dim offset%
Dim fname$=Dir$("*.spr",FILE)

Open "tile3_csub.bas" For output As #2
Open "tile3_index.txt" For output As #3


If separatesubs%=0 Then
Print #2,"CSUB TILE3"
Print #2,"00000000"
offset%=0
EndIf
Do
If fname$<>"" Then code fname$
fname$=Dir$()
Loop Until fname$=""
If separatesubs%=0 Then Print #2,"END CSUB"

Close #2
Close #3


'convert the file f$ to a compressed CSUB
Sub code f$
Local i%,j%,h%,l%,w%,n%,s%,il%
Local a$,o$,oc$
Open f$ For input As #1
Line Input #1,a$ 'process the dimensions and count
w%=Val(Field$(a$,1,","))
n%=Val(Field$(a$,2,","))
h%=Val(Field$(a$,3,","))
If h%=0 Then h%=w%
i%=Instr(f$,".")
o$=Left$(f$,i%-1)
If separatesubs%=1 Then
   Print #2,"CSUB "+o$
   Print #2,"00000000"
   offset%=0
' Else
'    Print #2,"'"+o$
EndIf
Local obuff%(w%*h%\8+128),buff%(w%*h%\8+128)
For s%=1 To n% 'process all the sprites in a file
  Print #3,Str$(offset%)
  Print #2,"'Offset ";offset%
  For l%=1 To h%
    a$="'"
    Do While Left$(a$,1)="'" 'skip comments
      Line Input #1,a$
    Loop
    'make sure all lines are the correct length
    If Len(a$)<w% Then Inc a$,Space$(w%-Len(a$))
    If Len(a$)>w% Then a$=Left$(a$,w%)
    LongString append buff%(),a$ 'get all the file into a single longstring
  Next l%
  j%=0
  For i%=1 To LLen(buff%())
    LongString append obuff%(),mycol$(LGetStr$(buff%(),i%,1))
  Next i%
  LongString clear buff%()
  il%=(LLen(obuff%())+7)\8 * 8
  i%=0
  Do While i%<w%*h% 'compress the data
    j%=LGetByte(obuff%(),i%)
    l%=1
    Inc i%
    Do While LGetByte(obuff%(),i%)=j% And l%<15
      Inc l%
      Inc i%
    Loop
    LongString append buff%(), Hex$(l%)+Chr$(j%)
  Loop
  'the output must be a multiple of 8 nibbles
  LongString append buff%(),Left$("00000000",8-(LLen(buff%()) Mod 8))
  If LLen(buff%())<il% Then 'compressed version is smaller so use it
    Print #2,"'"+o$;
    Print #2," is compressed"
    Print #2,Hex$(h%+&H8000,4)+Hex$(w%,4)
    j%=0
    For i%=8 To LLen(buff%()) Step 8 'reverse the order
      o$=LGetStr$(buff%(),i%,1)
      Inc o$,LGetStr$(buff%(),i%-1,1)
      Inc o$,LGetStr$(buff%(),i%-2,1)
      Inc o$,LGetStr$(buff%(),i%-3,1)
      Inc o$,LGetStr$(buff%(),i%-4,1)
      Inc o$,LGetStr$(buff%(),i%-5,1)
      Inc o$,LGetStr$(buff%(),i%-6,1)
      Inc o$,LGetStr$(buff%(),i%-7,1)
      Inc j%
      If j%=8 Then
        Print #2,o$
        j%=0
      Else
        Print #2,o$+" ";
      EndIf
    Next i%
    If j%<>0 Then Print #2,""
    Inc offset%,4+LLen(buff%())\2
  Else
    Print #2,"'"+o$;
    Print #2," is uncompressed"
    Print #2,Hex$(h%,4)+Hex$(w%,4)
    LongString append obuff%(),Left$("00000000",8-(LLen(obuff%()) Mod 8))
    j%=0
    For i%=8 To LLen(obuff%()) Step 8 'reverse the order
      o$=LGetStr$(obuff%(),i%,1)
      Inc o$,LGetStr$(obuff%(),i%-1,1)
      Inc o$,LGetStr$(obuff%(),i%-2,1)
      Inc o$,LGetStr$(obuff%(),i%-3,1)
      Inc o$,LGetStr$(obuff%(),i%-4,1)
      Inc o$,LGetStr$(obuff%(),i%-5,1)
      Inc o$,LGetStr$(obuff%(),i%-6,1)
      Inc o$,LGetStr$(obuff%(),i%-7,1)
      Inc j%
      If j%=8 Then
        Print #2,o$
        j%=0
      Else
        Print #2,o$+" ";
      EndIf
    Next i%
    If j%<>0 Then Print #2,""
    Inc offset%,4+LLen(obuff%())\2
  EndIf
  LongString clear obuff%()
  LongString clear buff%()
Next s%
Close #1
If separatesubs%=1 Then Print #2,"END CSUB"
End Sub
'
'converts the Ascii colour from the Maximite standard to PicoMite standard
Function mycol$(c$)
Static cols%(15)=(0,1,6,7,8,9,14,15,2,3,4,5,10,11,12,13)
Local i%
If c$=" " Then c$="0"
i%=Val("&H"+c$)
mycol$=Hex$(cols%(i%))
End Function