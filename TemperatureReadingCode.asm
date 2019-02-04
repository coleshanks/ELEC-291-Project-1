; This program tests the LTC2308 avaliable in the newer version of the DE1-SoC board.
; Access to the input pins of the ADC is avalible at connector J15. Here is the top
; view of the connector:
;
; +--+
; |  | <-- Red power button
; +--+
;
; +-----+-----+
; + GND | IN7 |
; +-----+-----+
; + IN6 | IN5 |
; +-----+-----+
; + IN4 | IN3 |
; +-----+-----+
; + IN2 | IN1 |
; ------+-----+
; + IN0 | 5V  |
; +-----+-----+
;      J15
; 
; Displays the result using the 7-segment displays and also sends it via the serial port to PUTTy.
;
; (c) Jesus Calvino-Fraga 2019
;
$NOLIST
$MODDE1SOC
$LIST

; Bits used to access the LTC2308
LTC2308_MISO bit 0xF8 ; Read only bit
LTC2308_MOSI bit 0xF9 ; Write only bit
LTC2308_SCLK bit 0xFA ; Write only bit
LTC2308_ENN  bit 0xFB ; Write only bit

CLK EQU 33333333
BAUD EQU 115200
TIMER_2_RELOAD EQU (65536-(CLK/(32*BAUD)))
TIMER_0_1ms EQU (65536-(CLK/(12*1000)))

; Reset vector
org 0x0000
	ljmp MainProgram

; External interrupt 0 vector (not used in this code)
org 0x0003
	reti

; Timer/Counter 0 overflow interrupt vector (not used in this code)
org 0x000B
	reti

; External interrupt 1 vector (not used in this code)
org 0x0013
	reti

; Timer/Counter 1 overflow interrupt vector (not used in this code)
org 0x001B
	reti

; Serial port receive/transmit interrupt vector (not used in this code)
org 0x0023 
	reti
	
; Timer/Counter 2 overflow interrupt vector (not used in this code)
org 0x002B
	reti

Initialize_Serial_Port:
    ; Initialize serial port and baud rate using timer 2
	mov RCAP2H, #high(TIMER_2_RELOAD)
	mov RCAP2L, #low(TIMER_2_RELOAD)
	mov T2CON, #0x34 ; #00110100B
	mov SCON, #0x52 ; Serial port in mode 1, ren, txrdy, rxempty
	ret

putchar:
	jbc	TI,putchar_L1
	sjmp putchar
putchar_L1:
	mov	SBUF,a
	ret
	
getchar:
	jbc	RI,getchar_L1
	sjmp getchar
getchar_L1:
	mov	a,SBUF
	ret

SendString:
    clr a
    movc a, @a+dptr
    jz SendString_L1
    lcall putchar
    inc dptr
    sjmp SendString  
SendString_L1:
	ret
	
Initialize_LEDs:
    ; Turn off LEDs
	mov	LEDRA,#0x00
	mov	LEDRB,#0x00
	ret
	
Initialize_ADC:
	; Initialize SPI pins connected to LTC2308
	clr	LTC2308_MOSI
	clr	LTC2308_SCLK
	setb LTC2308_ENN
	ret

LTC2308_Toggle_Pins:
    mov LTC2308_MOSI, c
    setb LTC2308_SCLK
    mov c, LTC2308_MISO
    clr LTC2308_SCLK
    ret

