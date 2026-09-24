; ============================================================
; VertexOS Bootloader
; Loads the kernel and switches the CPU to 32-bit Protected Mode
; ============================================================

[bits 16]
[org 0x7C00]

start:
    ; --------------------------------------------------------
    ; Initialize CPU / segment registers
    ; --------------------------------------------------------

    cli

    xor ax, ax

    mov ds, ax
    mov es, ax
    mov ss, ax

    ; Stack grows downward from 0x7C00
    mov sp, 0x7C00

    ; Save BIOS boot drive number
    mov [boot_drive], dl

    sti


    ; --------------------------------------------------------
    ; Display boot message
    ; --------------------------------------------------------

    mov si, boot_msg
    call print_string


    ; --------------------------------------------------------
    ; Load Kernel from Disk
    ;
    ; BIOS loads the kernel from:
    ; Cylinder 0
    ; Head 0
    ; Sector 2
    ;
    ; Kernel is loaded at physical address 0x1000
    ; --------------------------------------------------------

    mov ah, 0x02        ; BIOS disk read function
    mov al, 5           ; Read 2 sectors
    mov ch, 0           ; Cylinder 0
    mov cl, 2           ; Start at sector 2
    mov dh, 0           ; Head 0
    mov dl, [boot_drive]

    mov bx, 0x1000      ; ES:BX = 0000:1000

    int 0x13

    ; Carry flag = disk read failed
    jc disk_error


    ; --------------------------------------------------------
    ; Enter Protected Mode
    ; --------------------------------------------------------

    cli

    ; Load Global Descriptor Table
    lgdt [gdt_descriptor]


    ; Enable Protected Mode
    mov eax, cr0
    or eax, 0x01
    mov cr0, eax


    ; Far jump
    ;
    ; 0x08 = GDT Code Segment
    ; protected_mode = 32-bit code
    ;
    jmp 0x08:protected_mode


; ============================================================
; Disk Error
; ============================================================

disk_error:

    mov si, error_msg
    call print_string

.hang:
    cli
    hlt
    jmp .hang


; ============================================================
; Real Mode String Printing
;
; Uses BIOS interrupt 10h
; AH = 0Eh -> Teletype output
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
; 32-bit Protected Mode
; ============================================================

[bits 32]

protected_mode:

    ; --------------------------------------------------------
    ; Load Data Segment
    ;
    ; 0x10 = GDT Data Segment
    ; --------------------------------------------------------

    mov ax, 0x10

    mov ds, ax
    mov es, ax
    mov ss, ax


    ; --------------------------------------------------------
    ; Create 32-bit stack
    ; --------------------------------------------------------

    mov esp, 0x90000


    ; --------------------------------------------------------
    ; Jump to Kernel
    ;
    ; 0x08 = GDT Code Segment
    ; 0x1000 = Kernel address
    ; --------------------------------------------------------

    jmp 0x08:0x1000


; ============================================================
; Data
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

    ; --------------------------------------------------------
    ; GDT Entry 0: Null Descriptor
    ; --------------------------------------------------------

    dq 0x0000000000000000


    ; --------------------------------------------------------
    ; GDT Entry 1: Code Segment
    ;
    ; Selector = 0x08
    ; Base     = 0x00000000
    ; Limit    = 0xFFFFF
    ; 32-bit
    ; 4 KB granularity
    ; Readable code
    ; --------------------------------------------------------

    dq 0x00CF9A000000FFFF


    ; --------------------------------------------------------
    ; GDT Entry 2: Data Segment
    ;
    ; Selector = 0x10
    ; Base     = 0x00000000
    ; Limit    = 0xFFFFF
    ; 32-bit
    ; 4 KB granularity
    ; Read/write data
    ; --------------------------------------------------------

    dq 0x00CF92000000FFFF


gdt_end:


; ============================================================
; GDT Descriptor
; ============================================================

gdt_descriptor:

    ; GDT size - 1
    dw gdt_end - gdt_start - 1

    ; GDT physical address
    dd gdt_start


; ============================================================
; Boot Sector Padding
;
; BIOS requires:
;   First sector = exactly 512 bytes
;   Last two bytes = 0xAA55
; ============================================================

times 510 - ($ - $$) db 0

dw 0xAA55
