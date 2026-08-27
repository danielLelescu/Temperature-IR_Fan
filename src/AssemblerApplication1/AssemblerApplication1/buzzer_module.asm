; file: buzzer_module.asm
; authors: Lucas de Boi, Daniel Lelescu
; purpose: control of buzzer module, with goal of response to IR inputs

buzzer_init:
	sbi     DDRE, SPEAKER
	cbi		PORTE, SPEAKER
	ret


buzzer_beep: ; makes the buzzer beep, to be called when a button is pressed
	push	a0
	push	a1
	push	w

    ldi     a0, 20
    buzz:
        sbi     PORTE, SPEAKER
        WAIT_US 1500
        cbi     PORTE, SPEAKER
        WAIT_US 1500
        dec     a0
        brne    buzz ; loop until a0 = 0

	pop		w
	pop		a1
	pop		a0

    ret
