    ;Spectrum screen size 256 pixels wide x 192 scan lines
	; 32 x 24 Characters

    ; keyboard ports:
    ; todo fill in the rest.
    ; f7fe 12345
    ; fbfe qwert
    ; fdfe asdfg
    ; fefe shift/z/x/c/v

;NOTE: all player animation states must have exactly 2 frames each

ENTRY_POINT equ 32768
    org ENTRY_POINT

    call 0xdaf ;clear screen, open ch2
    ld a,1 ;choose border colour
    call 0x229b ;set border color with chosen value
main:
    halt ;wait for interrupt (ie. wait until the tv linescan has just completed -happens at 50hz) -locks game to 50fps

   
    ;loop all upper cars and update them
    ld b,UP_CARS_MAX
    ld ix, up_carsdata
    call delcarsloop
    ld b,UP_CARS_MAX    
    ld ix, up_carsdata
    call movecarsloop
    ld b,UP_CARS_MAX
    ld ix, up_carsdata
    ld hl,saloon_r ;todo: come up with a way to make car variant random
    call drawcarsloop

    ;second halt instruction, wait until the scanlines finish again before redrawing player
    ;(PRO-helps with flicker / CON-game now running @ 25fps)
    halt 

    ;loop all lower cars and update them
    ld b,LO_CARS_MAX
    ld ix, lo_carsdata
    call delcarsloop
    ld b,LO_CARS_MAX    
    ld ix, lo_carsdata
    call movecarsloop
    ld b,LO_CARS_MAX
    ld ix, lo_carsdata
    ld hl,saloon_l ;todo: come up with a way to make car variant random
    call drawcarsloop

    
    halt ;third halt. game will run @ 17fps !! 

    ;delete player
    ld ix,playerdata ;ix points at player properties
    call deletesprite
    ;check keys and move if pressed
    call checkkeys ;checks for WASD and moves player if pressed (also changes players animstate value)
    call setcorrectplayerbitmap ;sets hl to first bitmap in each animstate
    ;cycle animation frames
    ld a,(ix+9) ;a=animtimer
    inc a ;increment animTimer
    ld (ix+9),a ;set new value to timer
    cp ANIM_FRAME_LENGTH_TIME
    call nc,gonextanimframe
    call addanimationoffset
    ;draw correct frame
    call drawsprite ;draw sprite in HL
    

    ;ix is already player data, set iy to shop and check for collision
    ld iy,shopdata
    call checkplayerhatshopcollision
    
    ;draw shop (last so it is on top of all sprites)
    ld ix,shopdata
    call deletesprite
    ld hl,hatshop
    call drawsprite

    ld de,backgroundattributes
    ld hl,22528
    ld c,24 ;total lines of screen characters
    call paintbg

    ld ix,playerdata
    ld de,22528
    call paintplayer

    jp main

;
;DE=bg attributes
;HL=0x5800
;C=24
paintbg:
    ld b,32 ;cells per line
paintlineloop:
    ld a,(de) ;getcolour from DE
    ld (hl),a ;place into attr memory
    inc hl ;inc HL pointer
    djnz paintlineloop ;loop til B=0
gonextline
    inc de ;inc IX pointer to next attribute
    dec c ;next line in counter
    ld a,0
    cp c ;is C==0?
    jr nz, paintbg ;if C!=0, then start loop again
    ret ;otherwise finished.

;ix=player
;de=0x5800
paintplayer:
    ld a,(ix+2) ;get player y
    ld l,a
    add hl,hl
    add hl,hl ;HL= player y cell
    add hl,de ;+= 0x5800
    ld a,(ix+1) ;get player x
    rra
    rra
    rra ;/8
    ld e,a
    ld d,0
    add hl,de ;+= player x cell
    ld a,(ix+11) ;get player colour
    ld (hl),a ;paint the cell
    ret 

;cycles the anim frame index
;inputs
;IX=player
gonextanimframe:
    ld (ix+9),0 ;animTimer=0 
    ld a,(ix+8) ;get current anim frame
    cp ANIM_CYCLE_LENGTH
    jr c, incframe
    jr nc, resettofirstframe  
incframe:
    inc (ix+8) ;increment frame
    jp endgonext
resettofirstframe:
    ld (ix+8),0 ;set frame property to 0
    jp endgonext
endgonext:
    ret  

