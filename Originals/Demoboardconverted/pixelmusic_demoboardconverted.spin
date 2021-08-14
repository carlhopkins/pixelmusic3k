{
''*******************************************************************************      
''*     Pixelmusic 3000                                                         *
''*                                                                             *
''*     Copyright 2008 Uncommon Projects                                        *
''*     pm3k@uncommonprojects.com                                               *
''*                                                                             *
''*     This program is free software: you can redistribute it and/or modify    *
''*     it under the terms of the GNU General Public License as published by    *
''*     the Free Software Foundation, either version 3 of the License, or       *
''*     (at your option) any later version.                                     *
''*                                                                             *
''*     This program is distributed in the hope that it will be useful,         *
''*     but WITHOUT ANY WARRANTY; without even the implied warranty of          *
''*     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the           *
''*     GNU General Public License for more details.                            *
''*                                                                             *
''*     You should have received a copy of the GNU General Public License       *
''*     along with this program.  If not, see <http://www.gnu.org/licenses/>.   *
''*                                                                             *
''*******************************************************************************
}


CON


  _clkmode = xtal1 + pll16x     'set clock speed to 80 MHz  (16 x external crytsal 5_000_000Hz) 
  _xinfreq = 5_000_000
  _stack = ($3000 + $3000 + 100) >> 2   'accomodate display memory and stack

  x_tiles = 16
  y_tiles = 12

  paramcount = 14       
  bitmap_base = $2000
  display_base = $5000


  'can increase or decrease this number to make more or less time between color or shape changes
  DELAYUNIT = 10_000_000 '1/8 of a sec
  bits = 11

  
VAR

  'set the tv object variables...
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


  long delayStack[32]           'a stack of longs used by delay routine    
  byte lastrand
  byte delayflag
  LONG  adcval
  

OBJ
  'we use the propeller's included tv, graphics and mcp3208/adc objects
  tv            : "tv"
  gr            : "graphics"



  
PUB start | i, j, scalar_r, scalar_l, scalar_bigd, lastscalar, rightADCavg, leftADCavg, totalavg, rotateflag, changebit, changedisplay, displayroutine

  'turn on the external LED
  dira[16]~~
  outa[16]~~


  'start the adc object
  'start tv object
  longmove(@tv_status, @tvparams, paramcount)
  tv_screen := @screen
  tv_colors := @colors
  tv.start(@tv_status)

  'start and setup graphics object
  gr.start
  gr.setup(16, 12, 128, 96, bitmap_base)
'  mouse.start(24, 25)




''*******************************************************************************  
''  COLOR PALETTES
''  These are the colors that the PM3K will cycle through
''  We only use 4 colors onscreen at a time and one color is always black
''  To get more color variety, we create different palettes and combos of colors
''  Each palette group has a slight variation in the order or hue of the colors
''  This is exploited by the shapes which also arrange the color bits with variation
''  You can use 'Graphics_Palette.spin' in the Example Library if you would like to pick different color values
''*******************************************************************************  


  'browns and yellows
  SetColorPalette(0,$02,$ac,$18,$ab)
  SetColorPalette(1,$02,$18,$9e,$ab)
  SetColorPalette(2,$02,$bb,$18,$9b) 
  SetColorPalette(3,$02,$18,$ac,$ab)
  SetColorPalette(4,$02,$ab,$ac,$18)         
  SetColorPalette(5,$02,$ac,$18,$9b)

  'blues and purples 
  SetColorPalette(6,$02,$3c,$b8,$eb)
  SetColorPalette(7,$02,$0c,$5e,$fb)   
  SetColorPalette(8,$02,$b8,$3c,$eb)
  SetColorPalette(9,$02,$b8,$5d,$88)
  SetColorPalette(10,$02,$eb,$3c,$5d)         
  SetColorPalette(11,$02,$b8,$eb,$88) 

  'purple pink white
  SetColorPalette(12,$02,$58,$88,$3e)
  SetColorPalette(13,$02,$ed,$dd,$3e)
  SetColorPalette(14,$02,$cc,$ed,$b8)
  SetColorPalette(15,$02,$58,$88,$3e)
  SetColorPalette(16,$02,$68,$cc,$4d)         
  SetColorPalette(17,$02,$3e,$b8,$58)

  'light blues and greens
  SetColorPalette(18,$02,$5e,$3d,$f8)
  SetColorPalette(19,$02,$3d,$5e,$f8)
  SetColorPalette(20,$02,$6d,$3e,$6e)
  SetColorPalette(21,$02,$5e,$4e,$f8)
  SetColorPalette(22,$02,$6e,$3d,$4e)         
  SetColorPalette(23,$02,$f8,$6e,$3e)

  'orange and greens
  SetColorPalette(24,$02,$8d,$8e,$38)
  SetColorPalette(25,$02,$8e,$8d,$28)
  SetColorPalette(26,$02,$5c,$8e,$ad)
  SetColorPalette(27,$02,$7c,$7e,$5c)
  SetColorPalette(28,$02,$5c,$8d,$38)         
  SetColorPalette(29,$02,$28,$8e,$5c)  
  


  
  'start a new delay counter in its own cog
  delayflag:=0
  cognew(delay(@delayflag, 8), @delayStack) 
  cognew(@asm_entry,@adcval)

  'the screen is made of 16 horizontal x 12 vertical tiles (groups of pixels)
  'while each tile can have its own color palette, we set a color palette to apply globally across all screen tiles
  SetAreaColor(0,0,TV_HC-1,TV_VC-1,15)  
  repeat  'main loop  

