; LCD_test_4bit.asm: Initializes and uses an LCD in 4-bit mode
; using the most common procedure found on the internet.
$NOLIST
$MODLP51
$LIST

TEMP_SOAK_BUTTON 	equ P0.0
TIME_SOAK_BUTTON 	equ P0.2
TEMP_REFL_BUTTON    equ P0.4
TIME_REFL_BUTTON 	equ P0.7


org 0000H
    ljmp loop
		
DSEG at 0x30
	temp_soak: 		ds 1
	time_soak: 		ds 1
	temp_refl: 		ds 1
	time_refl: 		ds 1
cseg

; These 'equ' must match the hardware wiring
LCD_RS equ P1.1
LCD_RW equ P1.2 ; Not used in this code
LCD_E  equ P1.3
LCD_D4 equ P3.2
LCD_D5 equ P3.3
LCD_D6 equ P3.4
LCD_D7 equ P3.5


$NOLIST
$include(LCD_4bit.inc) ; A library of LCD related functions and utility macros
$LIST
	
Initial_Message0:  db '1 ', 0
Initial_Message1:  db 'TeS ', 0
Initial_Message2:  db 'TiS ', 0
Initial_Message3:  db 'TeR ', 0
Initial_Message4:  db 'TiR ', 0


loop:
	mov SP, #7FH
    lcall LCD_4BIT
	Set_Cursor(1,1)
	Send_Constant_String(#Initial_Message0)
	mov P0M0, #0
    mov P0M1, #0

	mov temp_soak, 		#0x150
	mov time_soak, 		#0x60
	mov temp_refl,		#0x150
	mov a,temp_refl
	add a,#0x110
	da a
	mov temp_refl,a
	mov time_refl, 		#0x40
	
check_temp_soak:
    jb TEMP_SOAK_BUTTON, check_time_soak
    Wait_Milli_Seconds(#50)
    jb TEMP_SOAK_BUTTON, check_time_soak
    jnb TEMP_SOAK_BUTTON,$
set_temp_soak:
	mov a, temp_soak
	cjne a,#0x180, change_temp_soak
	mov a,#0x129
	mov temp_soak,a
change_temp_soak:
	add a, #0x01
	da a
	mov temp_soak,a

check_time_soak:;
    jb TIME_SOAK_BUTTON, check_temp_refl 
    Wait_Milli_Seconds(#50)
    jb TIME_SOAK_BUTTON, check_temp_refl 
    jnb TIME_SOAK_BUTTON, $
set_time_soak:
	mov a, time_soak
	cjne a, #0x50, change_time_soak
	mov a, #0x19
	mov time_soak, a
change_time_soak:
	add a, #0x01
	da a
	mov time_soak, a
	
check_temp_refl:;
    jb TEMP_REFL_BUTTON, check_time_refl 
    Wait_Milli_Seconds(#50)
    jb TEMP_REFL_BUTTON, check_time_refl
    jnb TEMP_REFL_BUTTON, $
set_temp_refl:
	mov a, temp_refl
	cjne a, #0x260, change_temp_refl
	mov a, #0x179
	mov temp_refl, a
change_temp_refl:
	add a, #0x01
	da a
	mov temp_refl, a
	
check_time_refl:
    jb TIME_REFL_BUTTON, displayloop 
    Wait_Milli_Seconds(#50)
    jb TIME_REFL_BUTTON, displayloop
    jnb TIME_REFL_BUTTON, $
set_time_refl:
	mov a, time_refl
	cjne a, #0x65, change_time_refl
	mov a, #0x19
	mov time_refl, a
change_time_refl:
	add a, #0x01
	da a
	mov time_refl, a
	
displayloop:
	Set_Cursor(1,1)
	Send_Constant_String(#Initial_Message1)
	Set_Cursor(1,5)
	Display_BCD(temp_soak)
	Set_Cursor(1,9)
	Send_Constant_String(#Initial_Message2)
	Set_Cursor(1,13)
	Display_BCD(time_soak)
	Set_Cursor(2,1)
	Send_Constant_String(#Initial_Message3)
	Set_Cursor(2,5)
	Display_BCD(temp_refl)
	Set_Cursor(2,9)
	Send_Constant_String(#Initial_Message4)
	Set_Cursor(2,13)
	Display_BCD(time_refl)
	ljmp check_temp_soak
	
end
