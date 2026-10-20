
[bits 16]
[org 0x8000]

%define E820_BUFFER         0x9100
%define E820_COUNT          0x9000
%define E820_MAX_ENTRIES    32
%define E820_ENTRY_SIZE     24
%define E820_SIGNATURE      0x534D4150
%define BOOT_DRIVE_HANDOFF  0x4FE0

start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00
    sti

    mov al, [BOOT_DRIVE_HANDOFF]
    mov [boot_drive], al

    ; Collect the BIOS E820 memory map.
    mov word [E820_COUNT], 0
    xor ebx, ebx
    mov di, E820_BUFFER

e820_next:
    cmp word [E820_COUNT], E820_MAX_ENTRIES
    jae e820_too_many

    ; Request a 24-byte SMAP entry.
    mov dword [es:di + 20], 1
    mov eax, 0xE820
    mov edx, E820_SIGNATURE
    mov ecx, E820_ENTRY_SIZE
    int 0x15
    jc e820_failed
    cmp eax, E820_SIGNATURE
    jne e820_failed
    cmp ecx, 20
    jb e820_failed

    ; Ignore entries marked as disabled.
    cmp ecx, 24
    jb e820_save
    test dword [es:di + 20], 1
    jz e820_continue

e820_save:
    inc word [E820_COUNT]
    add di, E820_ENTRY_SIZE

e820_continue:
    test ebx, ebx
    jnz e820_next

e820_done:
    cmp word [E820_COUNT], 0
    je e820_failed

    ; Load the kernel from LBA 5 to physical address 0x1000.
    mov ax, [E820_COUNT]
    push ax

    mov si, kernel_dap
    mov dl, [boot_drive]
    mov ah, 0x42
    int 0x13
    jc disk_failed

    pop cx

    cli
    lgdt [gdt_descriptor]

    mov eax, cr0
    or eax, 1
    mov cr0, eax

    jmp 0x08:protected_mode

e820_too_many:
    ; More entries remain after reaching the supported limit.
    test ebx, ebx
    jnz e820_failed
    jmp e820_done

e820_failed:
    mov si, e820_error
    call print_error
    jmp halt

disk_failed:
    mov si, disk_error
    call print_error
    jmp halt

print_error:
    lodsb
    test al, al
    jz print_error_done
    mov ah, 0x0E
    int 0x10
    jmp print_error

print_error_done:
    ret

halt:
    cli
.hang:
    hlt
    jmp .hang

align 8
gdt_start:
    dq 0x0000000000000000
    dq 0x00CF9A000000FFFF
    dq 0x00CF92000000FFFF
gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1
    dd gdt_start

[bits 32]
protected_mode:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov esp, 0x90000
    cld

    ; Boot protocol:
    ; EAX = 0x564F534D ("VOSM")
    ; EBX = E820 buffer physical address
    ; ECX = number of valid entries
    mov eax, 0x564F534D
    mov ebx, E820_BUFFER
    movzx ecx, cx
    jmp 0x08:0x1000

e820_error:
    db "VertexOS: E820 memory detection failed!", 13, 10, 0

disk_error:
    db "VertexOS: kernel disk read failed!", 13, 10, 0

boot_drive:
    db 0

align 4
kernel_dap:
    db 0x10, 0
    dw 33
    dw 0x1000
    dw 0x0000
    dq 5

times 2048 - ($ - $$) db 0
