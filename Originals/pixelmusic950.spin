
''**********************************************************      
''*     Pixelmusic 3000                                    *
''*                                                        *
''*     Created by Tarikh Korula for Uncommon Projects     *
''*                                                        *
''*     January 2008                                       *
''*                                                        *
''**********************************************************


{
  TODOs
        Finalize Color Palettes

        > Finalize Shapes

        > Add Random selection to shape

        > Timing Routine for color

        Comments
        
        Title Screen
}
CON

  _clkmode = xtal1 + pll16x
  _xinfreq = 5_000_000
  _stack = ($3000 + $3000 + 100) >> 2   'accomodate display memory and stack

  x_tiles = 16
  y_tiles = 12

  paramcount = 14       
  bitmap_base = $2000
  display_base = $5000

  lines = 5
  thickness = 2

  DELAYUNIT = 10_000_000 '1/8 of a sec

  ADC_CLK       = 0 'Clock to ADC   
  ADC_DIN       = 1 'Data to/from ADC  
  ADC_CS        = 2 'CS to ADC  
  

VAR


  long  tv_status     '0/1/2 = off/visible/invisible           read-only
  long  tv_enable     '0/? = off/on                            write-only
  long  tv_pins       '%ppmmm = pins                           write-only
  long  tv_mode       '%ccinp = chroma,interlace,ntsc/pal,swap write-only
  long  tv_screen     'pointer to screen (words)               write-only
  long  tv_colors     'pointer to colors (longs)               write-only               
  long  tv_hc         'horizontal cells                        write-only
  long  tv_vc         'vertical cells                          write-only
  long  tv_hx         'horizontal cell expansion               write-only
  long  tv_vx         'vertical cell expansion                 write-only
  long  tv_ho         'horizontal offset16                     write-only
  long  tv_vo         'vertical offset16                       write-only
  long  tv_broadcast  'broadcast frequency (Hz)                write-only
  long  tv_auralcog   'aural fm cog                            write-only

  word  screen[x_tiles * y_tiles]
  long  colors[64]

  long delayStack[16]    
  byte lastrand
  byte delayflag
  

OBJ

  tv            : "tv"
  gr            : "graphics"
  adc           : "MCP3208"


  
PUB start | i, j, scalar_r, scalar_bigd, scalar_l, lastscalar, rightADCavg, leftADCavg, totalavg, rotateflag, changebit, changedisplay, displayroutine

  'turn on the LED
  dira[16]~~
  outa[16]~~

  
  adc.start(ADC_DIN,  ADC_CLK, ADC_CS, $FF)

  'start tv
  longmove(@tv_status, @tvparams, paramcount)
  tv_screen := @screen
  tv_colors := @colors
  tv.start(@tv_status)

  'start and setup graphics
  gr.start
  gr.setup(16, 12, 128, 96, bitmap_base)



''**********************************************************
''  color palettes
''********************************************************** 

  'browns and yellows
  SetColorPalette(0,$02,$9d,$9e,$9b)
  SetColorPalette(1,$02,$9e,$9d,$9b)
  SetColorPalette(2,$02,$9d,$9e,$9b)
  SetColorPalette(3,$02,$9d,$9e,$9b)
  SetColorPalette(4,$02,$9b,$9b,$9e)         
  SetColorPalette(5,$02,$9b,$9e,$9b)      

  'blues and purples 
  SetColorPalette(6,$02,$3c,$b8,$eb)
  SetColorPalette(7,$02,$b8,$3c,$eb)
  SetColorPalette(8,$02,$3c,$b8,$eb)
  SetColorPalette(9,$02,$3c,$b8,$eb)
  SetColorPalette(10,$02,$eb,$eb,$b8)         
  SetColorPalette(11,$02,$eb,$b8,$eb) 

  'purple pink white
  SetColorPalette(12,$02,$dd,$ed,$3e)
  SetColorPalette(13,$02,$ed,$dd,$3e)
  SetColorPalette(14,$02,$dd,$ed,$3e)
  SetColorPalette(15,$02,$dd,$ed,$3e)
  SetColorPalette(16,$02,$3e,$dd,$ed)         
  SetColorPalette(17,$02,$3e,$ed,$dd)


  'cycling light blues and greens
  SetColorPalette(18,$02,$4e,$3e,$6e)
  SetColorPalette(19,$02,$3e,$4e,$6e)
  SetColorPalette(20,$02,$4e,$3e,$6e)
  SetColorPalette(21,$02,$4e,$3e,$6e)
  SetColorPalette(22,$02,$6e,$3e,$4e)         
  SetColorPalette(23,$02,$6e,$4e,$3e)


  'cylcing orange and greens
  SetColorPalette(24,$02,$5c,$8e,$ad)
  SetColorPalette(25,$02,$8e,$5c,$ad)
  SetColorPalette(26,$02,$5c,$8e,$ad)
  SetColorPalette(27,$02,$5c,$8e,$ad)
  SetColorPalette(28,$02,$ad,$5c,$8e)         
  SetColorPalette(29,$02,$ad,$8e,$5c)  



  
  'start a new delay counter
  delayflag:=0
  cognew(delay(@delayflag, 8), @delayStack) 


  'keeping full screen tile out of repeat/reg draws helps prevent strobing
  SetAreaColor(0,0,TV_HC-1,TV_VC-1,15)  

  repeat  