;adds to hl the value for the current anim frame
addanimationoffset:
    ld a,(ix+8) ;get current anim frame
    cp 0 ;if 0 dont loop at all
    ret z ;return if =0
    ld b,a ;b=current anim frame
addoffsetloop:
    ld de,NICKY_BYTESPERFRAME
    add hl,de ;increase hl by bytesperframe
    djnz addoffsetloop ;loop until b=0
    ret


;loops through all cars and calls movecarsideways on them, if alive
;inputs
;B= max cars (reducing iterator)
;IX=cars data pointer
movecarsloop:
    ld a,(ix);
    cp 1 ;if IX==1...do move
    call z, domove 
    ld de,UP_CARSDATA_LENGTH
    add ix,de
    djnz movecarsloop
    ret
domove:
    call movecarsideways
    ret

;loops through all cars and calls deletesprite on them, if alive
;inputs
;B= max cars (reducing iterator)
;IX=cars data pointer
delcarsloop:
    ld a,(ix) ;A=car[i].isAlive?
    cp 1; compare 1 (is alive)
    call z, dodelete
    ld de,UP_CARSDATA_LENGTH
    add ix,de   
    djnz delcarsloop
    ret
dodelete:
    push bc
    call deletesprite
    pop bc
    ret

;loops through all cars and calls drawsprite on them, if alive
;inputs
;B= max cars (reducing iterator)
;IX=cars data pointer
drawcarsloop:
    ld a,(ix) ;A=car[i].isAlive?
    cp 1; compare 1 (is alive)
    call z, dodraw
    ld de,UP_CARSDATA_LENGTH
    add ix,de
    djnz drawcarsloop
    ret
dodraw:
    push bc
    push hl
    call drawsprite
    pop hl
    pop bc
    ret


; checks state of keys and calls move functions for player
;Inputs:
;IX=object being moved upon keypress
checkkeys:
    ld bc,0xfdfe
    in a, (c) ; reads ports, affects flags, but doesnt store value to a register
    rra  ; outermost bit = key0 = A
    push af
    call nc, moveleft
    pop af
    rra ; outermost bit = key1 = S
    push af
    call nc, movedown
    pop af
    rra ; outermost bit = key2 = D
    push af
    call nc, moveright
    pop af
    ld bc,0xfbfe
    in a, (c)
    rra ; key Q
    push af
    ;call nc, whateverQcando
    pop af
    rra ; key W
    push af
    call nc, moveup
    pop af
    ret

;moves object pointed by IX by it own speed property
;inputs:
;IX=properties of object to move
movecarsideways:
    ld a,(ix+1) ;load xpos to a
    add a,(ix+6) ;add speed
    ld (ix+1),a ;set new xpos value
    ret
;player movement routines
moveup:
    ld a,(ix+2) ;load ypos to a
    cp MIN_Y ;if a>=MINY
    ret c ;...don't move
    sub (ix+6) ;otherwise subtract speed value from a
    ld (ix+2),a ;set the new value
    ld a,(ix+7) ;get hasHat bool
    cp 0 ;doesnt have hat
    call z, setanim1
    cp 1 ;does have hat
    call z, setanim4
    ret
movedown:
    ld a,(ix+2) ;load ypos to a
    cp MAX_Y
    ret nc 
    add a,(ix+6) ;add speed
    ld (ix+2),a ;set new ypos value
    ld a,(ix+7) ;get hasHat bool
    cp 0 ;doesnt have hat
    call z, setanim2
    cp 1 ;does have hat
    call z, setanim5
    ret
moveleft:
    ld a,(ix+1) ;load xpos to a
    cp 0 ;if a==0...
    ret z ;...return
    sub (ix+6) ;otherwise subtract speed value from a
    ld (ix+1),a ;set the new value
    ret
moveright:
    ld a,(ix+1) ;load ypos to a
    cp MAX_X
    ret nc 
    add a,(ix+6) ;add speed
    ld (ix+1),a ;set new xpos value
    ret

;sets the player animstate variable to chosen value
setanim0:
    ld (ix+5),0 ;set anim state to 0
    ret
setanim1:
    ld (ix+5),1 ;set anim state to 1
    ret
setanim2:
    ld (ix+5),2 ;set anim state to 2
    ret
setanim3:
    ld (ix+5),3 ;set anim state to 3
    ret
setanim4:
    ld (ix+5),4 ;set anim state to 4
    ret
