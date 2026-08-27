; file: ir.asm
; purpose: all constants and subroutines related to the IR module

; -----------------------------------------
; Local constants
; -----------------------------------------
; From the reference file ir_rc5, we get Tbit = 1870 us:
;   T1 = 1870 us
;
; Timer2 choice:
;   f_clk = 4 MHz
;   prescaler = 32
;   => Timer2 tick = 8 us
;
; Therefore:
; T0 = T1/4 = 468 us
; T0_ticks = 468/8  = 59 ticks (waiting time in ticks since detection of start bit before sampling the first data bit)
; -----------------------------------------

.equ    T1     = 1870 ; us
.equ    T0_ticks    = 50 ; ticks --> needs to be in ticks because we apparently can't call a macro with an argument that can't be 
				   ;           calculated at moment of assembly. For the wait period before sampling the first bit, we cant 
				   ;		   call WAIT_US T1/4 - (Timer 2 value converted to us)


; -----------------------------------------
; ir_init
; purpose:
;   - configure PE7 as input for incoming command bit sampling
;   - configure INT7 on falling edge for start bit detection and subsequent triggering of INT7
;   - configure Timer2 
;	- initialize all IR variables
; -----------------------------------------
ir_init:
    ; PE7 input, no pull-up
    cbi     DDRE, IR  ; the IR symbol is defined as 7 in definitions.asm
    cbi     PORTE, IR

	 ; -------------------------
    ; Timer2:
    ; normal mode, prescaler = 32
	; COM21:COM20 = 0b00 (COM: Compare Output Mode: we set to 0 (deactivated) since this is irrelevant to our application)
    ; CS22:CS20 = 0b011  (CS2x: "Clock Select for timer 2, bit x" - A 32 prescaler is coded by 3 in CS2)
    ; -------------------------
    ldi     w, (1<<CS21) + (1<<CS20)
    out     TCCR2, w  ; TCCR2: Timer/Counter 2 Control Register

	; -------------------------
    ; INT7 on falling edge
    ; ISC71:ISC70 = 0b10 (c.f. page 214 in the book)
    ; EICRB bits 7:6 control INT7
    ; -------------------------
    ldi     w, (1<<ISC71)
    out     EICRB, w

	; initialize timer2 to 0
    ldi     w, 0
    out     TCNT2, w 

	; Initilialize all IR variables to 0
    ldi     w, 0
    sts		command, w
    sts     new_exec_cmd_flag, w
    sts     incoming_command_flag, w

	; Clear any pending INT7 flag before enabling INT7
    ldi     w, (1<<INTF7)
    out     EIFR, w

    ; Enable INT7
    ldi     w, (1<<INT7)
    out     EIMSK, w ; EIMSK: "External Interupt Mask"

	ret

; -----------------------------------------
; ext_int7 --> Interrupt Service Routine
; purpose:
;   - detect start of incoming IR command
;   - update incoming_command_flag
; -----------------------------------------
ext_int7:
	; "sauvegarde de contexte": we temporarily save the values of w and SREG on the stack until the end of the ISR
    push    w
    in      w, SREG
    push    w

	; reset Timer2 to measure elapsed time
    ldi     w, 0
    out     TCNT2, w

    ; incoming_command_flag = 1
    ldi     w, 1
    sts     incoming_command_flag, w

    ; disable INT7 until we've decoded the incoming command
    in      w, EIMSK
    andi    w, 0b01111111
    out     EIMSK, w

    pop     w
    out     SREG, w
    pop     w
    reti


; -----------------------------------------
; ir_service
; purpose:
;   - if a command is incoming, sample it
;   - abort reception if arrival in ir_service was too late (TCNT2 > T0_ticks)
;   - store final command in command
;   - set new_exec_cmd_flag = 1
;   - re-enable INT7 and restore previous SREG
; -----------------------------------------
ir_service:
    ; new incoming command?
    lds     w, incoming_command_flag
    tst     w
    breq    ir_service_done          ; no new command to process

    ; save current SREG, then disable interrupts during decoding
    in      w, SREG
    push    w
    cli

    ; consume incoming_command_flag
    ldi     w, 0
    sts     incoming_command_flag, w

    ; abort if Timer2 overflowed since INT7
    in      w, TIFR
    sbrc    w, TOV2
    rjmp    ir_abort_reception

    ; otherwise abort if arrival is already later than T0
    in      w, TCNT2
    cpi     w, T0_ticks+1
    brsh    ir_abort_reception

    ; initialize shift registers and bit counter
    CLR2    b1, b0
    ldi     b2, 14

    ; wait until Timer2 reaches T0
ir_wait_first_sample:
    in      w, TCNT2
    cpi     w, T0_ticks
    brlo    ir_wait_first_sample

ir_decode_loop:
    ; sample same physical IR line on PE7
    P2C     PINE, IR
    ROL2    b1, b0

    WAIT_US (T1-4)                   ; wait one bit period (- compensation)
    DJNZ    b2, ir_decode_loop

ir_decode_done:
    ; same post-processing as reference ir_rc5.asm
    com     b0
    sts     command, b0

    ldi     w, 1
    sts     new_exec_cmd_flag, w           ; read later by state_update_service

    rjmp    ir_finish_reception


; ------------------------------------------------
; Reception aborted because ir_service was reached too late
; ------------------------------------------------
ir_abort_reception:
    ; nothing to publish, just recover cleanly


; ------------------------------------------------
; Common cleanup path
; ------------------------------------------------
ir_finish_reception:
    ; clear pending INT7 flag
    ldi     w, (1<<INTF7)
    out     EIFR, w

    ; re-enable INT7
    in      w, EIMSK
    ori     w, (1<<INT7)
    out     EIMSK, w

    ; restore previous SREG
    pop     w
    out     SREG, w

ir_service_done:
    ret