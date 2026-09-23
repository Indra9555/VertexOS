[bits 32]
[org 0x1000]

start:

    ; ----------------------------------------
    ; Clear the VGA text screen
    ; ----------------------------------------

    mov edi, 0xB8000
    mov ecx, 80 * 25
    mov ax, 0x0720

.clear_screen:
    mov [edi], ax
    add edi, 2
    loop .clear_screen


    ; ----------------------------------------
    ; Print VertexOS title
    ; ----------------------------------------

    mov esi, title_msg
    mov edi, 0xB8000
    call print_string


    ; ----------------------------------------
    ; Print status message
    ; ----------------------------------------

    mov esi, status_msg
    mov edi, 0xB80A0
    call print_string


    ; ----------------------------------------
    ; Print architecture information
    ; ----------------------------------------

    mov esi, arch_msg
    mov edi, 0xB8140
    call print_string


    ; ----------------------------------------
    ; Kernel finished
    ; ----------------------------------------

.hang:
    cli
    hlt
    jmp .hang


; ========================================
; print_string
;
; ESI = address of string
; EDI = VGA destination
; ========================================

print_string:

.next_char:

    lodsb

    test al, al
    jz .done

    mov [edi], al

    ; White text on black background
    mov byte [edi + 1], 0x0F

    add edi, 2

    jmp .next_char

.done:
    ret


; ========================================
; Messages
; ========================================

title_msg db "VertexOS - Protected Mode Kernel", 0

status_msg db "Kernel loaded successfully.", 0

arch_msg db "Architecture: x86 32-bit Protected Mode", 0
