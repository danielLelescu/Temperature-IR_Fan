; file: state_manager.asm
; authors: Lucas De Boi, Daniel Lelescu

; -----------------------------------------
; Local constants
; -----------------------------------------
; Mode symbols
.equ MODE_MANUAL = 0
.equ MODE_AUTO = 1

; Command constants (determined empirically)
.equ CMD_MODE_MANUAL = 0x20
.equ CMD_MODE_AUTO = 0x21
.equ CMD_PAUSE_PLAY = 0x0d
.equ CMD_PLUS = 0x10
.equ CMD_MINUS = 0x11

state_init:
    ldi     w, MODE_MANUAL
    sts     mode, w

    ldi     w, 0
    sts     manual_speed, w
    sts     auto_pause_flag, w

    sts     lcd_auto_refresh_flag, w
    sts     lcd_manual_refresh_flag, w
    sts     servo_auto_refresh_flag, w
    sts     servo_manual_refresh_flag, w

    ret




state_update_service:
	; Check if there's a new command to process
    lds     w, new_exec_cmd_flag
    tst     w
	brne	PC+2
    rjmp    state_update_done

	; If there is a new command to process, we consume the new_exec_cmd_flag and process the command
    ldi     w, 0
    sts     new_exec_cmd_flag, w

	rcall buzzer_beep


	; we first check what mode we're in and according to that modify the state variables according to the command
    lds     w, command

    lds     r17, mode
    cpi     r17, MODE_MANUAL
    breq    state_manual_part

state_auto_part:
	JK		w, CMD_PLUS, temp_plus
	JK		w, CMD_MINUS, temp_minus
    cpi     w, CMD_PAUSE_PLAY  ; Is it the pause/play command?
    brne    cmd_check_auto_to_manual ; If no, we go on to check if it's the manual mode button 

	; if pause/play, we complement the auto_pause_flag, and return
    lds     r17, auto_pause_flag
    ldi     r18, 1
    eor     r17, r18
    sts     auto_pause_flag, r17

	rjmp state_auto_update_done

	; adding 1C to target temp
	temp_plus:

	lds		w, target_temp
	ADDI	w, 0x10
	sts		target_temp, w ; updating target_temp in hex, for servo

	lds		w, target_temp_dec
	ADDI	w, 1
	sts		target_temp_dec, w ; updating target_temp in dec, for display

	STI		command, 1 ; consuming the plus
	rjmp	state_auto_update_done

	; substracting 1C from target tepm
	temp_minus:

	lds		w, target_temp
	SUBI	w, 0x10
	sts		target_temp, w ; updating target_temp in hex, for servo

	lds		w, target_temp_dec
	SUBI	w, 1
	sts		target_temp_dec, w ; updating target_temp in dec, for display

	STI		command, 1 ; consuming the minus
	; fall through to auto_update_done

	state_auto_update_done:
	ldi     r17, 1
    sts     lcd_auto_refresh_flag, r17
    sts     servo_auto_refresh_flag, r17

    rjmp    state_update_done

cmd_check_auto_to_manual:
    cpi     w, CMD_MODE_MANUAL ; Is it the manual mode button?
    brne    state_update_done ; If no, then it's an irrelevant button has been pressed and we do nothing

	; If yes, we set the mode to manual
    ldi     r17, MODE_MANUAL
    sts     mode, r17

    ldi     r17, 1
    sts     lcd_manual_refresh_flag, r17
    sts     servo_manual_refresh_flag, r17

    rjmp    state_update_done

state_update_done: ; closer label for breq
    ret

state_manual_part:
	; if its equal or greater than 10, then it's not a speed modification command, but of the other two: (pause/play) OR (manual -> auto)
    cpi     w, 10
    brsh	cmd_check_pause_play

    sts     manual_speed, w

    ldi     r17, 1
    sts     lcd_manual_refresh_flag, r17
    sts     servo_manual_refresh_flag, r17
    rjmp    state_update_done

cmd_check_pause_play:
    cpi     w, CMD_PAUSE_PLAY ; Is it the pause/play button?
    brne    cmd_check_manual_to_auto

    ldi     r17, 0
    sts     manual_speed, r17

    ldi     r17, 1
    sts     lcd_manual_refresh_flag, r17
    sts     servo_manual_refresh_flag, r17
    rjmp    state_update_done

cmd_check_manual_to_auto:
    cpi     w, CMD_MODE_AUTO ; Is it the manual --> auto button?
    brne    state_update_done ; If no, then irrelevant command

	; If yes, we change the mode 
    ldi     r17, MODE_AUTO 
    sts     mode, r17

	; If we were in AUTO and paused it, then changed to MANUAL, we would want the pause to not still be active when we go back
	ldi     r17, 0
	sts     auto_pause_flag, r17

    ldi     r17, 1
    sts     lcd_auto_refresh_flag, r17
    sts     servo_auto_refresh_flag, r17
	rjmp state_update_done

