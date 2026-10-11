
[bits 32]
[section .text]

global kernel_start

extern __bss_start
extern __bss_end

extern console_init
extern console_print
extern console_newline
extern console_get_cursor

extern serial_init
extern serial_print
extern serial_write_hex

extern pmm_init
extern pmm_alloc_page
extern pmm_free_page
extern pmm_get_free_pages

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
    cld

    ; Preserve bootloader handoff values.
    push eax
    push ebx
    push ecx

    ; Clear BSS before using zero-initialized variables.
    mov edi, __bss_start
    mov ecx, __bss_end
    sub ecx, edi
    xor eax, eax
    rep stosb

    ; Restore bootloader handoff values.
    pop ecx
    pop ebx
    pop eax

    ; Save the handoff values.
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

    ; Advance to the next 24-byte entry.
    add dword [e820_entry_ptr], 24
    inc dword [e820_index]
    jmp e820_print_loop

e820_print_done:
    mov esi, e820_ok_msg
    call serial_print

    ; Existing serial test.
    mov esi, serial_test_msg
    call serial_print
    mov eax, 0x1234ABCD
    call serial_write_hex
    mov esi, serial_newline
    call serial_print

    ; ========================================================
    ; Physical Memory Manager initialization and self-test.
    ; ========================================================

    mov esi, pmm_init_msg
    call serial_print

    ; pmm_init input:
    ; EAX = E820 map pointer
    ; EBX = E820 entry count
    mov eax, [e820_buffer]
    mov ebx, [e820_count]
    call pmm_init

    ; Record the initial free-page count.
    call pmm_get_free_pages
    mov [pmm_initial_free_pages], eax

    mov esi, pmm_free_initial_msg
    call serial_print
    mov eax, [pmm_initial_free_pages]
    call serial_write_hex
    mov esi, serial_newline
    call serial_print

    ; Allocate one physical page.
    call pmm_alloc_page
    test eax, eax
    jz pmm_alloc_failed

    mov [pmm_test_page], eax

    mov esi, pmm_alloc_msg
    call serial_print
    mov eax, [pmm_test_page]
    call serial_write_hex
    mov esi, serial_newline
    call serial_print

    ; Free the allocated page.
    mov eax, [pmm_test_page]
    call pmm_free_page
    cmp eax, 1
    jne pmm_free_failed

    mov esi, pmm_free_ok_msg
    call serial_print

    ; Check the free-page count after freeing.
    call pmm_get_free_pages

    mov esi, pmm_free_final_msg
    call serial_print
    call serial_write_hex
    mov esi, serial_newline
    call serial_print

    ; Allocation followed by freeing must restore the count.
    call pmm_get_free_pages
    cmp eax, [pmm_initial_free_pages]
    jne pmm_count_failed

    mov esi, pmm_test_pass_msg
    call serial_print

    ; ========================================================
    ; Existing VGA console and system initialization.
    ; ========================================================

    mov esi, title_msg
    call console_print
    call console_newline

    mov esi, status_msg
    call console_print
    call console_newline

    mov esi, arch_msg
    call console_print
    call console_newline

    ; Initialize interrupts and timing.
    call idt_init
    call pic_init
    call timer_init
    call time_init

    ; Unmask timer IRQ0 and keyboard IRQ1.
    in al, 0x21
    and al, 0xFC
    out 0x21, al

    ; Initialize the shell and display its prompt.
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

; ============================================================
; Failure handlers
; ============================================================

boot_handoff_failed:
    cli
    mov esi, handoff_error_msg
    call serial_print
    jmp failure_hang

pmm_alloc_failed:
    cli
    mov esi, pmm_alloc_error_msg
    call serial_print
    jmp failure_hang

pmm_free_failed:
    cli
    mov esi, pmm_free_error_msg
    call serial_print
    jmp failure_hang

pmm_count_failed:
    cli
    mov esi, pmm_count_error_msg
    call serial_print
    jmp failure_hang

failure_hang:
    hlt
    jmp failure_hang


[section .data]

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

pmm_init_msg:
    db "[PMM] Initializing physical memory manager...", 13, 10, 0

pmm_free_initial_msg:
    db "[PMM] Initial free pages: 0x", 0

pmm_alloc_msg:
    db "[PMM] Allocated physical page at: 0x", 0

pmm_free_ok_msg:
    db "[PMM] Page freed successfully.", 13, 10, 0

pmm_free_final_msg:
    db "[PMM] Free pages after test: 0x", 0

pmm_test_pass_msg:
    db "[PMM] Allocation/free test PASSED.", 13, 10, 0

pmm_alloc_error_msg:
    db "[PMM ERROR] Physical page allocation failed.", 13, 10, 0

pmm_free_error_msg:
    db "[PMM ERROR] Physical page free failed.", 13, 10, 0

pmm_count_error_msg:
    db "[PMM ERROR] Free-page count was not restored.", 13, 10, 0

serial_newline:
    db 13, 10, 0


[section .bss]

alignb 4
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

pmm_initial_free_pages:
    resd 1

pmm_test_page:
    resd 1
