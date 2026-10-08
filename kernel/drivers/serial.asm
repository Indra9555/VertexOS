[bits 32]

section .text

global serial_init
global serial_write
global serial_print
global serial_write_hex


; ============================================================
; VertexOS Serial Driver
;
; PC COM1 UART
;
; Base port:
;
;   0x3F8
;
; Configuration:
;
;   Baud rate : 38400
;   Data bits : 8
;   Stop bits : 1
;   Parity    : None
;
; ============================================================


; ============================================================
; COM1 PORTS
; ============================================================

COM1_BASE       equ 0x3F8

COM1_DATA       equ COM1_BASE + 0
COM1_IER        equ COM1_BASE + 1
COM1_FCR        equ COM1_BASE + 2
COM1_LCR        equ COM1_BASE + 3
COM1_MCR        equ COM1_BASE + 4
COM1_LSR        equ COM1_BASE + 5


; ============================================================
; LINE STATUS REGISTER
; ============================================================

LSR_DATA_READY  equ 0x01
LSR_EMPTY       equ 0x20


; ============================================================
; serial_init
;
; Initialize COM1.
;
; Configuration:
;
;   38400 baud
;   8 data bits
;   1 stop bit
;   No parity
;
; ============================================================

serial_init:

    ; --------------------------------------------------------
    ; Disable all serial interrupts.
    ; --------------------------------------------------------

    mov dx, COM1_IER

    mov al, 0x00

    out dx, al


    ; --------------------------------------------------------
    ; Enable Divisor Latch Access Bit.
    ; --------------------------------------------------------

    mov dx, COM1_LCR

    mov al, 0x80

    out dx, al


    ; --------------------------------------------------------
    ; Set baud rate divisor.
    ;
    ; UART clock = 115200 Hz
    ;
    ; 115200 / 38400 = 3
    ; --------------------------------------------------------

    mov dx, COM1_DATA

    mov al, 0x03

    out dx, al


    mov dx, COM1_IER

    mov al, 0x00

    out dx, al


    ; --------------------------------------------------------
    ; Disable Divisor Latch Access.
    ;
    ; 8 data bits
    ; 1 stop bit
    ; no parity
    ; --------------------------------------------------------

    mov dx, COM1_LCR

    mov al, 0x03

    out dx, al


    ; --------------------------------------------------------
    ; Enable FIFO.
    ;
    ; FIFO enabled
    ; Clear RX FIFO
    ; Clear TX FIFO
    ; 14-byte threshold
    ; --------------------------------------------------------

    mov dx, COM1_FCR

    mov al, 0xC7

    out dx, al


    ; --------------------------------------------------------
    ; Configure modem control.
    ;
    ; DTR enabled
    ; RTS enabled
    ; OUT2 enabled
    ; --------------------------------------------------------

    mov dx, COM1_MCR

    mov al, 0x0B

    out dx, al

    ret


; ============================================================
; serial_write
;
; Write one character.
;
; Input:
;
;   AL = character
;
; Preserves:
;
;   EAX
;   EDX
;
; ============================================================

serial_write:

    ; --------------------------------------------------------
    ; Preserve caller registers.
    ;
    ; Stack layout:
    ;
    ;   [ESP + 0] = original EDX
    ;   [ESP + 4] = original EAX
    ; --------------------------------------------------------

    push eax
    push edx


serial_write_wait:

    ; --------------------------------------------------------
    ; Wait until transmitter holding register is empty.
    ; --------------------------------------------------------

    mov dx, COM1_LSR

    in al, dx

    test al, LSR_EMPTY

    jz serial_write_wait


    ; --------------------------------------------------------
    ; Recover original character.
    ;
    ; The original EAX is still stored at [ESP + 4].
    ; --------------------------------------------------------

    mov eax, [esp + 4]


    ; --------------------------------------------------------
    ; Send character.
    ; --------------------------------------------------------

    mov dx, COM1_DATA

    out dx, al


    ; --------------------------------------------------------
    ; Restore caller registers.
    ; --------------------------------------------------------

    pop edx
    pop eax

    ret


; ============================================================
; serial_print
;
; Print null-terminated string.
;
; Input:
;
;   ESI = string address
;
; ============================================================

serial_print:

    push eax


serial_print_loop:

    lodsb

    test al, al

    jz serial_print_done

    call serial_write

    jmp serial_print_loop


serial_print_done:

    pop eax

    ret


; ============================================================
; serial_write_hex
;
; Print a 32-bit value as 8 hexadecimal digits.
;
; Input:
;
;   EAX = unsigned 32-bit value
;
; Example:
;
;   EAX = 0x1234ABCD
;
; Output:
;
;   1234ABCD
;
; ============================================================

serial_write_hex:

    push eax
    push ebx
    push ecx
    push edx


    mov ebx, eax

    mov ecx, 8


serial_hex_loop:

    ; --------------------------------------------------------
    ; Extract most significant nibble.
    ; --------------------------------------------------------

    mov eax, ebx

    shr eax, 28

    and eax, 0x0F


    ; --------------------------------------------------------
    ; Convert nibble to ASCII.
    ; --------------------------------------------------------

    cmp al, 9

    jbe serial_hex_digit

    add al, 'A' - 10

    jmp serial_hex_output


serial_hex_digit:

    add al, '0'


serial_hex_output:

    call serial_write


    ; --------------------------------------------------------
    ; Move next nibble into most significant position.
    ; --------------------------------------------------------

    shl ebx, 4

    loop serial_hex_loop


    pop edx
    pop ecx
    pop ebx
    pop eax

    ret
