
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

%define PMM_MAX_MEMORY 0x08000000

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

    ; Restore handoff values.
    pop ecx
    pop ebx
    pop eax

    mov [boot_magic], eax
    mov [e820_buffer], ebx
    mov [e820_count], ecx

    call console_init
    call serial_init

    ; Print and validate boot handoff.
    mov esi, handoff_msg
    call serial_print
    mov eax, [boot_magic]
    call serial_write_hex
    mov esi, serial_newline
    call serial_print

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

    mov dword [e820_index], 0
    mov dword [e820_entry_ptr], 0x9100

e820_print_loop:
    mov eax, [e820_index]
    cmp eax, [e820_count]
    jae e820_print_done

    mov esi, e820_entry_msg
    call serial_print
    mov eax, [e820_index]
    call serial_write_hex

    ; Base address, high then low.
    mov esi, e820_base_msg
    call serial_print
    mov esi, [e820_entry_ptr]
    mov eax, [esi + 4]
    call serial_write_hex
    mov esi, [e820_entry_ptr]
    mov eax, [esi]
    call serial_write_hex

    ; Region length, high then low.
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

    ; ========================================================
    ; Initialize the Physical Memory Manager.
    ; ========================================================

    mov esi, pmm_init_msg
    call serial_print

    mov eax, [e820_buffer]
    mov ebx, [e820_count]
    call pmm_init

    call pmm_get_free_pages
    mov [pmm_initial_free_pages], eax

    mov esi, pmm_initial_msg
    call serial_print
    mov eax, [pmm_initial_free_pages]
    call serial_write_hex
    mov esi, serial_newline
    call serial_print

    ; ========================================================
    ; Test 1: Allocate one page.
    ; ========================================================

    call pmm_alloc_page
    test eax, eax
    jz pmm_alloc_failed

    mov [pmm_page_a], eax

    mov esi, pmm_alloc_msg
    call serial_print
    mov eax, [pmm_page_a]
    call serial_write_hex
    mov esi, serial_newline
    call serial_print

    ; ========================================================
    ; Test 2: Reject an unaligned free.
    ; Freeing page_address + 1 must fail.
    ; ========================================================

    mov eax, [pmm_page_a]
    inc eax
    call pmm_free_page

    test eax, eax
    jnz pmm_invalid_free_failed

    ; The page remains allocated: free count = initial - 1.
    call pmm_get_free_pages
    mov edx, [pmm_initial_free_pages]
    dec edx
    cmp eax, edx
    jne pmm_count_failed

    mov esi, pmm_invalid_pass_msg
    call serial_print

    ; ========================================================
    ; Test 3: Reject a free at the exclusive 128 MiB limit.
    ; ========================================================

    mov eax, PMM_MAX_MEMORY
    call pmm_free_page

    test eax, eax
    jnz pmm_invalid_free_failed

    call pmm_get_free_pages
    cmp eax, edx
    jne pmm_count_failed

    mov esi, pmm_range_pass_msg
    call serial_print

    ; ========================================================
    ; Test 4: Free the real page successfully.
    ; ========================================================

    mov eax, [pmm_page_a]
    call pmm_free_page

    cmp eax, 1
    jne pmm_free_failed

    ; ========================================================
    ; Test 5: Reject a double free.
    ; ========================================================

    mov eax, [pmm_page_a]
    call pmm_free_page

    test eax, eax
    jnz pmm_double_free_failed

    call pmm_get_free_pages
    cmp eax, [pmm_initial_free_pages]
    jne pmm_count_failed

    mov esi, pmm_double_pass_msg
    call serial_print

    ; ========================================================
    ; Test 6: Allocate three distinct physical pages.
    ; ========================================================

    call pmm_alloc_page
    test eax, eax
    jz pmm_alloc_failed
    mov [pmm_page_a], eax

    call pmm_alloc_page
    test eax, eax
    jz pmm_alloc_failed
    mov [pmm_page_b], eax

    call pmm_alloc_page
    test eax, eax
    jz pmm_alloc_failed
    mov [pmm_page_c], eax

    ; A, B, and C must all differ.
    mov eax, [pmm_page_a]
    cmp eax, [pmm_page_b]
    je pmm_duplicate_page_failed

    cmp eax, [pmm_page_c]
    je pmm_duplicate_page_failed

    mov eax, [pmm_page_b]
    cmp eax, [pmm_page_c]
    je pmm_duplicate_page_failed

    ; Verify the free count decreased by three.
    call pmm_get_free_pages
    mov edx, [pmm_initial_free_pages]
    sub edx, 3
    cmp eax, edx
    jne pmm_count_failed

    mov esi, pmm_multi_pass_msg
    call serial_print

    ; ========================================================
    ; Test 7: Free all three pages.
    ; ========================================================

    mov eax, [pmm_page_a]
    call pmm_free_page
    cmp eax, 1
    jne pmm_free_failed

    mov eax, [pmm_page_b]
    call pmm_free_page
    cmp eax, 1
    jne pmm_free_failed

    mov eax, [pmm_page_c]
    call pmm_free_page
    cmp eax, 1
    jne pmm_free_failed

    ; Verify the original count is restored.
    call pmm_get_free_pages
    cmp eax, [pmm_initial_free_pages]
    jne pmm_count_failed

    mov esi, pmm_final_msg
    call serial_print
    mov eax, [pmm_initial_free_pages]
    call serial_write_hex
    mov esi, serial_newline
    call serial_print

    mov esi, pmm_test_pass_msg
    call serial_print

    ; ========================================================
    ; Existing VGA console, interrupts, timer, and shell.
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

