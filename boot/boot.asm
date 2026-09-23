[bits 16]
[org 0x7C00]

start:
    cli

    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00

    sti

    mov [boot_drive], dl

    mov si, boot_msg
    call print_string

    ; Load kernel from disk
    mov ah, 0x02
    mov al, 1
    mov ch, 0
    mov cl, 2
    mov dh, 0
    mov dl, [boot_drive]

    mov bx, 0x1000
    int 0x13

    jc disk_error

    ; Jump to kernel
    jmp 0x0000:0x1000


disk_error:
    mov si, error_msg
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


boot_drive db 0

boot_msg db "Welcome to VertexOS!", 13, 10, 0
error_msg db "Disk read error!", 13, 10, 0


times 510 - ($ - $$) db 0
dw 0xAA55
