'program to convert all the sprite files in a directory to a CSUB
Option explicit
Option default none
Const separatesubs% = 0
Dim offset%,cols%(15)=(0,1,6,7,8,9,14,15,2,3,4,5,10,11,12,13)
Dim fname$=Dir$("*.spr",FILE)
If separatesubs%=0 Then
 Print #0,"CSUB SPRITES"
 Print #0,"00000000"
 offset%=0
 EndIf
Do
If fname$<>"" Then code fname$
fname$=Dir$()
Loop Until fname$=""
If separatesubs%=0 Then Print #0,"END CSUB"


Sub code f$
Local i%,j%,h%,l%,w%,n%,s%
Local a$,o$
Open f$ For input As #1
Line Input #1,a$
w%=Val(Field$(a$,1,","))
n%=Val(Field$(a$,2,","))
h%=Val(Field$(a$,3,","))
If h%=0 Then h%=w%
i%=Instr(f$,".")
o$=Left$(f$,i%-1)
If separatesubs%=1 Then
    Print #0,"CSUB "+o$
    Print #0,"00000000"
    offset%=0
 Else
    Print #0,"'"+o$
 EndIf
Local buff%(w%*h%\8+2)
For s%=1 To n%
 Print "'Offset ";offset%
 Print #0,Hex$(h%,4)+Hex$(w%,4)
 For l%=1 To h%
  a$="'"
  Do While Left$(a$,1)="'" 'skip comments
   Line Input #1,a$
  Loop
  If Len(a$)<w% Then Inc a$,Space$(w%-Len(a$))
  If Len(a$)>w% Then a$=Left$(a$,w%)
  LongString append buff%(),a$
 Next l%
 If LLen(buff%()) Mod 8 Then
  LongString append buff%(),Space$(8-(LLen(buff%()) Mod 8))
 EndIf
 j%=0
 For i%=8 To LLen(buff%()) Step 8
  o$=mycol$(LGetStr$(buff%(),i%,1))
  Inc o$,mycol$(LGetStr$(buff%(),i%-1,1))
  Inc o$,mycol$(LGetStr$(buff%(),i%-2,1))
  Inc o$,mycol$(LGetStr$(buff%(),i%-3,1))
  Inc o$,mycol$(LGetStr$(buff%(),i%-4,1))
  Inc o$,mycol$(LGetStr$(buff%(),i%-5,1))
  Inc o$,mycol$(LGetStr$(buff%(),i%-6,1))
  Inc o$,mycol$(LGetStr$(buff%(),i%-7,1))
  Print #0,o$+" ";
  Inc j%
  If j% Mod 8 = 0 Then Print #0,""
 Next i%
 Inc offset%,4+LLen(buff%())\2
 LongString clear buff%()
 If j% Mod 8 <> 0 Then Print #0,""
Next s%
Close #1
If separatesubs%=1 Then Print #0,"END CSUB"
End Sub
Function mycol$(c$)
Local i%
If c$=" " Then c$="0"
i%=Val("&H"+c$)
mycol$=Hex$(cols%(i%))
End Function