''*******************************************************************************  
''  retrieve ADC L and R values, build pixel scalar values
 
    rightADCavg := adcval +2 'right channel volume/voltage               
    leftADCavg := adcval +10 'left channel volume/voltage

    scalar_r := (adcval/8) 'we're massaging the number into something applicable to the shapes  
    scalar_l := (adcval/8)
    scalar_bigd :=((scalar_r)*2/5) +16

    totalavg:=(scalar_r+scalar_l)/2 'we will use totalavg to help make sure not to change anything if no input


''*******************************************************************************  
''  change the color and shape?

    if totalavg > 4 'if we're getting some adc values
      if delayflag==1 'and the random time delay has elapsed (to make sure we aren't changing too fast)
        i++
        if i>29
          i:=0
        SetAreaColor(0,0,TV_HC-1,TV_VC-1,i) 'pick a new color palette
        delayflag:=0

        if changedisplay==0  'this whole changedisplay routine just changes screen patterns a little less frequently than color
          changedisplay:=randomgen(2) 'try randomgen(4) for slower layout changes or no ranomgen delay for frequent changes with color 
          displayroutine:=randomgen(8)-1 'randomly pick one of 8 screen patterns 
        else
          changedisplay--
    
        cognew(delay(@delayflag, 0), @delayStack)


''*******************************************************************************  
''  change the orientation? some of the screen patterns have alternating rotations

    if j//9== 0
      rotateflag := !rotateflag

''*******************************************************************************  
''  Translate L+R inputs to simple shapes and colors
''  PM3K has 8 total screen pattern/arrangements of shapes onscreen
''  We cycle through these patterns randomly when there have been adc level changes and a certain amount of time has passed
''  The shapes in the layout are grown or shrunk based in the ADC values
''  To see what a particular screen pattern looks like just hardcode the displayroutine var to a number between 0 and 7

   'displayroutine:=1

   
    gr.clear
    

    case displayroutine
        0:
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



        1: 
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



        2: 
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
           

 
        3:   
        'stripes
         gr.width(scalar_l+16)  
         gr.pix(0, 0, 0, @pixdeftriclear1)
         
         gr.width(scalar_r+16)  
         if rotateflag
           gr.pix(0, 0, 0, @pixdeftriclear2a)
         else 
           gr.pix(0, 0, 1, @pixdeftriclear2b) 


        4:       
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

              
        5: 
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

        6:    
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


        7:   
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

    
''*******************************************************************************      
'thanks to Jim Fouch in the parallax forums for these 3 screen color pubs
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


''*******************************************************************************  
pub randomgen (sigdigs):output | mask, var1
      if sigdigs==32
        mask:= %0000000000011111
      elseif sigdigs==16 
        mask:= %0000000000001111
      elseif sigdigs==8
        mask:= %0000000000000111
      elseif sigdigs==4                     
        mask:= %0000000000000011
      else                    
        mask:= %0000000000000001  
        
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
              org

asm_entry     mov       dira,asm_dira                   'make pins 8 (ADC) and 0 (DAC) outputs

              movs      ctra,#8                         'POS W/FEEDBACK mode for CTRA
              movd      ctra,#9
              movi      ctra,#%01001_000
              mov       frqa,#1

              mov       asm_cnt,cnt                     'prepare for WAITCNT loop
              add       asm_cnt,asm_cycles

              
:loop         waitcnt   asm_cnt,asm_cycles              'wait for next CNT value (timing is determinant after WAITCNT)

              mov       asm_sample,phsa                 'capture PHSA and get difference
              sub       asm_sample,asm_old
              add       asm_old,asm_sample
                                                         
              WRlong    asm_sample,par
    
              jmp       #:loop                          'wait for next sample period

asm_cycles    long      100                     'sample time
asm_dira      long      $00000E00                       'output mask

asm_cnt       res       1
asm_old       res       1
asm_sample    res       1


 







                         