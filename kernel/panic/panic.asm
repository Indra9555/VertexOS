[bits 32]

section .text

global kernel_panic


; ============================================================
; VertexOS Kernel Panic
;
; Purpose:
;
;   Provide a central mechanism for unrecoverable kernel errors.
;
; Behavior:
;
;   1. Disable CPU interrupts.
;   2. Print panic information.
;   3. Halt the CPU permanently.
;
; This function NEVER returns.
;
; Input:
;
;   ESI = address of null-terminated panic reason
;
; ============================================================


; ============================================================
; EXTERNAL COMPONENTS
; ============================================================

extern console_newline
extern console_print


; ============================================================
; kernel_panic
; ============================================================

kernel_panic:

    ; --------------------------------------------------------
    ; Preserve panic-reason pointer.
    ;
    ; console_print advances ESI while reading a string.
    ; --------------------------------------------------------

    push esi


    ; --------------------------------------------------------
    ; Disable interrupts.
    ; --------------------------------------------------------

    cli


    ; --------------------------------------------------------
    ; Print blank line before panic information.
    ; --------------------------------------------------------

    call console_newline


    ; --------------------------------------------------------
    ; Print separator.
    ; --------------------------------------------------------

    mov esi, panic_separator

    call console_print

    call console_newline


    ; --------------------------------------------------------
    ; Print panic title.
    ; --------------------------------------------------------

    mov esi, panic_title

    call console_print

    call console_newline


    ; --------------------------------------------------------
    ; Print separator.
    ; --------------------------------------------------------

    mov esi, panic_separator

    call console_print

    call console_newline


    ; --------------------------------------------------------
    ; Print panic reason label.
    ; --------------------------------------------------------

    mov esi, panic_reason_label

    call console_print


    ; --------------------------------------------------------
    ; Restore original panic-reason pointer.
    ; --------------------------------------------------------

    pop esi

    call console_print

    call console_newline


    ; --------------------------------------------------------
    ; Print final halt message.
    ; --------------------------------------------------------

    mov esi, panic_halted_message

    call console_print

    call console_newline


    ; --------------------------------------------------------
    ; Permanently halt the kernel.
    ;
    ; Interrupts are disabled, so normal kernel execution
    ; cannot continue.
    ; --------------------------------------------------------

kernel_panic_halt:

    hlt

    jmp kernel_panic_halt


; ============================================================
; DATA
; ============================================================

section .data


; ============================================================
; PANIC SEPARATOR
; ============================================================

panic_separator:

    db "==================================================", 0


; ============================================================
; PANIC TITLE
; ============================================================

panic_title:

    db "                  KERNEL PANIC", 0


; ============================================================
; PANIC REASON LABEL
; ============================================================

panic_reason_label:

    db "Reason: ", 0


; ============================================================
; HALT MESSAGE
; ============================================================

panic_halted_message:

    db "System halted.", 0