pmm_invalid_free_failed:
    cli
    mov esi, pmm_invalid_error_msg
    call serial_print
    jmp failure_hang

pmm_double_free_failed:
    cli
    mov esi, pmm_double_error_msg
    call serial_print
    jmp failure_hang

pmm_duplicate_page_failed:
    cli
    mov esi, pmm_duplicate_error_msg
    call serial_print
    jmp failure_hang

pmm_count_failed:
    cli
    mov esi, pmm_count_error_msg
    call serial_print

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
    db "[PMM] Initializing physical memory manager.", 13, 10, 0

pmm_initial_msg:
    db "[PMM] Initial free pages: 0x", 0

pmm_alloc_msg:
    db "[PMM] Allocated physical page: 0x", 0

pmm_invalid_pass_msg:
    db "[PMM TEST] Unaligned free rejected: PASS", 13, 10, 0

pmm_range_pass_msg:
    db "[PMM TEST] Out-of-range free rejected: PASS", 13, 10, 0

pmm_double_pass_msg:
    db "[PMM TEST] Double free rejected: PASS", 13, 10, 0

pmm_multi_pass_msg:
    db "[PMM TEST] Three distinct pages allocated: PASS", 13, 10, 0

pmm_final_msg:
    db "[PMM] Final free-page count: 0x", 0

pmm_test_pass_msg:
    db "[PMM] All regression tests PASSED.", 13, 10, 0

pmm_alloc_error_msg:
    db "[PMM ERROR] Physical page allocation failed.", 13, 10, 0

pmm_free_error_msg:
    db "[PMM ERROR] Physical page free failed.", 13, 10, 0

pmm_invalid_error_msg:
    db "[PMM ERROR] Invalid free was incorrectly accepted.", 13, 10, 0

pmm_double_error_msg:
    db "[PMM ERROR] Double free was incorrectly accepted.", 13, 10, 0

pmm_duplicate_error_msg:
    db "[PMM ERROR] Allocator returned duplicate pages.", 13, 10, 0

pmm_count_error_msg:
    db "[PMM ERROR] Free-page count mismatch.", 13, 10, 0

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

pmm_page_a:
    resd 1

pmm_page_b:
    resd 1

pmm_page_c:
    resd 1
