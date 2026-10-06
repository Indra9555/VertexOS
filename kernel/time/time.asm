[bits 32]

section .text

global time_init
global time_get_ticks
global time_get_seconds

extern timer_ticks


; ============================================================
; time_init
;
; Initializes the kernel time subsystem.
;
; The PIT already increments timer_ticks approximately
; 100 times per second.
; ============================================================

time_init:
    ret


; ============================================================
; time_get_ticks
;
; Returns the current number of timer ticks.
;
; Return:
;   EAX = timer tick count
; ============================================================

time_get_ticks:
    mov eax, [timer_ticks]
    ret


; ============================================================
; time_get_seconds
;
; Converts timer ticks into elapsed seconds.
;
; PIT frequency:
;   100 ticks/second
;
; Return:
;   EAX = elapsed seconds
; ============================================================

time_get_seconds:
    mov eax, [timer_ticks]
    xor edx, edx
    mov ecx, 100
    div ecx
    ret
