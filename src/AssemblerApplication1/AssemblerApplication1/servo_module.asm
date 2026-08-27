; file: servo_module.asm
; authors: Lucas de Boi, Daniel Lelescu
; purpose: control of servo motor via PWM lookup table, to emulate fan

; Architecture:
;   servo_init    : Bloc 0 (driver) - Timer1 hardware PWM initialisation
;   servo_set_ocr : Bloc 0 (driver) - updates OCR1A pulse width
;   servo_manager : Bloc 1 (manager) - checks refresh flags, calls driver
;
; Hardware PWM — Timer1, Fast PWM, ICR1 as TOP:
;   - Output pin: OC1A = PB5 (hardware-fixed, set as output in DDRB)
;   - Prescaler 8 @ 4MHz -> tick = 2 us
;   - ICR1 = 9999 -> period = 10000 * 2 us = 20 ms
;   - OCR1A sets pulse width: OCR1A ticks * 2 us = pulse in us
;
; Modified SG90 pulse mapping (tick = 2 us):
;   500 ticks = 1000 us = 1.0 ms -> full speed one direction
;   750 ticks = 1500 us = 1.5 ms -> stopped (neutral)
;  1000 ticks = 2000 us = 2.0 ms -> full speed other direction
;
; Speed 1-9 lookup table maps to OCR1A tick values (500-1000).
;
; !! CALIBRATE SERVO_STOP for your servo after running servo36218.asm !!
; The neutral point is physical — 750 ticks is theoretical 1.5ms,
; your servo may stop at a slightly different value.
;
 
; -----------------------------------------
; Local constants
; -----------------------------------------
.equ SERVO_ICR1     = 9999  ; TOP -> 20 ms period
.equ SERVO_STOP     = 769  ; calibrated neutral/stop
.equ SERVO_MIN      = 500   ; 1.0 ms -> full speed one direction
.equ SERVO_MAX      = 1000  ; 2.0 ms -> full speed other direction
 
 
; -----------------------------------------
; servo_init
; Configure Timer1 for Fast PWM on OC1A (PB5).
; Call once during initialisation, before sei.
; -----------------------------------------
servo_init:

    ; OC1A (PB5) must be set as output for hardware PWM to appear on pin
    sbi     DDRB, 5

	; reset timer counter
    ldi     w, 0
    out     TCNT1H, w
    out     TCNT1L, w
	sts		auto_servo_speed, w ; initializing testing variable
 
    ; --- ICR1 = 9999 (sets 20ms period) ---
    ldi     w, high(SERVO_ICR1)
    out     ICR1H, w
    ldi     w, low(SERVO_ICR1)
    out     ICR1L, w
 
    ; --- OCR1A = SERVO_STOP (motor starts stopped) ---
    ldi     w, high(SERVO_STOP)
    out     OCR1AH, w
    ldi     w, low(SERVO_STOP)
    out     OCR1AL, w
 
    ; --- TCCR1A ---
    ; COM1A1:COM1A0 = 1:0 -> non-inverting Fast PWM on OC1A
    ;   (OC1A set at BOTTOM, cleared on compare match)
    ; WGM11:WGM10   = 1:0 -> Fast PWM mode 14 (ICR1 as TOP), combined with TCCR1B
    ldi     w, (1<<COM1A1) | (1<<WGM11)
    out     TCCR1A, w
 
    ; --- TCCR1B ---
    ; WGM13:WGM12 = 1:1 -> Fast PWM mode 14 (ICR1 as TOP)
    ; CS12:CS11:CS10 = 0:1:0 -> prescaler 8
    ldi     w, (1<<WGM13) | (1<<WGM12) | (1<<CS11)
    out     TCCR1B, w
 
    ret
 

