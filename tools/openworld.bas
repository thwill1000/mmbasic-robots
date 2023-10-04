'define variables
  dim UT$ length 64       'unit type
  dim ULX$ length 64      'unit X coordinate
  dim ULY$ length 64      'unit X coordinate
  dim UA$ length 64       'unit A parameter
  dim UB$ length 64       'unit B parameter
  dim UC$ length 64       'unit C parameter
  dim UD$ length 64       'unit D parameter
  dim UH$ length 64       'unit health
  
  Dim LV$(64) Length 128  'the map 128h x 64v with tile numbers
  DIM TA$                 '256-1 tile attributes
  dim DP$                 '256-1 destruction paths
  
  
'load world map and attributes
  Open "data\level-a" For input As #1
  UT$=input$(64,#1)
  ULX$=input$(64,#1)
  ULY$=input$(64,#1)
  UA$=input$(64,#1)
  UB$=input$(64,#1)
  UC$=input$(64,#1)
  UD$=input$(64,#1)
  UH$=input$(64,#1)
  dum$=input$(128,#1) 'maar dit is leeg.
  dum$=input$(128,#1) 'maar dit is leeg.
  For i=0 To 63:LV$(i)=Input$(128,#1):Next i
  Close #1
  
'load destruct paths and tile attributes
  Open "data\tileset.amiga" For input As #1
  dum$=Input$(2,#1) 'offset
  DP$=Input$(255,#1)  '255 destruct paths
  dum$=Input$(1,#1) '1 path ignored
  TA$=input$(255,#1)  '255 tile attributes
'  dum$=Input$(1,#1) '1 attribute ignored
  close #1
  
  
  for i=1 to 64:print right$("0"+hex$(asc(mid$(ut$,i,1))),2);" ";:next:print
  for i=1 to 64:print right$("0"+hex$(asc(mid$(ulx$,i,1))),2);" ";:next:print
  for i=1 to 64:print right$("0"+hex$(asc(mid$(uly$,i,1))),2);" ";:next:print
  for i=1 to 64:print right$("0"+hex$(asc(mid$(ua$,i,1))),2);" ";:next:print
  for i=1 to 64:print right$("0"+hex$(asc(mid$(ub$,i,1))),2);" ";:next:print
  for i=1 to 64:print right$("0"+hex$(asc(mid$(uc$,i,1))),2);" ";:next:print
  for i=1 to 64:print right$("0"+hex$(asc(mid$(ud$,i,1))),2);" ";:next:print
  for i=1 to 64:print right$("0"+hex$(asc(mid$(uh$,i,1))),2);" ";:next:print
  print
  for i=1 to 255:print right$("0"+hex$(asc(mid$(ta$,i,1))),2);" ";:next:print
'for i=1 to 255:print right$("0"+hex$(asc(mid$(ta$,i,1))and &h3f),2);" ";:next:print
