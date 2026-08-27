; file: temp module
; authors: Lucas De Boi, Daniel Lelescu

; file: temp_module.asm
; purpose: all constants and subroutines related to the temperature module

; -----------------------------------------
; Local constants
; -----------------------------------------

; 1-Wire ROM / function commands are defined in wire1.asm


; DS18B20 configuration byte
; 11-bit resolution -> config = 0x5F
.equ TEMP_RES = 0x5F

; Internal states
.equ IDLE           = 0
.equ CONV_RUNNING   = 1

; Scheduler-based conversion wait
; One scheduler tick ~= 9.984 ms
; 41 ticks ~= 409.3 ms (a bit of margin from the conversion time for 11 bit resolution which is 375 ms)
.equ TEMP_CONV_TICKS = 41

; Overheat threshold
; .equ TEMP_OVERHEAT_RAW   = 0x01E0


; -----------------------------------------
; temp_init
; purpose:
;   - initialize 1-Wire interface
;   - configure the temp sensor to 11-bit resolution (0.25°C)
;   - initialize temperature variables
; -----------------------------------------
temp_init:
    rcall   wire1_init

    ; initialize variables
    ldi		w, 0
    sts		temp_state, w
    sts		temp_raw_lo, w
    sts		temp_raw_hi, w

	ldi		w, 0x90
	sts		target_temp, w ; 25C default target
	ldi		w, 25
	sts		target_temp_dec, w

    ; Configure DS18B20 resolution to 11 bits
    ; Write Scratchpad: TH, TL, Config
    rcall wire1_reset
    CA wire1_write, skipROM
    CA wire1_write, writeScratchpad
    CA wire1_write, 0x00          ; TH dummy value
    CA wire1_write, 0x00          ; TL dummy value
    CA wire1_write, TEMP_RES

    ret


; -----------------------------------------
; temp_service
; purpose:
;   - if IDLE and temp_sched_flag = 1:
;       start a conversion and load temp_conv_cnt
;   - if CONV_RUNNING and temp_conv_cnt = 0:
;       read temperature (and update overheat_flag)
; -----------------------------------------
temp_service:
    lds w, temp_state
    tst w
    breq temp_idle_part

    ; ---------------------------------
    ; conversion running
    ; ---------------------------------
    lds w, temp_conv_cnt
    tst w
    brne temp_service_done

    ; conversion finished -> read scratchpad

	rcall wire1_reset
	CA wire1_write, skipROM
	CA wire1_write, readScratchpad

	rcall wire1_read
	sts temp_raw_lo, a0

	rcall wire1_read
	sts temp_raw_hi, a0


    ; back to IDLE
    ldi w, IDLE
    sts temp_state, w

    ; update lcd and servo AUTO refresh flags 
	ldi w, 1
	sts lcd_auto_refresh_flag, w
	sts servo_auto_refresh_flag, w
    
	rjmp temp_service_done

    ; ---------------------------------
    ; idle state
    ; ---------------------------------
temp_idle_part:
    lds w, temp_sched_flag
    tst w
    breq temp_service_done

    ; consume scheduling flag
    ldi w, 0
    sts temp_sched_flag, w

    ; start a new conversion
    rcall wire1_reset
    CA wire1_write, skipROM
    CA wire1_write, convertT

    ; load relative wait counter
    ldi w, TEMP_CONV_TICKS
    sts temp_conv_cnt, w

    ; enter running state
    ldi w, CONV_RUNNING
    sts temp_state, w

temp_service_done:
    ret
