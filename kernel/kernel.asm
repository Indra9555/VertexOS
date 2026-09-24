[bits 32]
[section .text]

global kernel_start

extern idt_init
extern pic_init


; ============================================================
; VertexOS Kernel Entry Point
; ============================================================

kernel_start:

    ; --------------------------------------------------------
    ; Clear the VGA text screen
    ; --------------------------------------------------------

    mov edi, 0xB8000
    mov ecx, 80 * 25
    mov ax, 0x0720

.clear_screen:

    mov [edi], ax
    add edi, 2

    loop .clear_screen


    ; --------------------------------------------------------
    ; Print VertexOS title
    ; --------------------------------------------------------

    mov esi, title_msg
    mov edi, 0xB8000

    call print_string


    ; --------------------------------------------------------
    ; Print kernel status
    ; --------------------------------------------------------

    mov esi, status_msg
    mov edi, 0xB80A0

    call print_string


    ; --------------------------------------------------------
    ; Print architecture information
    ; --------------------------------------------------------

    mov esi, arch_msg
    mov edi, 0xB8140

    call print_string


    ; --------------------------------------------------------
    ; Initialize Interrupt Descriptor Table
    ; --------------------------------------------------------

    call idt_init


    ; --------------------------------------------------------
    ; Initialize Programmable Interrupt Controller
    ; --------------------------------------------------------

    call pic_init


    ; --------------------------------------------------------
    ; Enable keyboard IRQ1
    ;
    ; PIC master data port = 0x21
    ;
    ; IRQ1 corresponds to bit 1.
    ;
    ; 1 = masked
    ; 0 = enabled
    ;
    ; 11111111
    ;        ↑
    ;       IRQ1
    ;
    ; AND with 11111101 clears bit 1.
    ; --------------------------------------------------------

    in al, 0x21

    and al, 0xFD

    out 0x21, al


    ; --------------------------------------------------------
    ; Enable CPU interrupts
    ; --------------------------------------------------------

    sti


    ; --------------------------------------------------------
    ; Wait for hardware interrupts
    ; --------------------------------------------------------

.hang:

    hlt

    jmp .hang


; ============================================================
; print_string
;
; ESI = address of string
; EDI = VGA destination address
;
; VGA text mode:
;
; Character = [EDI]
; Attribute = [EDI + 1]
; ============================================================

print_string:

.next_char:

    lodsb

    test al, al

    jz .done


    ; Write character

    mov [edi], al


    ; White text on black background

    mov byte [edi + 1], 0x0F


    ; Move to next VGA character

    add edi, 2

    jmp .next_char


.done:

    ret


; ============================================================
; Kernel messages
; ============================================================

title_msg db "VertexOS - Protected Mode Kernel", 0

status_msg db "Kernel loaded successfully.", 0

arch_msg db "Architecture: x86 32-bit Protected Mode", 0