''**********************************************************
''  retrieve ADC L and R values, build pixel scalars
 
    rightADCavg := adc.average(0,35)
    leftADCavg := adc.average (1,35)

    scalar_r := (rightADCavg*16/4096)  
    scalar_l := (leftADCavg*16/4096)
    scalar_bigd :=((scalar_r)*2/5) +16

    totalavg:=(scalar_r+scalar_l)/2


''**********************************************************
''  change the color and shape?

    if totalavg > 4
      if delayflag==1
        i++
        if i>29
          i:=0
        SetAreaColor(0,0,TV_HC-1,TV_VC-1,i)
        delayflag:=0

        'if changedisplay==0
         ' changedisplay:=randomgen(4)
          displayroutine:=randomgen(8)-1 
        'else
         ' changedisplay--
    
        cognew(delay(@delayflag, 0), @delayStack)
          



''**********************************************************
''  change the shape?

    if j//9== 0
      rotateflag := !rotateflag
     

        
''**********************************************************
''  draw L+R with simple shapes and colors

    gr.clear
    'displayroutine:=1

    case displayroutine
        0:
          '9 keep (0 with mults)
          if j//2== 0
            changebit := !changebit
           
          gr.width(scalar_r+16)
          if changebit==0
           gr.pix(0, 0, 0, @pixdeftriclear2a)
          else
           gr.pix(0, 0, 0, @pixdeftriclear2b) 
           
          gr.width(scalar_l+16) 
          gr.pix(0, 0, 0, @pixdefsmall1)

          if totalavg <> 0
            gr.width((totalavg)/2+16)
            gr.pix(-90, 0, 0, @pixdeftriclear3) 
            gr.pix(90, 0, 0, @pixdeftriclear3) 



        1: '7 maybe
          if j//2== 0
            changebit := !changebit
           
            gr.width(scalar_l+16)
            gr.pix(0, 0, 1, @pixdefsmall2)                                           
           
          else
            gr.width(scalar_bigd)                                                    
           
          gr.width(scalar_r+16)
          if changebit==0
             gr.pix(0, 0, 0, @pixdeftriclear2a)
          else
             gr.pix(0, 0, 0, @pixdeftriclear2b)
           
          gr.width(scalar_l+16)
          gr.pix(0, 0, 0, @pixdefsmall1)



        2: '8 keep
          if j//2== 0
            changebit := !changebit
           
            gr.width(scalar_l)
            gr.pix(0, 0, 1, @pixdefsmall1)                                           
           
          else
            gr.width(scalar_bigd)                                                    
           
          gr.width(scalar_r)
          if changebit==0
             gr.pix(0, 0, 0, @pixdeftriclear2a)
          else
             gr.pix(0, 0, 0, @pixdeftriclear2b)
           
          gr.width(scalar_l)
          gr.pix(0, 0, 0, @pixdefsmall1)
           

 
        3:   '7 maybe  single lined sq, combine?
        'stripes
         gr.width(scalar_l+16)  
         gr.pix(0, 0, 0, @pixdeftriclear1)
         
         gr.width(scalar_r+16)  
         if rotateflag
           gr.pix(0, 0, 0, @pixdeftriclear2a)
         else 
           gr.pix(0, 0, 1, @pixdeftriclear2b) 


        4:     '9 nice  
          'multiples2
          'do middle
          gr.width(scalar_r+16) 
          gr.pix(0, 0, 0, @pixdeftriclear2)
           
          gr.width(scalar_l+16)  
          gr.pix(0, 0, 0, @pixdeftriclear1)
           
          'do sides
          if totalavg <> 0
            gr.width((totalavg)/2+16)
            gr.pix(-90, 0, 0, @pixdeftriclear3) 
            gr.pix(90, 0, 0, @pixdeftriclear3) 
            gr.pix(0, 90, 0, @pixdeftriclear3)
            gr.pix(0, -90, 0, @pixdeftriclear3)

              
        5:  '9keep
          'multiples4
          'do middle
          gr.width(scalar_r+16) 
          gr.pix(0, 0, 0, @pixdeftriclear2)
           
          gr.width(scalar_l+16)  
          gr.pix(0, 0, 0, @pixdeftriclear1)
           
          'do sides
          if totalavg <> 0
            gr.width((totalavg)/2+16)     
            gr.pix(-90, -90, 0, @pixdeftriclear2)
            gr.pix(-90, 0, 0, @pixdeftriclear3) 
            gr.pix(90, 90, 0, @pixdeftriclear2)
            gr.pix(90, 0, 0, @pixdeftriclear3) 
            gr.pix(-90, 90, 0, @pixdeftriclear2)
            gr.pix(0, 90, 0, @pixdeftriclear3)
            gr.pix(90, -90, 0, @pixdeftriclear2)
            gr.pix(0, -90, 0, @pixdeftriclear3)        

        6:    '7 maybe
          'multiples5
          'do middle
          gr.width(scalar_r+16) 
          gr.pix(0, 0, 0, @pixdeftriclear2)
           
          gr.width(scalar_l+16)  
          gr.pix(0, 0, 0, @pixdeftriclear1)
           
          'do sides
          if totalavg <> 0
            gr.width((totalavg)/2)
            gr.pix(0, 90, 0, @pixdeftriclear3)
            gr.pix(0, -90, 0, @pixdeftriclear3)        


        7:   '8 insteasd of 14?
          'multiples7
          'do middle
          gr.width(scalar_l)  
          gr.pix(0, 0, 0, @pixdeftriclear1)
          
          gr.width(scalar_r+16) 
          gr.pix(0, 0, 0, @pixdeftriclear2)
           
          'do sides
          if totalavg <> 0
            gr.width((totalavg)/2+16)
            gr.pix(-90, 0, 0, @pixdeftriclear2) 
            gr.pix(90, 0, 0, @pixdeftriclear2)
            gr.width((totalavg)/8) 
            gr.pix(0, 90, 0, @pixdeftriclear3)
            gr.pix(0, -90, 0, @pixdeftriclear3)
 
    'update screen bitmap
    gr.copy(display_base)

    if j ==16
      j:=0
    else
      j++    
     
    lastscalar := scalar_r

    
 
