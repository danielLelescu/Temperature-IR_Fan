; file: lcd_module.asm
; authors: Lucas de Boi, Daniel Lelescu
; purpose: visual interface of the application

lcd_service:

	; checking lcd_sched_flag
	lds w, lcd_sched_flag
	tst w
	brne PC+2
	rjmp lcd_service_done

	; consuming lcd_sched_flag if 1
	ldi w, 0
	sts lcd_sched_flag, w

	; checking mode
	lds w, mode
	cpi w, MODE_MANUAL
	breq lcd_service_manual


	; lcd_service_auto
	lds w, lcd_auto_refresh_flag
	tst w
	brne PC+2
	rjmp lcd_service_done

	; consuming auto_refresh_flag if 1
	ldi w, 0
	sts lcd_auto_refresh_flag, w
	rcall LCD_clear
	rjmp lcd_display_auto


	lcd_service_manual:
	lds w, lcd_manual_refresh_flag
	tst w
	brne PC+2
	rjmp lcd_service_done

	; consuming manual_refresh_flag if 1
	ldi w, 0
	sts lcd_manual_refresh_flag, w
	rcall LCD_clear
	rjmp lcd_display_manual

; --- drivers ---
lcd_display_auto:
    lds     a0, temp_raw_lo
    lds     a1, temp_raw_hi
   
	rcall LCD_home
	PRINTF LCD
	.db "mode: AUTO T=",FDEC,target_temp_dec,"C",LF,0
	PRINTF LCD
	.db "temp: ",FFRAC2+FSIGN,a,4,$42,"C   ",0

	;auto_servo_speed displayed on LEDs, abanadoned idea
	;lds		w, auto_servo_speed

	rjmp lcd_service_done

lcd_display_manual:
	rcall LCD_home
	PRINTF LCD
	.db "mode: MANUAL",LF,0
	PRINTF LCD
	.db "Speed: ",FHEX,low(manual_speed),0

lcd_service_done:
	ret
