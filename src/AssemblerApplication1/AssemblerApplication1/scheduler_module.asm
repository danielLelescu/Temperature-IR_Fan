; file: scheduler.asm
; authors: Lucas De Boi, Daniel Lelescu

; file: scheduler_module.asm
; purpose: periodic software scheduler using Timer0 compare match

; -----------------------------------------
; Local constants
; -----------------------------------------
; Timer0:
;   f_clk = 4 MHz
;   prescaler = 1024
;   tick = 256 us
;
; CTC ("Clear Timer on Compare Match) with OCR0 (Ouput Compare Register) = 38:
;   period = (38+1)*256 us = 9984 us ~= 10 ms
; -----------------------------------------

.equ SCHED_OCR0              = 38

; software periods expressed in scheduler ticks 
.equ LCD_SCHED_RELOAD        = 10      ; ~100 ms
.equ TEMP_SCHED_RELOAD     = 100     ; ~ 1 ms 

; -----------------------------------------
; scheduler_init
; purpose:
;   - configure Timer0 in CTC (Clear Timer on Compare Match) mode
;   - enable compare match interrupt
;   - initialize software counters and flags
; -----------------------------------------
scheduler_init:
    ; initialize software counters
    ldi     w, LCD_SCHED_RELOAD
    sts     lcd_sched_cnt, w

    ldi     w, TEMP_SCHED_RELOAD
    sts     temp_sched_cnt, w

    ldi     w, 0
    sts     temp_conv_cnt, w
    sts     lcd_sched_flag, w
    sts     temp_sched_flag, w

    ; Timer0 CTC mode, OCR0 = 38
    ldi     w, SCHED_OCR0
    out     OCR0, w

    ; WGM01 = 1 -> CTC
    ; CS02:CS00 = 111 -> prescaler 1024
    ldi     w, (1<<WGM01) + (1<<CS02) + (1<<CS01) + (1<<CS00)
    out     TCCR0, w

    ; clear any pending compare flag
    ldi     w, (1<<OCF0)
    out     TIFR, w

    ; enable Timer0 compare interrupt
    in      w, TIMSK
    ori     w, (1<<OCIE0)
    out     TIMSK, w

    ret


; -----------------------------------------
; timer0_comp_isr
; purpose:
;   periodic scheduler tick (~10 ms)
; -----------------------------------------
timer0_comp_isr:
    push    w
    in      w, SREG
    push    w

    ; ---------------------------------
    ; LCD scheduler counter
    ; ---------------------------------
    lds     w, lcd_sched_cnt
    tst     w
    breq    lcd_cnt_reload

    dec     w
    sts     lcd_sched_cnt, w
    brne    temp_sched_part

lcd_cnt_reload:
    ldi     w, LCD_SCHED_RELOAD
    sts     lcd_sched_cnt, w

    ldi     w, 1
    sts     lcd_sched_flag, w

temp_sched_part:
    ; ---------------------------------
    ; Temperature scheduler counter
    ; ---------------------------------
    lds     w, temp_sched_cnt
    tst     w
    breq    temp_cnt_reload

    dec     w
    sts     temp_sched_cnt, w
    brne    temp_conv_part

temp_cnt_reload:
    ldi     w, TEMP_SCHED_RELOAD
    sts     temp_sched_cnt, w

    ldi     w, 1
    sts     temp_sched_flag, w

temp_conv_part: 
    ; ---------------------------------
    ; Temperature conversion countdown
    ; ---------------------------------
    lds     w, temp_conv_cnt
    tst     w
    breq    scheduler_isr_done

    dec     w
    sts     temp_conv_cnt, w

scheduler_isr_done:
    pop     w
    out     SREG, w
    pop     w
    reti