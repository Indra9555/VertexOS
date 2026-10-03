[bits 32]

section .text

global idt_init

extern keyboard_handler

extern exception_0
extern exception_1
extern exception_2
extern exception_3
extern exception_4
extern exception_5
extern exception_6
extern exception_7
extern exception_8
extern exception_9
extern exception_10
extern exception_11
extern exception_12
extern exception_13
extern exception_14
extern exception_15
extern exception_16
extern exception_17
extern exception_18
extern exception_19
extern exception_20
extern exception_21
extern exception_22
extern exception_23
extern exception_24
extern exception_25
extern exception_26
extern exception_27
extern exception_28
extern exception_29
extern exception_30
extern exception_31


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
; IDT ENTRY INSTALLATION MACRO
;
; %1 = interrupt vector
; %2 = handler address
;
; Each IDT entry contains:
;
; offset_low
; selector
; zero
; flags
; offset_high
; ============================================================

%macro SET_IDT_ENTRY 2

    mov eax, %2

    mov word [idt + %1 * 8], ax

    mov word [idt + %1 * 8 + 2], 0x08

    mov byte [idt + %1 * 8 + 4], 0

    mov byte [idt + %1 * 8 + 5], 0x8E

    shr eax, 16

    mov word [idt + %1 * 8 + 6], ax

%endmacro


; ============================================================
; idt_init
;
; Initializes the IDT and installs:
;
; CPU exceptions → vectors 0x00–0x1F
; Keyboard IRQ1 → vector 0x21
; ============================================================

idt_init:

    ; --------------------------------------------------------
    ; Clear entire IDT
    ; --------------------------------------------------------

    mov edi, idt

    xor eax, eax

    mov ecx, 2048

    rep stosb


    ; ========================================================
    ; CPU EXCEPTIONS
    ; ========================================================

    SET_IDT_ENTRY 0,  exception_0
    SET_IDT_ENTRY 1,  exception_1
    SET_IDT_ENTRY 2,  exception_2
    SET_IDT_ENTRY 3,  exception_3
    SET_IDT_ENTRY 4,  exception_4
    SET_IDT_ENTRY 5,  exception_5
    SET_IDT_ENTRY 6,  exception_6
    SET_IDT_ENTRY 7,  exception_7
    SET_IDT_ENTRY 8,  exception_8
    SET_IDT_ENTRY 9,  exception_9
    SET_IDT_ENTRY 10, exception_10
    SET_IDT_ENTRY 11, exception_11
    SET_IDT_ENTRY 12, exception_12
    SET_IDT_ENTRY 13, exception_13
    SET_IDT_ENTRY 14, exception_14
    SET_IDT_ENTRY 15, exception_15
    SET_IDT_ENTRY 16, exception_16
    SET_IDT_ENTRY 17, exception_17
    SET_IDT_ENTRY 18, exception_18
    SET_IDT_ENTRY 19, exception_19
    SET_IDT_ENTRY 20, exception_20
    SET_IDT_ENTRY 21, exception_21
    SET_IDT_ENTRY 22, exception_22
    SET_IDT_ENTRY 23, exception_23
    SET_IDT_ENTRY 24, exception_24
    SET_IDT_ENTRY 25, exception_25
    SET_IDT_ENTRY 26, exception_26
    SET_IDT_ENTRY 27, exception_27
    SET_IDT_ENTRY 28, exception_28
    SET_IDT_ENTRY 29, exception_29
    SET_IDT_ENTRY 30, exception_30
    SET_IDT_ENTRY 31, exception_31


    ; ========================================================
    ; KEYBOARD IRQ
    ;
    ; PIC remapping gives IRQ1 vector 0x21.
    ; ========================================================

    SET_IDT_ENTRY 0x21, keyboard_handler


    ; ========================================================
    ; Load IDT register
    ; ========================================================

    lidt [idt_pointer]

    ret
