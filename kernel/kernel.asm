
[bits 32]
[section .text]

global kernel_start

extern console_init
extern console_print
extern console_newline
extern console_get_cursor

extern serial_init
extern serial_print
extern serial_write_hex

extern idt_init
extern pic_init

extern timer_init
extern time_init

extern keyboard_print_prompt
extern keyboard_set_cursor

extern shell_init
extern shell_update

kernel_start:
    cli

    ; Capture bootloader handoff.
    mov [boot_magic], eax
    mov [e820_buffer], ebx
    mov [e820_count], ecx

    call console_init
    call serial_init

    ; Print boot magic.
    mov esi, handoff_msg
    call serial_print
    mov eax, [boot_magic]
    call serial_write_hex
    mov esi, serial_newline
    call serial_print

    ; Validate handoff metadata.
    cmp dword [boot_magic], 0x564F534D
    jne boot_handoff_failed

    cmp dword [e820_buffer], 0x9100
    jne boot_handoff_failed

    cmp dword [e820_count], 1
    jb boot_handoff_failed

    cmp dword [e820_count], 32
    ja boot_handoff_failed

    ; Print E820 entry count.
    mov esi, e820_count_msg
    call serial_print
    mov eax, [e820_count]
    call serial_write_hex
    mov esi, serial_newline
    call serial_print

    ; Initialize E820 iteration state.
    mov dword [e820_index], 0
    mov dword [e820_entry_ptr], 0x9100

e820_print_loop:
    mov eax, [e820_index]
    cmp eax, [e820_count]
    jae e820_print_done

    ; Entry number.
    mov esi, e820_entry_msg
    call serial_print
    mov eax, [e820_index]
    call serial_write_hex

    ; 64-bit base address: high word, then low word.
    mov esi, e820_base_msg
    call serial_print

    mov esi, [e820_entry_ptr]
    mov eax, [esi + 4]
    call serial_write_hex

    mov esi, [e820_entry_ptr]
    mov eax, [esi]
    call serial_write_hex

    ; 64-bit region length: high word, then low word.
    mov esi, e820_length_msg
    call serial_print

    mov esi, [e820_entry_ptr]
    mov eax, [esi + 12]
    call serial_write_hex

    mov esi, [e820_entry_ptr]
    mov eax, [esi + 8]
    call serial_write_hex

    ; Memory type.
    mov esi, e820_type_msg
    call serial_print

    mov esi, [e820_entry_ptr]
    mov eax, [esi + 16]
    call serial_write_hex

    ; Extended attributes.
    mov esi, e820_attr_msg
    call serial_print

    mov esi, [e820_entry_ptr]
    mov eax, [esi + 20]
    call serial_write_hex

    mov esi, serial_newline
    call serial_print

    ; Move to the next 24-byte entry.
    add dword [e820_entry_ptr], 24
    inc dword [e820_index]
    jmp e820_print_loop

e820_print_done:
    mov esi, e820_ok_msg
    call serial_print

    mov esi, serial_test_msg
    call serial_print
    mov eax, 0x1234ABCD
    call serial_write_hex
    mov esi, serial_newline
    call serial_print

    ; Existing VGA console output.
    mov esi, title_msg
    call console_print
    call console_newline

    mov esi, status_msg
    call console_print
    call console_newline

    mov esi, arch_msg
    call console_print
    call console_newline

    ; Existing interrupt and timing initialization.
    call idt_init
    call pic_init
    call timer_init
    call time_init

    ; Unmask timer IRQ0 and keyboard IRQ1.
    in al, 0x21
    and al, 0xFC
    out 0x21, al

    call shell_init
    call shell_print_initial_prompt

    sti

kernel_loop:
    call shell_update
    hlt
    jmp kernel_loop

shell_print_initial_prompt:
    call console_get_cursor
    call keyboard_set_cursor
    call keyboard_print_prompt
    ret

boot_handoff_failed:
    cli
    mov esi, handoff_error_msg
    call serial_print

boot_handoff_hang:
    hlt
    jmp boot_handoff_hang

section .data

title_msg:
    db "VertexOS - Protected Mode Kernel", 0

status_msg:
    db "Kernel loaded successfully.", 0

arch_msg:
    db "Architecture: x86 32-bit Protected Mode", 0

handoff_msg:
    db "[BOOT] Handoff magic: 0x", 0

e820_count_msg:
    db "[E820] Entry count: 0x", 0

e820_entry_msg:
    db "[E820] Entry ", 0

e820_base_msg:
    db " Base=0x", 0

e820_length_msg:
    db " Length=0x", 0

e820_type_msg:
    db " Type=0x", 0

e820_attr_msg:
    db " Attr=0x", 0

e820_ok_msg:
    db "[E820] Map dump completed.", 13, 10, 0

handoff_error_msg:
    db "[BOOT ERROR] Invalid bootloader handoff or E820 metadata.", 13, 10, 0

serial_test_msg:
    db "[SERIAL] COM1 initialized. Test value: 0x", 0

serial_newline:
    db 13, 10, 0

section .bss

align 4
boot_magic:
    resd 1

e820_buffer:
    resd 1

e820_count:
    resd 1

e820_index:
    resd 1

e820_entry_ptr:
    resd 1
