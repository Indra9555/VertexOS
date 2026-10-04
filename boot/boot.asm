[bits 16]
[org 0x7C00]

start:
    cli

    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00

    mov [boot_drive], dl

    sti

    mov si, boot_msg
    call print_string


    ; ========================================================
    ; Load kernel from disk
    ;
    ; Boot sector = sector 1
    ; Kernel starts at sector 2
    ;
    ; 32 sectors × 512 bytes = 16384 bytes
    ;
    ; Kernel is loaded at physical address 0x1000.
    ; ========================================================

    mov ah, 0x02
    mov al, 32
    mov ch, 0
    mov cl, 2
    mov dh, 0
    mov dl, [boot_drive]

    mov bx, 0x1000

    int 0x13

    jc disk_error


    ; ========================================================
    ; Enter 32-bit protected mode
    ; ========================================================

    cli

    lgdt [gdt_descriptor]

    mov eax, cr0
    or eax, 0x01
    mov cr0, eax

    jmp 0x08:protected_mode


; ============================================================
; Disk read error
; ============================================================

disk_error:

    mov si, error_msg
    call print_string

.hang:
    cli
    hlt
    jmp .hang


; ============================================================
; BIOS text output
; ============================================================

print_string:

    lodsb

    test al, al
    jz .done

    mov ah, 0x0E
    mov bh, 0x00
    mov bl, 0x07

    int 0x10

    jmp print_string

.done:
    ret


; ============================================================
; 32-bit protected mode
; ============================================================

[bits 32]

protected_mode:

    mov ax, 0x10

    mov ds, ax
    mov es, ax
    mov ss, ax

    mov esp, 0x90000

    jmp 0x08:0x1000


; ============================================================
; Boot data
; ============================================================

boot_drive db 0

boot_msg:
    db "Welcome to VertexOS!", 13, 10, 0

error_msg:
    db "Disk read error!", 13, 10, 0


; ============================================================
; Global Descriptor Table
; ============================================================

align 8

gdt_start:

    dq 0

    ; Code segment
    dq 0x00CF9A000000FFFF

    ; Data segment
    dq 0x00CF92000000FFFF

gdt_end:


gdt_descriptor:

    dw gdt_end - gdt_start - 1
    dd gdt_start


; ============================================================
; Boot sector signature
; ============================================================

times 510 - ($ - $$) db 0

dw 0xAA55
