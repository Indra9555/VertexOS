[bits 16]
[org 0x7C00]

%define BOOT_DRIVE_HANDOFF 0x4FE0

start:
    cli

    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00

    mov [boot_drive], dl
    mov [BOOT_DRIVE_HANDOFF], dl

    sti

    mov si, boot_msg
    call print_string

    ; Check BIOS extended disk support.
    mov ah, 0x41
    mov bx, 0x55AA
    mov dl, [boot_drive]
    int 0x13
    jc disk_error

    cmp bx, 0xAA55
    jne disk_error

    test cx, 1
    jz disk_error

    ; Load stage 2 from LBA 1 to physical 0x8000.
    mov si, boot_dap
    mov dl, [boot_drive]
    mov ah, 0x42
    int 0x13
    jc disk_error

    jmp 0x0000:0x8000

disk_error:
    mov si, error_msg
    call print_string

.hang:
    cli
    hlt
    jmp .hang

print_string:
    lodsb
    test al, al
    jz .done

    mov ah, 0x0E
    mov bh, 0
    mov bl, 0x07
    int 0x10
    jmp print_string

.done:
    ret

boot_drive:
    db 0

boot_msg:
    db "VertexOS: Loading stage 2...", 13, 10, 0

error_msg:
    db "VertexOS: Boot disk error!", 13, 10, 0

align 4

boot_dap:
    db 0x10, 0
    dw 4
    dw 0x8000
    dw 0
    dq 1

times 510 - ($ - $$) db 0
dw 0xAA55