Pub SetAreaColor(X1,Y1,X2,Y2,ColorIndex)|DX,DY
  Repeat DX from X1 to X2
    Repeat DY from Y1 to Y2
      SetTileColor(DX,DY,ColorIndex)
   
Pub SetTileColor( x, y, ColorIndex)
   screen[y * tv_hc + x] := display_base >> 6 + y + x * tv_vc + ((ColorIndex & $3F) << 10)
 
Pub SetColorPalette(ColorIndex,Color1,Color2,Color3,Color4)
  colors[ColorIndex] := (Color1) + (Color2 << 8) +  (Color3 << 16) + (Color4 << 24)

pub delay (delayflagAddr, mult)
    if mult==0   '0 = choose a random number b/w 0 and 31
      mult:=randomgen(32)
      waitcnt(DELAYUNIT*mult + cnt)
      
    else         'multiply by a multiplier
      waitcnt(DELAYUNIT*mult + cnt)

    byte[delayflagAddr]:=1



pub randomgen (sigdigs):output | mask, var1
      if sigdigs==32
        mask:= %0000000000011111
      elseif sigdigs==16 
        mask:= %0000000000001111
      elseif sigdigs==8
        mask:= %0000000000000111
      else                      
        mask:= %0000000000000011
        
      var1:=(((cnt?) &  mask) + 1)

      if var1==lastrand
        var1:=(((cnt?) &  mask) + 1)  

      lastrand:=var1
      output:=var1
   

DAT

tvparams                long    0               'status
                        long    1               'enable
                        long    %001_0101       'pins
                        long    %0000           'mode
                        long    0               'screen
                        long    0               'colors
                        long    x_tiles         'hc
                        long    y_tiles         'vc
                        long    10              'hx
                        long    1               'vx
                        long    0               'ho
                        long    0               'vo
                        long    0               'broadcast
                        long    0               'auralcog

