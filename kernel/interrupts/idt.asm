[bits 32]
[section .text]

; ============================================================
; VertexOS Interrupt Descriptor Table
; ============================================================

; ------------------------------------------------------------
; IDT storage
; 256 entries × 8 bytes = 2048 bytes
; ------------------------------------------------------------

[section .data]

align 8

idt:
    times 256 * 8 db 0

idt_pointer:
    dw 2048 - 1
    dd idt


; ============================================================
; Code
; ============================================================

[section .text]

global idt_init
global interrupt_handler

; ------------------------------------------------------------
; idt_init
;
; Initializes IDT entry 0x21 and loads the IDT.
; ------------------------------------------------------------

idt_init:

    ; --------------------------------------------------------
    ; Configure interrupt vector 0x21
    ; --------------------------------------------------------
    ;
    ; Handler address = interrupt_handler
    ; Selector       = 0x08 (kernel code segment)
    ; Flags          = 0x8E
    ;
    ; 0x8E = Present + Ring 0 + 32-bit Interrupt Gate
    ; --------------------------------------------------------

    mov eax, interrupt_handler

    ; Low 16 bits of handler address
    mov word [idt + (0x21 * 8) + 0], ax

    ; Kernel code segment
    mov word [idt + (0x21 * 8) + 2], 0x08

    ; Reserved byte
    mov byte [idt + (0x21 * 8) + 4], 0

    ; Interrupt gate
    mov byte [idt + (0x21 * 8) + 5], 0x8E

    ; High 16 bits of handler address
    shr eax, 16
    mov word [idt + (0x21 * 8) + 6], ax

    ; --------------------------------------------------------
    ; Load IDT
    ; --------------------------------------------------------

    lidt [idt_pointer]

    ret


; ============================================================
; Interrupt Handler
; ============================================================

interrupt_handler:

    ; --------------------------------------------------------
    ; Display interrupt message
    ; --------------------------------------------------------

    mov esi, interrupt_msg
    mov edi, 0xB81E0

.print:

    lodsb

    test al, al
    jz .done

    mov [edi], al
    mov byte [edi + 1], 0x0F

    add edi, 2

    jmp .print

.done:

    ; Return from interrupt
    iret


; ============================================================
; Messages
; ============================================================

interrupt_msg db "Interrupt 0x21 handled successfully!", 0
