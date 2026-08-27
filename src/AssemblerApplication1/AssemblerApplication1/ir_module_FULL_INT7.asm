; file: ir_module.asm
; authors: Lucas De Boi, Daniel Lelescu
; purpose: IR decoding with full reception inside INT7 ISR

; -----------------------------------------
; Local constants
; -----------------------------------------
; Same timing as reference ir_rc5.asm
; -----------------------------------------

.equ T1 = 1870


; -----------------------------------------
; ir_init
; purpose:
;   - configure PE7 as input
;   - configure INT7 on falling edge
;   - initialize IR variables
; -----------------------------------------
ir_init:
    ; PE7 input, no pull-up
    cbi     DDRE, IR ; IR is defined as pin 7 in definitions.asm
    cbi     PORTE, IR

    ; INT7 on falling edge to detect RC5 transmission start bit
    ; ISC71:ISC70 = 0b10
    ldi     w, (1<<ISC71)
    out     EICRB, w

    ; initialize IR variables
    ldi     w, 0
    sts     command, w
    sts     command_raw_low, w
    sts     command_raw_hi, w
    sts     new_exec_cmd_flag, w
    sts     new_raw_cmd_flag, w
	sts		last_toggle_bit, w

    ; clear pending INT7 flag
    ldi     w, (1<<INTF7)
    out     EIFR, w

    ; enable INT7
    ldi     w, (1<<INT7)
    out     EIMSK, w

    ret


; -----------------------------------------
; ext_int7
; purpose:
;   - receive the full 14-bit RC5 frame inside the ISR
;   - publish raw reception complete
; -----------------------------------------
ext_int7:
    ; save context
    push    w
    in      w, SREG
    push    w
    push    b0
    push    b1
    push    b2

	; disable INT7 during decoding
    in      w, EIMSK
    andi    w, 0b01111111
    out     EIMSK, w

    ; initialize reception buffer
    ldi     w, 0
    sts     command_raw_low, w
    sts     command_raw_hi, w
    sts     new_raw_cmd_flag, w

    CLR2    b1, b0
    ldi     b2, 14

    ; same timing as reference file
    WAIT_US (T1/4)

ir_decode_loop:
    P2C     PINE, IR
    ROL2    b1, b0
    WAIT_US (T1-4)
    DJNZ    b2, ir_decode_loop

    ; store raw 14-bit reception
    sts     command_raw_low, b0
    sts     command_raw_hi, b1

    ; publish raw reception complete
    ldi     w, 1
    sts     new_raw_cmd_flag, w

    ; restore context
    pop     b2
    pop     b1
    pop     b0
    pop     w
    out     SREG, w
    pop     w
    reti


; -----------------------------------------
; ir_service
; purpose:
;   - if a raw 14-bit reception is complete, do the post-processing
;   - publish final command
;   - set new_exec_cmd_flag = 1
;   - re-enable INT7
; -----------------------------------------
ir_service:
    lds     w, new_raw_cmd_flag
    tst     w
    breq    ir_service_done

    ; consume raw-ready flag
    ldi     w, 0
    sts     new_raw_cmd_flag, w

	; anti-corruption/debouncing measure, before rising/falling edge detection
	lds     a0, command_raw_hi		; (00)(2x start bit)(toggle bit)(2x device address bits)
    mov     a1, a0
    andi    a1, 0b00100000          ; isolating start bit 1
    brne    ir_service_done 

	; rising/falling edge detection for toggle bit
	andi	a0, (1<<3)				; isolating new toggle bit
	lds		a1, last_toggle_bit
	cp		a0, a1					; comparing toggle bits
	breq	ir_service_done			; same toggle = held down button, skip to done

	sts		last_toggle_bit, a0 ; if unique cmd, update last toggle bit

    ; same post-processing as reference ir_rc5.asm
    lds     a0, command_raw_low
    com     a0
    sts     command, a0

    ; publish final command
    ldi     w, 1
    sts     new_exec_cmd_flag, w

ir_service_done:
    ; clear pending INT7 flag and re-enable INT7
    ldi     w, (1<<INTF7)
    out     EIFR, w

    in      w, EIMSK
    ori     w, (1<<INT7)
    out     EIMSK, w

    ret