pixdeftriclear1         word                            
                        byte    2,16,8,8
                        word    %%00000001, %%10000000
                        word    %%00000011, %%11000000
                        word    %%00000111, %%11100000
                        word    %%00001111, %%11110000
                        word    %%00011111, %%11111000
                        word    %%00111111, %%11111100
                        word    %%01111111, %%11111110
                        word    %%11111111, %%11111111
                        word    %%01111111, %%11111110
                        word    %%00111111, %%11111100
                        word    %%00011111, %%11111000
                        word    %%00001111, %%11110000
                        word    %%00000111, %%11100000
                        word    %%00000011, %%11000000
                        word    %%00000001, %%10000000
                        word    %%00000000, %%00000000                     

pixdeftriclear2         word                            
                        byte    2,16,8,8
                        word    %%00000002, %%20000000
                        word    %%00000022, %%22000000
                        word    %%00000222, %%22200000
                        word    %%00002222, %%22220000
                        word    %%00022222, %%22222000
                        word    %%00222222, %%22222200
                        word    %%02222222, %%22222220
                        word    %%22222222, %%22222222
                        word    %%02222222, %%22222220
                        word    %%00222222, %%22222200
                        word    %%00022222, %%22222000
                        word    %%00002222, %%22220000
                        word    %%00000222, %%22200000
                        word    %%00000022, %%22000000
                        word    %%00000002, %%20000000
                        word    %%00000000, %%00000000 


pixdeftriclear3         word                            
                        byte    2,16,8,8
                        word    %%00000003, %%30000000
                        word    %%00000033, %%33000000
                        word    %%00000333, %%33300000
                        word    %%00003333, %%33330000
                        word    %%00033333, %%33333000
                        word    %%00333333, %%33333300
                        word    %%03333333, %%33333330
                        word    %%33333333, %%33333333
                        word    %%03333333, %%33333330
                        word    %%00333333, %%33333300
                        word    %%00033333, %%33333000
                        word    %%00003333, %%33330000
                        word    %%00000333, %%33300000
                        word    %%00000033, %%33000000
                        word    %%00000003, %%30000000
                        word    %%00000000, %%00000000 


pixdeftriclear2a         word                            
                        byte    2,16,8,8
                        word    %%00000000, %%00000000
                        word    %%00000022, %%22000000
                        word    %%00000000, %%00000000
                        word    %%00002222, %%22220000
                        word    %%00000000, %%00000000
                        word    %%00222222, %%22222200
                        word    %%00000000, %%00000000
                        word    %%22222222, %%22222222
                        word    %%00000000, %%00000000
                        word    %%00222222, %%22222200
                        word    %%00000000, %%00000000
                        word    %%00002222, %%22220000
                        word    %%00000000, %%00000000
                        word    %%00000022, %%22000000
                        word    %%00000000, %%00000000
                        word    %%00000000, %%00000000
                        
pixdeftriclear2b         word                            
                        byte    2,16,8,8
                        word    %%00000002, %%20000000
                        word    %%00000000, %%00000000
                        word    %%00000222, %%22200000
                        word    %%00000000, %%00000000
                        word    %%00022222, %%22222000
                        word    %%00000000, %%00000000
                        word    %%02222222, %%22222220
                        word    %%00000000, %%00000000
                        word    %%02222222, %%22222220
                        word    %%00000000, %%00000000
                        word    %%00022222, %%22222000
                        word    %%00000000, %%00000000
                        word    %%00000222, %%22200000
                        word    %%00000000, %%00000000
                        word    %%00000002, %%20000000
                        word    %%00000000, %%00000000 





pixdeftri2              word                            
                        byte    2,16,8,8
                        word    %%00000001, %%10000000
                        word    %%00000011, %%11000000
                        word    %%00000111, %%11100000
                        word    %%00001112, %%21110000
                        word    %%00011122, %%22111000
                        word    %%00111222, %%22211100
                        word    %%01112223, %%32221110
                        word    %%11122233, %%33222111
                        word    %%01112233, %%33221110
                        word    %%00111223, %%32211100
                        word    %%00011122, %%22111000
                        word    %%00001112, %%21110000
                        word    %%00000111, %%11100000
                        word    %%00000011, %%11000000
                        word    %%00000001, %%10000000
                        word    %%00000000, %%00000000



