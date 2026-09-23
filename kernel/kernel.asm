[bits 16]
[org 0x1000]

start:
    mov si, kernel_msg
    call print_string

.hang:
    cli
    hlt
    jmp .hang


print_string:
    lodsb
    cmp al, 0
    je .done

    mov ah, 0x0E
    mov bh, 0x00
    mov bl, 0x07
    int 0x10

    jmp print_string

.done:
    ret


kernel_msg db "Hello from VertexOS Kernel!", 0
