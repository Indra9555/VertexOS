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
; Allocate space for 256 IDT entries
; 256 × 8 = 2048 bytes
; ------------------------------------------------------------

idt:
    times 256 * 8 db 0

idt_pointer:
    dw 2048 - 1
    dd idt
