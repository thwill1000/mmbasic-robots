Cls
Print "Attack of the PETSCII Robots is loading, please wait ..."
Const file$ = Mm.Info$(Path) + "src/robots.bas"
If InStr(Mm.Device$, "PicoMite") Then
  Cmm2 Run file$, Mm.CmdLine$
Else
  Run file$, Mm.CmdLine$
EndIf
