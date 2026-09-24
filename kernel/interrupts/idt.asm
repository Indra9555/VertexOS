[bits 32]

; ============================================================
; VertexOS Interrupt Descriptor Table
; ============================================================

; ------------------------------------------------------------
; IDT Entry
; Each entry is 8 bytes in 32-bit Protected Mode
; ------------------------------------------------------------

struc IDT_ENTRY
    .offset_low  resw 1
    .selector    resw 1
    .zero        resb 1
    .flags       resb 1
    .offset_high resw 1
endstruc

; ------------------------------------------------------------
; IDT Pointer
; Used by the CPU's LIDT instruction
; ------------------------------------------------------------

struc IDT_POINTER
    .limit resw 1
    .base  resd 1
endstruc

; ------------------------------------------------------------
; IDT storage
; 256 entries × 8 bytes = 2048 bytes
; ------------------------------------------------------------

idt:
    times 256 * 8 db 0

; ------------------------------------------------------------
; IDT Pointer
; ------------------------------------------------------------

idt_pointer:
    dw 2048 - 1
    dd idt

; ------------------------------------------------------------
; Initialize the IDT
; ------------------------------------------------------------

global idt_init

idt_init:
    lidt [idt_pointer]
    ret
