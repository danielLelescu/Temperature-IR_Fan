; file: project_vars.asm
; purpose: SRAM variables 
; note: this file is meant to be included afer:
;		.dseg
;		. org 0x0260
; authors: Lucas De Boi, Daniel Lelescu

; -----------------------------------------
; SCHEDULER
; -----------------------------------------
; Counters
lcd_sched_cnt:              .byte 1
temp_sched_cnt:             .byte 1
temp_conv_cnt:              .byte 1
; Flags
lcd_sched_flag:             .byte 1
temp_sched_flag:            .byte 1


; -----------------------------------------
; IR
; -----------------------------------------
; Data
command:               .byte 1
command_raw_low:       .byte 1
command_raw_hi:        .byte 1
; Flags
new_exec_cmd_flag:		.byte 1
new_raw_cmd_flag:		.byte 1
last_toggle_bit:		.byte 1

; -----------------------------------------
; TEMPERATURE
; -----------------------------------------
; Data
temp_state:                 .byte 1
temp_raw_lo:                .byte 1
temp_raw_hi:                .byte 1
target_temp:				.byte 1
target_temp_dec:			.byte 1

; -----------------------------------------
; STATE MANAGER
; -----------------------------------------
mode:                           .byte 1
manual_speed:                   .byte 1
auto_pause_flag:                .byte 1

lcd_auto_refresh_flag:          .byte 1
lcd_manual_refresh_flag:        .byte 1

servo_auto_refresh_flag:        .byte 1
servo_manual_refresh_flag:      .byte 1

auto_servo_speed:				.byte 1


