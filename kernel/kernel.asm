[bits 32]
[section .text]

global kernel_start

extern idt_init
extern pic_init
extern keyboard_print_prompt
extern shell_init
extern shell_update


; ============================================================
; VertexOS Kernel Entry Point
; ============================================================

kernel_start:

    ; --------------------------------------------------------
    ; Clear VGA text screen
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
    ; Initialize IDT
    ; --------------------------------------------------------

    call idt_init


    ; --------------------------------------------------------
    ; Initialize PIC
    ; --------------------------------------------------------

    call pic_init


    ; --------------------------------------------------------
    ; Enable keyboard IRQ1
    ; --------------------------------------------------------

    in al, 0x21

    and al, 0xFD

    out 0x21, al


    ; --------------------------------------------------------
    ; Initialize shell
    ; --------------------------------------------------------

    call shell_init


    ; --------------------------------------------------------
    ; Print initial shell prompt
    ; --------------------------------------------------------

    call keyboard_print_prompt


    ; --------------------------------------------------------
    ; Enable CPU interrupts
    ; --------------------------------------------------------

    sti


    ; --------------------------------------------------------
    ; Main kernel loop
    ; --------------------------------------------------------

.hang:

    call shell_update

    hlt

    jmp .hang


; ============================================================
; print_string
;
; ESI = source string
; EDI = VGA destination
; ============================================================

print_string:

.next_char:

    lodsb

    test al, al

    jz .done

    mov [edi], al

    mov byte [edi + 1], 0x0F

    add edi, 2

    jmp .next_char


.done:

    ret


; ============================================================
; Kernel Messages
; ============================================================

title_msg:

    db "VertexOS - Protected Mode Kernel", 0


status_msg:

    db "Kernel loaded successfully.", 0


arch_msg:

    db "Architecture: x86 32-bit Protected Mode", 0
