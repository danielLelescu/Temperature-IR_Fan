; file: main.asm
; authors: Lucas De Boi, Daniel Lelescu
.include "m128def.inc"
.include "macros.asm"
.include "definitions.asm"


.dseg
.org 0x0260 ; zone in SRAM where variables can be directly accessed by printf and displayed
.include "project_vars.asm"

.cseg
; =========================
; table des vecteurs
; =========================
.org 0
    jmp reset

.org INT7addr ; IR command detection
    jmp ext_int7

.org OC0addr ; general timer: update of software counters and setting of sched_flags
    jmp timer0_comp_isr



.include "lcd.asm"
.include "printf.asm"
.include "wire1.asm"

; =========================
; reset
; =========================
reset:
    LDSP RAMEND

	OUTI DDRC, 0xFF ; for testing the IR module via the LEDs

	;OUTI PORTC, 0xFF
	
	rcall scheduler_init
	;OUTI PORTC, 0x01
	rcall ir_init
	;OUTI PORTC, 0x02
	rcall temp_init
	;OUTI PORTC, 0x04
	rcall state_init
	;OUTI PORTC, 0x08
	rcall buzzer_init
	;OUTI PORTC, 0x00

	rcall LCD_init
	;OUTI PORTC, 0x20
	rcall LCD_clear
    rcall LCD_home
	rcall lcd_display_manual
	;OUTI PORTC, 0x40
    rcall servo_init
	;OUTI PORTC, 0x80
    
    sei

main:
    rcall ir_service
	rcall temp_service
	rcall state_update_service
	rcall servo_service
	rcall lcd_service

	;--- GENERAL TESTING ---
	;rcall buzzer_beep

	; ----------TEMP MODULE TESTING ------------
	; line 1: conversion state S (IDLE=0, RUNNING=1) and C: temp_conv_cnt
;	lds w, lcd_sched_flag
;	tst w
;	breq main_loop_end
;	ldi w, 0
;	sts lcd_sched_flag, w
;   rcall   LCD_home
;   PRINTF  LCD
;.db "S=",FHEX,low(temp_state)," C=",FHEX,low(temp_conv_cnt),LF,0

    ; line 2 : température in decimal
;    lds     a0, temp_raw_lo
;    lds     a1, temp_raw_hi
;    PRINTF  LCD
;.db "temp=",FFRAC2+FSIGN,a,4,$42,"C   ",0

; ----------IR MODULE TESTING ------------

; just to see the command being displayed on the LEDs while doing all debugging
;lds     w, command
;out     PORTC, w

;	rcall   LCD_home
;    PRINTF  LCD
;.db "cmd=",FHEX,command,"   ",0

; ---------- SCHEDULER TESTING ------------------
;	lds     w, temp_sched_flag
;    tst     w
;    breq    lcd_part

;    ldi     w, 0
;    sts     temp_sched_flag, w

;    in      w, PORTB
;    ldi     r17, 0b00000010      ; LED1
;    eor     w, r17
;    out     PORTB, w

;lcd_part:
;	lds     w, lcd_sched_flag
;   tst     w
;   breq    main_loop_end

;    ldi     w, 0
;    sts     lcd_sched_flag, w

;    in      w, PORTB
;    ldi     r17, 0b00000001      ; LED1
;    eor     w, r17
;    out     PORTB, w

; -------- State Manager Testing ------------
;   lds     w, lcd_sched_flag
;   tst     w
;   breq    main_loop_end
;
;   ldi     w, 0
;   sts     lcd_sched_flag, w

;   rcall   LCD_home
;   PRINTF  LCD
;.db "IR=",FHEX,low(command),"   ",LF,0
;   PRINTF LCD
;.db "M=",FHEX,low(mode)," P=",FHEX,low(auto_pause_flag)," S=",FHEX,low(manual_speed),0


main_loop_end:
    rjmp main


; =========================
; modules
; =========================
.include "scheduler_module.asm"
.include "ir_module_FULL_INT7.asm"
.include "temp_module.asm"
.include "state_manager.asm"
.include "buzzer_module.asm"
.include "servo_module.asm"
.include "lcd_module.asm"


