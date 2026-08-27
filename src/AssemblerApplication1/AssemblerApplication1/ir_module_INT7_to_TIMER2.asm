; file: ir_module.asm
; authors: Lucas De Boi, Daniel Lelescu
; purpose: IR decoding using INT7 + Timer2 compare match in CTC mode

; -----------------------------------------
; Local constants
; -----------------------------------------
; Timer2:
;   f_clk = 4 MHz
;   prescaler = 32
;   => timer tick = 8 us
;
; T1 = 1870 us  -> 1870/8 = 233.75 ticks -> 234 ticks
; T0 was calibrated experimentally to 50 ticks in the previous version
;
; These values are written directly into OCR2.
; -----------------------------------------

.equ IR_T0_COMPARE = 50
.equ IR_T1_COMPARE = 233


; -----------------------------------------
; ir_init
; purpose:
;   - configure PE7 as input
;   - configure INT7 on falling edge
;   - configure Timer2 in CTC mode
;   - initialize IR variables
; -----------------------------------------
ir_init:
    ; PE7 input, no pull-up
    cbi DDRE, IR
    cbi PORTE, IR

    ; Timer2:
    ; CTC mode -> WGM21=1, WGM20=0
    ; prescaler = 32 -> CS22:CS20 = 0b011
    ldi w, (1<<WGM21) + (1<<CS21) + (1<<CS20)
    out TCCR2, w

    ; initialize Timer2 registers
    ldi w, 0
    out TCNT2, w
    out OCR2,  w

    ; INT7 on falling edge
    ; ISC71:ISC70 = 0b10
    ldi w, (1<<ISC71)
    out EICRB, w

    ; initialize IR variables
	ldi w, 0
    sts command, w
    sts ir_shift_lo, w
    sts ir_shift_hi, w
    sts ir_bits_left, w
    sts new_exec_cmd_flag, w
    sts new_raw_cmd_flag, w

    ; clear pending flags
    ldi     w, (1<<INTF7)
    out     EIFR, w

    ldi     w, (1<<OCF2)
    out     TIFR, w

    ; enable INT7
    ldi     w, (1<<INT7)
    out     EIMSK, w

    ; disable Timer2 compare interrupt initially
    in      w, TIMSK
    andi    w, 0b01111111         ; clear OCIE2
    out     TIMSK, w

    ret


; -----------------------------------------
; ext_int7
; purpose:
;   - start a new IR reception
;   - arm Timer2 compare for first sample at T0
; -----------------------------------------
ext_int7:
    push    w

    ; reset Timer2 as early as possible
    ldi     w, 0
    out     TCNT2, w

    ; now save SREG
    in      w, SREG
    push    w

    ; initialize reception buffer and bit counter
    ldi     w, 0
    sts     ir_shift_lo, w
    sts     ir_shift_hi, w
    sts     new_raw_cmd_flag, w

    ldi     w, 14
    sts     ir_bits_left, w

    ; disable INT7 during reception
    in      w, EIMSK
    andi    w, 0b01111111
    out     EIMSK, w

	; disable Timer0 compare interrupt during IR reception
    in      w, TIMSK
    andi    w, 0b01111101         ; clear OCIE0 (bit 1), keep others
    out     TIMSK, w

    ; first compare at T0
    ldi     w, IR_T0_COMPARE
    out     OCR2, w

    ; clear any pending compare flag
    ldi     w, (1<<OCF2)
    out     TIFR, w

    ; enable Timer2 compare interrupt
    in      w, TIMSK
    ori     w, (1<<OCIE2)
    out     TIMSK, w

    pop     w
    out     SREG, w
    pop     w
    reti


; -----------------------------------------
; timer2_comp_isr
; purpose:
;   - sample one bit on each compare match
;   - first compare is at T0
;   - next compares are at T1
;   - when 14 bits are received, publish raw-ready flag
; -----------------------------------------
timer2_comp_isr:
    push    w
    in      w, SREG
    push    w
    push    a0
    push    a1

    ; load current shift register
    lds     a0, ir_shift_lo
    lds     a1, ir_shift_hi

    ; sample IR pin into carry
    P2C     PINE, IR

    ; shift sampled bit into 16-bit register
    ROL2    a1, a0

    ; store updated shift register
    sts     ir_shift_lo, a0
    sts     ir_shift_hi, a1

    ; check whether this was the first sampled bit
    lds     w, ir_bits_left
    cpi     w, 14
    brne    ir_not_first_bit

    ; from now on, compare period becomes T1
    ldi     a0, IR_T1_COMPARE
    out     OCR2, a0

ir_not_first_bit:
    ; decrement remaining bits count
    dec     w
    sts     ir_bits_left, w
    brne    ir_timer2_restore

    ; ---------------------------------
    ; reception complete
    ; ---------------------------------

    ; disable Timer2 compare interrupt
    in      w, TIMSK
    andi    w, 0b01111111         ; clear OCIE2
    out     TIMSK, w

    ; publish raw reception complete
    ldi     w, 1
    sts     new_raw_cmd_flag, w

ir_timer2_restore:
    pop     a1
    pop     a0
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

    ; same post-processing as reference ir_rc5.asm
    lds     a0, ir_shift_lo
    com     a0
    sts     command, a0

    ; publish final command
    ldi     w, 1
    sts     new_exec_cmd_flag, w

    ; clear pending INT7 flag and re-enable INT7
    ldi     w, (1<<INTF7)
    out     EIFR, w

    in      w, EIMSK
    ori     w, (1<<INT7)
    out     EIMSK, w

	; re-enable Timer0 compare interrupt
    in      w, TIMSK
    ori     w, (1<<OCIE0)
    out     TIMSK, w

ir_service_done:
    ret