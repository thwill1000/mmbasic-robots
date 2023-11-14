  'this tool creates a single absolute index file from all relative index files.
  'uses pre-loaded library as basis
  
  
  option default integer
  
  'load tile and sprite indexes for locations in the library
  
  'get start addresses
  hlt=Peek(cfunaddr HEALTH)
  spr=Peek(cfunaddr SPRITES)
  til0=Peek(cfunaddr TILE0)
  til1=Peek(cfunaddr TILE1)
  til2=Peek(cfunaddr TILE2)
  til3=Peek(cfunaddr TILE3)
  itemx=Peek(cfunaddr ITEM)
  tlx=Peek(cfunaddr TLA)
  keys=Peek(cfunaddr KEY)
  
  'build global index file
  Dim sprite_index(&h60)
  Dim health_index(5)
  Dim tile_index(&hff)
  Dim item_index(5)
  Dim tla_index(&h17)
  Dim key_index(2)
  
  'read an calculate (copy of pet23.bas sub "loadindex")
  
  Open "../sprites/hlt_index.txt" For input As #1
  For i=0 To 5
    Input #1,a$
    health_index(i)=hlt+Val(a$)
  Next
  Close #1
  
  Open "../sprites/spr_index.txt" For input As #1
  For i=0 To &h5f
    Input #1,a$
    sprite_index(i)=spr+Val(a$)
  Next
  Close #1
  
  Open "../tiles/tile0_index.txt" For input As #1
  For i=0 To &h3f
    Input #1,a$
    tile_index(i)=til0+Val(a$)
  Next
  Close #1
  
  Open "../tiles/tile1_index.txt" For input As #1
  For i=&h40 To &h7f
    Input #1,a$
    tile_index(i)=til1+Val(a$)
  Next
  Close #1
  
  Open "../tiles/tile2_index.txt" For input As #1
  For i=&h80 To &hbf
    Input #1,a$
    tile_index(i)=til2+Val(a$)
  Next
  Close #1
  
  Open "../tiles/tile3_index.txt" For input As #1
  For i=&hc0 To &hff
    Input #1,a$
    tile_index(i)=til3+Val(a$)
  Next
  Close #1
  
  Open "../tiles/tla_index.txt" For input As #1
  For i=0 To &h17
    Input #1,a$
    tla_index(i)=tlx+Val(a$)
  Next
  Close #1
  
  Open "../sprites/key_index.txt" For input As #1
  For i=0 To 2
    Input #1,a$
    key_index(i)=keys+Val(a$)
  Next
  Close #1
  
  Open "../sprites/item_index.txt" For input As #1
  For i=0 To 5
    Input #1,a$
    item_index(i)=itemx+Val(a$)
  Next
  Close #1

  
  'write relative indices to new file
  'library is located in flash slot 4
  
  fl_adr=mm.info(flash address 4)
  
  Open "../lib/flash_index.txt" For OUTPUT As #1
  
  For i=0 To &hff
    print #1,str$(tile_index(i)-fl_adr)
  Next
  
  For i=0 To &h17
    print #1,str$(tla_index(i)-fl_adr)
  Next
  
  For i=0 To 2
    print #1,str$(key_index(i)-fl_adr)
  Next
  
  For i=0 To 5
    print #1,str$(item_index(i)-fl_adr)
  Next
  
  For i=0 To 5
    print #1,str$(health_index(i)-fl_adr)
  Next
  
  For i=0 To &h5f
    print #1,str$(sprite_index(i)-fl_adr)
  Next
  
  Close #1
  
end