; Bit-bang communication with LTC2308.  Check Figure 8 in datasheet (page 18):
; https://www.analog.com/media/en/technical-documentation/data-sheets/2308fc.pdf
; The VREF for this 12-bit ADC is 4.096V
; Warning: we are reading the previously converted channel! If you want to read the
; channel 'now' call this function twice.
;
; Channel to read passed in register 'b'.  Result in R1 (bits 11 downto 8) and R0 (bits 7 downto 0).
; Notice the weird order of the channel select bits!
LTC2308_RW:
    clr a 
	clr	LTC2308_ENN ; Enable ADC

    ; Send 'S/D', get bit 11
    setb c ; S/D=1 for single ended conversion
    lcall LTC2308_Toggle_Pins
    mov acc.3, c
    ; Send channel bit 0, get bit 10
    mov c, b.2 ; O/S odd channel select
    lcall LTC2308_Toggle_Pins
    mov acc.2, c 
    ; Send channel bit 1, get bit 9
    mov c, b.0 ; S1
    lcall LTC2308_Toggle_Pins
    mov acc.1, c
    ; Send channel bit 2, get bit 8
    mov c, b.1 ; S0
    lcall LTC2308_Toggle_Pins
    mov acc.0, c
    mov R1, a
    
    ; Now receive the lest significant eight bits
    clr a 
    ; Send 'UNI', get bit 7
    setb c ; UNI=1 for unipolar output mode
    lcall LTC2308_Toggle_Pins
    mov acc.7, c
    ; Send 'SLP', get bit 6
    clr c ; SLP=0 for NAP mode
    lcall LTC2308_Toggle_Pins
    mov acc.6, c
    ; Send '0', get bit 5
    clr c
    lcall LTC2308_Toggle_Pins
    mov acc.5, c
    ; Send '0', get bit 4
    clr c
    lcall LTC2308_Toggle_Pins
    mov acc.4, c
    ; Send '0', get bit 3
    clr c
    lcall LTC2308_Toggle_Pins
    mov acc.3, c
    ; Send '0', get bit 2
    clr c
    lcall LTC2308_Toggle_Pins
    mov acc.2, c
    ; Send '0', get bit 1
    clr c
    lcall LTC2308_Toggle_Pins
    mov acc.1, c
    ; Send '0', get bit 0
    clr c
    lcall LTC2308_Toggle_Pins
    mov acc.0, c
    mov R0, a

	setb LTC2308_ENN ; Disable ADC

	ret

; Converts the 16-bit hex number in [R1,R0] to a 
; 5-digit packed BCD in [R4,R3,R2] using the
; double-dabble algorithm.
hex2bcd16:
	clr a
	mov R4, a ; Initialize BCD to 00-00-00 
	mov R3, a
	mov R2, a
	mov R5, #16  ; Loop counter.

hex2bcd16_L1:
	; Shift binary left	
	mov a, R1
	mov c, acc.7 ; This way [R1,R0] remains unchanged!
	mov a, R0
	rlc a
	mov R0, a
	mov a, R1
	rlc a
	mov R1, a
    
	; Perform bcd + bcd + carry using BCD arithmetic
	mov a, R2
	addc a, R2
	da a
	mov R2, a
	mov a, R3
	addc a, R3
	da a
	mov R3, a
	mov a, R4
	addc a, R4
	da a
	mov R4, a

	djnz R5, hex2bcd16_L1

	ret

; Look-up table for the 7-seg displays. (Segments are turn on with zero) 
T_7seg:
    DB 40H, 79H, 24H, 30H, 19H, 12H, 02H, 78H, 00H, 10H

; Display the 4-digit bcd stored in [R3,R2] using the 7-segment displays
Display_BCD:
	mov dptr, #T_7seg
	; Display the channel in HEX5
	mov a, b
	anl a, #0x0f
	movc a, @a+dptr
	mov HEX5, a
	
	; Display [R3,R2] in HEX3, HEX2, HEX1, HEX0
	mov a, R3
	swap a
	anl a, #0x0f
	movc a, @a+dptr
	mov HEX3, a
	
	mov a, R3
	anl a, #0x0f
	movc a, @a+dptr
	mov HEX2, a
	
	mov a, R2
	swap a
	anl a, #0x0f
	movc a, @a+dptr
	mov HEX1, a
	
	mov a, R2
	anl a, #0x0f
	movc a, @a+dptr
	mov HEX0, a
	
	ret

; Send a 4-digit BCD number stored in [R3,R2] to the serial port	
SendNumber:
	mov a, #'\r'
	lcall putchar
	mov a, R3
	swap a
	anl a, #0x0f
	orl a, #'0'
	lcall putchar
	mov a, #'.'
	lcall putchar
	mov a, R3
	anl a, #0x0f
	orl a, #'0'
	lcall putchar
	mov a, R2
	swap a
	anl a, #0x0f
	orl a, #'0'
	lcall putchar
	mov a, R2
	anl a, #0x0f
	orl a, #'0'
	lcall putchar
	ret
	
