[bits 32]
[section .text]

; ============================================================
; VertexOS Programmable Interrupt Controller (PIC)
; ============================================================

global pic_init


; ============================================================
; PIC ports
; ============================================================

PIC1_COMMAND equ 0x20
PIC1_DATA    equ 0x21

PIC2_COMMAND equ 0xA0
PIC2_DATA    equ 0xA1


; ============================================================
; pic_init
;
; Remaps the master/slave PIC:
;
; Master IRQs: 0-7   → vectors 0x20-0x27
; Slave  IRQs: 8-15  → vectors 0x28-0x2F
;
; Initially masks every IRQ.
; Keyboard IRQ1 will be enabled later.
; ============================================================

pic_init:

    ; --------------------------------------------------------
    ; Start PIC initialization sequence
    ; ICW1 = 0x11
    ; --------------------------------------------------------

    mov al, 0x11

    out PIC1_COMMAND, al
    out PIC2_COMMAND, al


    ; --------------------------------------------------------
    ; ICW2
    ;
    ; Master IRQ0 → interrupt vector 0x20
    ; Slave  IRQ8 → interrupt vector 0x28
    ; --------------------------------------------------------

    mov al, 0x20
    out PIC1_DATA, al

    mov al, 0x28
    out PIC2_DATA, al


    ; --------------------------------------------------------
    ; ICW3
    ;
    ; Master: slave connected to IRQ2
    ; Slave: identity = 2
    ; --------------------------------------------------------

    mov al, 0x04
    out PIC1_DATA, al

    mov al, 0x02
    out PIC2_DATA, al


    ; --------------------------------------------------------
    ; ICW4
    ;
    ; 8086/88 mode
    ; --------------------------------------------------------

    mov al, 0x01

    out PIC1_DATA, al
    out PIC2_DATA, al


    ; --------------------------------------------------------
    ; Mask all IRQs
    ; --------------------------------------------------------

    mov al, 0xFF

    out PIC1_DATA, al
    out PIC2_DATA, al

    ret
