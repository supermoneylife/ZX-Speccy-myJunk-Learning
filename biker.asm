; ASM data file from a ZX-Paintbrush picture with 16 x 16 pixels (= 2 x 2 characters)

; line based output of pixel data:
bikerx  db 0
bikery  db 32
bikerspeed EQU 8

biker:
db %00000011, %11000000
db %00000111, %11100000
db %00000110, %00000000
db %00000111, %11100000
db %00001011, %11000000
db %00000110, %01000000
db %00001111, %00010100
db %11001111, %11111100
;
db %01111111, %11111000
db %00111111, %11111000
db %01111111, %11111100
db %11011111, %11110110
db %10111111, %11101010
db %10101011, %00101010
db %11011001, %10110110
db %01110000, %00011100