setanim5:
    ld (ix+5),5 ;set anim state to 5
    ret   
setanim6:
    ld (ix+5),6 ;set anim state to 6
    ret   
;function points HL to the player sprite, depending on which anim state he is in
;Inputs:
;IX=player
;Outputs:
;HL=first frame in correct anim sequence.
setcorrectplayerbitmap:
    ld a,(ix+5) ;ld current animstate key into a
    cp 0 ;is it idle (no hat)?
    ld hl,idle_nohat
    ret z
    cp 1 ;is it up (no hat)?
    ld hl,up_nohat
    ret z
    cp 2 ;is it down (no hat)?
    ld hl,down_nohat
    ret z
    cp 3
    ld hl,idle_hat
    ret z
    cp 4 ;is it up (with hat)?
    ld hl,up_hat
    ret z
    cp 5 ;is it down (with hat)?
    ld hl,down_hat
    ret z
    ;; TODO: cp 6 (dancing?)
    ret

;INPUTS:
;IX=player
;IY=hatshop
;DESTROYS: a, bc, hl 
checkplayerhatshopcollision:
    ld a,(ix+1) ;A=player x
    add a,(ix+10) ;A=players right edge
    ld l,(iy+1) ;L=shop x
    cp l ;compare A with B
    ret c ;return if player is past the left side
    ld a,(ix+1) ;A=player x
    ld c,(iy+5) ;C=shop width
    add hl,bc ;add shop width to L
    cp l ;compare A with L
    ret nc ;return if player is past the right side
    ld a,(ix+2) ;A=player y
    add a,(ix+4) ;A+=player height
    ld l,(iy+2) ;L=shop y
    cp l ;compare A with L
    ret c ;return if player is above the shop y
    ;if this far, then its a hit....
    ld (ix+7),1 ;set hat bool to 1
    call setanim5 ;set anim to down with hat;
    call setcorrectplayerbitmap ;change the sprite to hatted sprite
    ret
;
;
;


;
;
;
;; DATA BEGINS
; NOTE: Due to the coding for movement .The 'speed' property must be the 7th data byte on all moving objects

;map-data:
;lanes y constants:
U1 equ 28
U2 equ 48
U3 equ 68
LANE_DIVIDE equ 88
L1 equ 92
L2 equ 116
L3 equ 136
MAX_X equ 255-28 ;rightside boundary for player (screenwidth-playerwidth-speed)
MIN_Y equ 0+4 ;upper boundary (0+speed)
MAX_Y equ 192-24 ;bottom boundary for player (screenheight-playerheight-speed)


;note: for moving sprites , data bytes 1-7 must be laid out in order as notes
; if not a moving sprite, bytes 1-5 must be laid out in order.

;hatshop data:
;isalive?,x,y,sizex,sizey,width (pixels)
shopdata    db 1,(256/2)-16,192-16,4,16,32

;player data format:
;0 isAlive (bool) 1=alive
;1 x
;2 y
;3 sizex (cells)
;4 sizey (lines)
;5 anim state (0=idle,1=up,2=down,3=idle hat,4=up hat,5=down hat,6=down dancing)
;6 move speed
;7 has a hat? (bool) 0=no hat
;8 current anim frame
;9 animtimer
;10 width (pixels)
;11 colour attribute
playerdata  db 1,120,0,3,24,0,4,0,0,0,24,4



;;car data format:
;isAlive
;x
;y
;sizex (cells)
;sizey (lines)
;variant(0=bike,1=car,2=lorry)
;speed
UP_CARS_MAX equ 5
UP_CARSDATA_LENGTH equ 7
up_carsdata
    db 1,0,U1,3,16,1,4
    db 1,0,U2,3,16,1,8
    db 1,0,U3,3,16,1,2
    db 0,0,0,3,16,1,2
    db 0,0,0,3,16,1,2
LO_CARS_MAX equ 5
LO_CARSDATA_LENGTH equ 7
lo_carsdata
    db 1,0,L1,3,16,1,-4
    db 1,0,L2,3,16,1,-8
    db 1,0,L3,3,16,1,-2
    db 0,0,0,3,16,1,-2
    db 0,0,0,3,16,1,-2

include "sprites/cars/carsprites.asm"
include "sprites/player/nickysprite.asm"
include "sprites/map/mapsprites.asm"
include "util/screentools.asm"
include "util/spritetools.asm"

    end ENTRY_POINT