; Wait 1 millisecond using Timer 0
Wait1ms:
	clr	TR0
	mov	a,#0xF0
	anl	a,TMOD
	orl	a,#0x01
	mov	TMOD,a
	mov	TH0, #high(TIMER_0_1ms)
	mov	TL0, #low(TIMER_0_1ms)
	clr	TF0
	setb TR0
	jnb	TF0,$
	clr	TR0
	ret
	
; Wait R2 milliseconds
MyDelay:
	lcall Wait1ms
    djnz R2, MyDelay
	ret
	
InitialString: db '\r\nLTC2308 test program\r\n', 0

;Below is code that converts to temperature (it is from Lab 3 and I am not sure if it will work)
Do_Something_With_Result:
;**********************In this part of the code, we should convert the voltage (in r1)also in Result into the temperature
;The formula is as follows
;T=100.0*(Vout-2.73)
;Where Vout is (ADC/(1023))*4.096 (ADC*4096)/(1000*1023)
;First, need to divide the value in r1/Result by 1023
;4 digits are

mov x+0, R0 ; lower 8 bits
mov x+1, R1 ; upper 4 bits in r1
mov x+2, #0
mov x+3, #0
Load_y(4096); load 4096 into y
lcall mul32 ;multiply ADC by 4096, x should contain 4096*ADC
Load_y(10230) ;load (1023*1000) into y to keep integer arithmetic
lcall div32 ; now x should contain (Vout)
Load_y(273); y should contain 273
lcall sub32 ;x=(Vout*100-273)
mov R0, x+0
mov R1, x+1
ret


MainProgram:
    mov sp, #0x7f
    lcall Initialize_LEDs
    lcall Initialize_Serial_Port
    lcall Initialize_ADC
    
    mov dptr, #InitialString
    lcall SendString

forever:
	mov a, SWA ; read the channel to convert from the switches
	anl a, #00000111B ; We need only the last three bits since there are only eight channels
	mov b, a
	lcall LTC2308_RW  ; Read the channel from the ADC
	lcall LTC2308_RW  ; Second function call, as per instructions. 
	lcall Do_Something_With_Result ; to convert the raw voltage values to temperature.
	lcall hex2bcd16   ; Convert to bcd
	
	lcall Display_BCD ; Display using the 7-segment displays
	lcall SendNumber  ; Send to serial port
	
	mov R2, #250
	lcall MyDelay
	
	sjmp forever
	
FSM:
	DSEG at 0x30
	;CSEG
	temp_soak: 		ds 1
	time_soak: 		ds 1
	temp_refl: 		ds 1
	time_refl: 		ds 1
	temp_finish:		ds 1

	mov temp_soak, 		#150
	mov time_soak, 		#60
	mov temp_refl,		#220
	mov time_refl, 		#45
	mov temp_finish,	#60

	sjmp state0

next_state:
	mov a, state

state0:
	cjne a, #0, state1
	mov pwm, #0
	jb KEY.3 state0_done
	jnb KEY.3, $
	mov state, #1
state0_done:
	ljmp next_state

state1:
	cjne a, #1, state2
	mov pwm, #100
	mov sec, #0
	mov a, temp_soak
	clr c
	subb a, temp
	jnc state1_done
	mov state, #2
state1_done:
	ljmp next_state

state2:
	cjne a, #2, state3
	mov pwm, #20
	mov a, time_soak
	clr c
	subb a, sec
	jnc state2_done
	mov state, #3
state2_done:
	ljmp next_state

state3:
	cjne a, #3, state4
	mov pwm, #100
	mov sec, #0
	mov a, temp_refl
	clr c
	subb a, temp
	jnc state3_done
	mov state, #4
state3_done:
	ljmp next_state

state4:
	cjne a, #4, state5
	mov pwm #20
	mov a, time_refl
	clr c
	subb a, sec
	jnc state4_done
	mov state, #5
state4_done:
	ljmp next_state

state5:
	cjne a, #5, state0
	mov pwm, #0
	mov a, temp_finish
	clr c
	subb a, temp
	jnc state5_done
	mov state, #0
state5_done:
	ljmp next_state

end
