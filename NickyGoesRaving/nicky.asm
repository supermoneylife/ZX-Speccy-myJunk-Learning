    ;Spectrum screen size 256 pixels wide x 192 scan lines
	; 32 x 24 Characters

    ; keyboard ports:
    ; todo fill in the rest.
    ; f7fe 12345
    ; fbfe qwert
    ; fdfe asdfg
    ; fefe shift/z/x/c/v

ENTRY_POINT equ 32768
    org ENTRY_POINT

    call 0xdaf ;clear screen, open ch2
    xor a ;set 0 to zero (border color choice)
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

    halt ;second halt instruction, wait until the scanlines finish again before redrawing player (PRO-helps with flicker / CON-game now running @ 25fps)
    
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

    halt ;third halt. Now running at 17fps !! 
    
    ;update player
    ld ix,playerdata ;ix points at player properties
    call deletesprite
    ld a,(ix+5) ;get animstate
    ;decide which idle animstate to default to
    call setidlenohat
    cp 3 ;3=idle with hat
    call z, setidlehat
    call checkkeys ;checks for WASD and moves player if pressed (also changes players animstate value)
    call drawsprite ;draw sprite in HL

    ;drawshop
    ld ix,shopdata
    call deletesprite
    ld hl,hatshop
    call drawsprite

    jp main

setidlenohat:
    ld hl,idle_nohat
    ret
setidlehat:
    ld hl,idle_hat
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

moveup:
    ld a,(ix+2) ;load ypos to a
    cp 0 ;if a==0...
    ret z ;...return
    sub (ix+6) ;otherwise subtract speed value from a
    ld (ix+2),a ;set the new value
    ld a,1 ;load a with 1 (anim code for up)
    ld (ix+5),a ;set anim state in player data
    call setcorrectplayerbitmap ;points HL at different player sprite bitmap data, depending on current animstate
    ret
movedown:
    ld a,(ix+2) ;load ypos to a
    cp MAX_Y
    ret nc 
    add a,(ix+6) ;add speed
    ld (ix+2),a ;set new ypos value
    ld a,2 ;load a with (anim code for down)
    ld (ix+5),a ;set anim state in player data
    call setcorrectplayerbitmap ;points HL at different player sprite bitmap data, depending on current animstate
    ret
moveleft:
    ld a,(ix+1) ;load xpos to a
    cp 0 ;if a==0...
    ret z ;...return
    sub (ix+6) ;otherwise subtract speed value from a
    ld (ix+1),a ;set the new value
    ; not changing animstate here, but still must call to set bitmap
    call setcorrectplayerbitmap ;points HL at different player sprite bitmap data, depending on current animstate
    ret
moveright:
    ld a,(ix+1) ;load ypos to a
    cp MAX_X
    ret nc 
    add a,(ix+6) ;add speed
    ld (ix+1),a ;set new xpos value
    ; not changing animstate here, but still must call to set bitmap
    call setcorrectplayerbitmap ;points HL at different player sprite bitmap data, depending on current animstate
    ret


;function points HL to the player sprite, depending on which anim state he is in
;Inputs:
;IX=player
;Outputs:
;HL=first frame in correct anim sequence.
setcorrectplayerbitmap:
    ld a,(ix+7) ;get hat bool into a
    cp 0 ;compare 0
    call nz,switchtohatstate ;if !=0 switch to hat sprite (3 higher in index)

    ld a,(ix+5);
    ;; NOT NEEDED TO CHECK 0 or (idles) checked earlier
    ; ld a,(ix+5) ;ld current animstate key into a
    ; cp 0 ;is it idle (no hat)?
    ; ld hl,idle_nohat
    ; ret z
    cp 1 ;is it up (no hat)?
    ld hl,up_nohat
    ret z
    cp 2 ;is it down (no hat)?
    ld hl,down_nohat
    ret z
    ;; again cp 3 not needed
    cp 4 ;is it up (with hat)?
    ld hl,up_hat
    ret z
    cp 5 ;is it down (with hat)?
    ld hl,down_hat
    ret z
    ;; TODO: cp 6 (dancing?)
    ret

switchtohatstate:
    ld a,(ix+5);get animstate
    cp 1 ;if animstate is 1-3 , then add 3 (which gives you the hat version)
    add a,3
    cp 2
    add a,3
    cp 3
    add a,3
    ld (ix+5),a ;set the value
    ret

;DATA BEGINS
; NOTE: Due to the coding for movement .The 'speed' property must be the 7th data byte on all moving objects

;map-data:
;lanes y constants:
U1 equ 24
U2 equ 44
U3 equ 64
LANE_DIVIDE equ 84
L1 equ 88
L2 equ 108
L3 equ 128
MAX_X equ 255-28 ;rightside boundary for player (screenwidth-playerwidth-speed)
MAX_Y equ 192-28 ;bottom boundary for player (screenheight-playerheight-speed)


;note: for moving sprites , data bytes 1-7 must be laid out in order as notes
; if not a moving sprite, bytes 1-5 must be laid out in order.

;hatshop data:
shopdata    db 1,(256/2)-16,192-16,4,16

;player data format:
;0 isAlive (bool) 1=alive
;1 x
;2 y
;3 sizex (cells)
;4 sizey (lines)
;5 anim state (0=idle,1=up,2=down,3=idle hat,4=up hat,5=down hat,6=down dancing)
;6 move speed
;7 has a hat? (bool) 0=no hat
playerdata  db 1,0,0,3,24,0,8,0


;;player data format:
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
