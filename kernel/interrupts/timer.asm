[bits 32]

section .text

global timer_init
global timer_handler
global timer_ticks


; ============================================================
; PIT
; ============================================================

PIT_COMMAND equ 0x43
PIT_CHANNEL0 equ 0x40

; PIT input frequency:
;
; 1193182 Hz
;
; Divisor 11932 gives approximately 100 Hz.
;
; 1193182 / 11932 ≈ 100 Hz
;
PIT_DIVISOR equ 11932


; ============================================================
; timer_init
;
; Configure PIT channel 0:
;
;   Channel 0
;   Access mode: low byte then high byte
;   Mode 3: square wave generator
;   Binary mode
;
; Frequency ≈ 100 Hz
; ============================================================

timer_init:

    ; --------------------------------------------------------
    ; Command:
    ;
    ; 00 11 011 0
    ;
    ; Channel 0
    ; Low/high byte
    ; Mode 3
    ; Binary
    ; --------------------------------------------------------

    mov al, 0x36

    out PIT_COMMAND, al


    ; --------------------------------------------------------
    ; Send divisor low byte.
    ; --------------------------------------------------------

    mov ax, PIT_DIVISOR

    out PIT_CHANNEL0, al


    ; --------------------------------------------------------
    ; Send divisor high byte.
    ; --------------------------------------------------------

    mov al, ah

    out PIT_CHANNEL0, al

    ret


; ============================================================
; TIMER INTERRUPT HANDLER
; ============================================================

timer_handler:

    pushad

    inc dword [timer_ticks]


    ; --------------------------------------------------------
    ; Send End Of Interrupt to master PIC.
    ; --------------------------------------------------------

    mov al, 0x20

    out 0x20, al

    popad

    iretd


; ============================================================
; DATA
; ============================================================

section .data

timer_ticks:
    dd 0