{
pixdefbigd2             word                            
                        byte    4,32,16,16
                        word    %%00000000,%%00000000,%%00000000,%%00000000
                        word    %%00000000,%%00000002,%%20000000,%%00000000
                        word    %%00000000,%%00000022,%%22000000,%%00000000
                        word    %%00000000,%%00000222,%%22200000,%%00000000
                        word    %%00000000,%%00002222,%%22220000,%%00000000
                        word    %%00000000,%%00022222,%%22222000,%%00000000
                        word    %%00000000,%%00222222,%%22222200,%%00000000
                        word    %%00000000,%%02222222,%%22222220,%%00000000
                        word    %%00000000,%%22222222,%%22222222,%%00000000
                        word    %%00000002,%%22222222,%%22222222,%%20000000
                        word    %%00000022,%%22222222,%%22222222,%%22000000
                        word    %%00000222,%%22222222,%%22222222,%%22200000
                        word    %%00002222,%%22222222,%%22222222,%%22220000
                        word    %%00022222,%%22222222,%%22222222,%%22222000
                        word    %%00222222,%%22222222,%%22222222,%%22222200
                        word    %%02222222,%%22222222,%%22222222,%%22222220
                        word    %%22222222,%%22222222,%%22222222,%%22222220
                        word    %%02222222,%%22222222,%%22222222,%%22222200
                        word    %%00222222,%%22222222,%%22222222,%%22222000
                        word    %%00022222,%%22222222,%%22222222,%%22220000
                        word    %%00002222,%%22222222,%%22222222,%%22200000
                        word    %%00000222,%%22222222,%%22222222,%%22000000
                        word    %%00000022,%%22222222,%%22222222,%%20000000
                        word    %%00000002,%%22222222,%%22222222,%%00000000
                        word    %%00000000,%%22222222,%%22222220,%%00000000
                        word    %%00000000,%%02222222,%%22222200,%%00000000
                        word    %%00000000,%%00222222,%%22222000,%%00000000
                        word    %%00000000,%%00022222,%%22220000,%%00000000
                        word    %%00000000,%%00002222,%%22200000,%%00000000
                        word    %%00000000,%%00000222,%%22000000,%%00000000
                        word    %%00000000,%%00000022,%%20000000,%%00000000
                        word    %%00000000,%%00000002,%%00000000,%%00000000


}

'keep
pixdefmed2              word                            
                        byte    2,16,8,8
                        word    %%00000000, %%00000000
                        word    %%00000000, %%00000000
                        word    %%00000002, %%20000000 
                        word    %%00000022, %%22000000
                        word    %%00002222, %%22220000
                        word    %%00022222, %%22222000
                        word    %%02222222, %%22222220
                        word    %%22222222, %%22222222
                        word    %%02222222, %%22222220
                        word    %%00022222, %%22222000
                        word    %%00002222, %%22220000
                        word    %%00000022, %%22000000
                        word    %%00000002, %%20000000
                        word    %%00000000, %%00000000
                        word    %%00000000, %%00000000
                        word    %%00000000, %%00000000                     



'keep 
pixdefsmall1            word                            
                        byte    2,16,8,8
                        word    %%00000000, %%00000000
                        word    %%00000000, %%00000000
                        word    %%00000000, %%00000000 
                        word    %%00000001, %%10000000
                        word    %%00000011, %%11000000
                        word    %%00000111, %%11100000
                        word    %%00011111, %%11111000
                        word    %%11111111, %%11111111
                        word    %%00011111, %%11111000
                        word    %%00000111, %%11100000
                        word    %%00000011, %%11000000
                        word    %%00000001, %%10000000
                        word    %%00000000, %%00000000
                        word    %%00000000, %%00000000
                        word    %%00000000, %%00000000
                        word    %%00000000, %%00000000    

pixdefsmall2            word                            
                        byte    2,16,8,8
                        word    %%00000000, %%00000000
                        word    %%00000000, %%00000000
                        word    %%00000000, %%00000000 
                        word    %%00000002, %%20000000
                        word    %%00000022, %%22000000
                        word    %%00000222, %%22200000
                        word    %%00022222, %%22222000
                        word    %%22222222, %%22222222
                        word    %%00022222, %%22222000
                        word    %%00000222, %%22200000
                        word    %%00000022, %%22000000
                        word    %%00000002, %%20000000
                        word    %%00000000, %%00000000
                        word    %%00000000, %%00000000
                        word    %%00000000, %%00000000
                        word    %%00000000, %%00000000 







                         