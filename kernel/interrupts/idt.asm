[bits 32]

section .text

global idt_init

extern keyboard_handler


; ============================================================
; VertexOS Interrupt Descriptor Table
; ============================================================


; ============================================================
; IDT Entry
;
; 32-bit Protected Mode IDT entry = 8 bytes
; ============================================================

struc IDT_ENTRY
    .offset_low  resw 1
    .selector    resw 1
    .zero        resb 1
    .flags       resb 1
    .offset_high resw 1
endstruc


; ============================================================
; IDT storage
;
; 256 × 8 = 2048 bytes
; ============================================================

section .data

idt:
    times 256 * 8 db 0


; ============================================================
; IDT Pointer
; ============================================================

idt_pointer:

    dw 2048 - 1
    dd idt


section .text


; ============================================================
; idt_init
;
; Initializes the IDT and installs:
;
; IRQ1 → interrupt vector 0x21
; ============================================================

idt_init:

    ; --------------------------------------------------------
    ; Clear IDT
    ; --------------------------------------------------------

    mov edi, idt

    xor eax, eax

    mov ecx, 2048

    rep stosb


    ; --------------------------------------------------------
    ; Install keyboard handler at vector 0x21
    ;
    ; IDT entry address:
    ;
    ; 0x21 × 8 = 0x108
    ; --------------------------------------------------------

    mov eax, keyboard_handler


    ; Low 16 bits of handler address

    mov word [idt + 0x21 * 8], ax


    ; Code segment selector

    mov word [idt + 0x21 * 8 + 2], 0x08


    ; Reserved byte

    mov byte [idt + 0x21 * 8 + 4], 0


    ; Interrupt gate
    ;
    ; 0x8E =
    ; Present
    ; DPL 0
    ; 32-bit Interrupt Gate

    mov byte [idt + 0x21 * 8 + 5], 0x8E


    ; High 16 bits of handler address

    shr eax, 16

    mov word [idt + 0x21 * 8 + 6], ax


    ; --------------------------------------------------------
    ; Load IDT register
    ; --------------------------------------------------------

    lidt [idt_pointer]

    ret