servo_service:
    push    a0
    push    a1
    push    w
	push	b0
 
	; checking mode
    lds     w, mode
    cpi     w, MODE_MANUAL
    brne    PC+2
	rjmp	servo_manual
 
	; --- AUTO ---
	servo_auto:
    lds     w, servo_auto_refresh_flag
    tst     w
	brne	PC+2
    rjmp    servo_service_done
 
	; clearing auto_refresh_flag in case of 1
    clr     w
    sts     servo_auto_refresh_flag, w

	; checking pause_flag
    lds     w, auto_pause_flag
    tst     w
	breq	PC+2
    rjmp    servo_set_stop

 
    ; map integer degrees (temp_raw) to OCR tick value
    lds     a1, temp_raw_hi ; not needed to be analyzed until temperatures > 32C, as per DS18B20 decoding
	lds		a0, temp_raw_lo
 
	lds		b0, target_temp

    cp      a0, b0 ; (temp < target temp) - 1
    brlo    servo_auto_slow
	ADDI	b0, 0x10
    cp      a0, b0 ; (target + 1C) - 2
    brlo    servo_auto_med_low
	ADDI	b0, 0x10
    cp      a0, b0 ; (target + 2C) - 3
    brlo    servo_auto_med
	ADDI	b0, 0x10
    cp      a0, b0 ; (target + 3C) - 4
    brlo    servo_auto_med_high
	;ADDI	b0, 0x10
	;cp		a0, b0 ; (target + 4C) - 5
 
	servo_auto_fast: ; (target + 4C) - 5
		ldi     a1, high(1000)
		ldi     a0, low(1000)
		STI		auto_servo_speed, 5
		rjmp    servo_set_PWM
 
	servo_auto_med_high:
		ldi     a1, high(950)
		ldi     a0, low(950)
		STI		auto_servo_speed, 4
		rjmp    servo_set_PWM
 
	servo_auto_med:
		ldi     a1, high(900)
		ldi     a0, low(900)
		STI		auto_servo_speed, 3
		rjmp    servo_set_PWM
 
	servo_auto_med_low:
		ldi     a1, high(850)
		ldi     a0, low(850)
		STI		auto_servo_speed, 2
		rjmp    servo_set_PWM
 
	servo_auto_slow:
		ldi     a1, high(800)
		ldi     a0, low(800)
		STI		auto_servo_speed, 1
		rjmp    servo_set_PWM
 
	; --- MANUAL ---
	servo_manual:
	lds     w, servo_manual_refresh_flag
	tst     w
	breq    servo_service_done
 
	; clearing manual_refresh_flag in case of 1
    clr     w
    sts     servo_manual_refresh_flag, w
 
    ; table lookup: manual_speed 1-9 -> OCR tick value
    lds     w, manual_speed
 
    ldi     zl, low(2*servo_speed_table)
    ldi     zh, high(2*servo_speed_table)
	; ! decomment and comment above 2 lines to set calibration table !
	;ldi		zl, low(2*servo_calibration_table)
	;ldi		zh, high(2*servo_calibration_table)
 
    lsl     w                       ; byte offset = index * 2
    add     zl, w
    brcc    PC+2
    inc     zh
 
    lpm     a0, z+                  ; low byte first (.db layout)
    lpm     a1, z                   ; high byte
 
    rjmp    servo_set_PWM
 
; --- DRIVER ---
servo_set_stop:
	ldi		a1, high(SERVO_STOP)
	ldi		a0, low(SERVO_STOP)


; changes PWM via OCR1A, input 16bit tick value e.g high(750):low(750)
servo_set_PWM:
    out     OCR1AH, a1
    out     OCR1AL, a0
	; drop down into service_done

servo_service_done:
	pop		b0
    pop     w
    pop     a1
    pop     a0
    ret
 
 
; -----------------------------------------
; servo_speed_table
; Manual speed 1-9 -> OCR1A tick values (2 us/tick)
; speed 1 =  500 ticks = 1.0 ms  (fast one direction)
; speed 5 =  750 ticks = 1.5 ms  (stopped)
; speed 9 = 1000 ticks = 2.0 ms  (fast other direction)
; Stored low byte first to match lpm a0,z+ / lpm a1,z
; -----------------------------------------
servo_speed_table:
    .db low(SERVO_STOP), high(SERVO_STOP) ; speed 0
	.db low(780),  high(780)    ; speed 1 -- slowest
    .db low(808),  high(808)    ; speed 2
    .db low(835),  high(835)    ; speed 3
    .db low(862),  high(862)    ; speed 4
    .db low(890),  high(890)    ; speed 5
    .db low(918),  high(918)    ; speed 6
    .db low(945),  high(945)    ; speed 7
    .db low(972),  high(972)    ; speed 8
    .db low(1000), high(1000)   ; speed 9 -- fastest

servo_calibration_table: ; to find SERVO_STOP
    .db low(765),  high(765)	; -- lower bound, 0
	.db low(766),  high(766)    ; 1
    .db low(767),  high(767)    ; 2
    .db low(768),  high(768)    ; 3
    .db low(769),  high(769)    ; 4
    .db low(770),  high(770)    ; 5
    .db low(771),  high(771)    ; 6
    .db low(772),  high(772)    ; 7
    .db low(773),  high(773)    ; 8
    .db low(774),  high(774)    ; -- upper bound, 9
