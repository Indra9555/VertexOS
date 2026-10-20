
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

extern heap_init
extern kmalloc
extern kfree
extern heap_region_count
extern heap_region_bases

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
    ; PMM Test 1: Allocate one page.
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
    ; PMM Test 2: Reject an unaligned free.
    ; ========================================================

    mov eax, [pmm_page_a]
    inc eax
    call pmm_free_page

    test eax, eax
    jnz pmm_invalid_free_failed

    call pmm_get_free_pages
    mov edx, [pmm_initial_free_pages]
    dec edx
    cmp eax, edx
    jne pmm_count_failed

    mov esi, pmm_invalid_pass_msg
    call serial_print

    ; ========================================================
    ; PMM Test 3: Reject the exclusive 128 MiB limit.
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
    ; PMM Test 4: Free the real page successfully.
    ; ========================================================

    mov eax, [pmm_page_a]
    call pmm_free_page

    cmp eax, 1
    jne pmm_free_failed

    ; ========================================================
    ; PMM Test 5: Reject a double free.
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
    ; PMM Test 6: Allocate three distinct physical pages.
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

    mov eax, [pmm_page_a]
    cmp eax, [pmm_page_b]
    je pmm_duplicate_page_failed

    cmp eax, [pmm_page_c]
    je pmm_duplicate_page_failed

    mov eax, [pmm_page_b]
    cmp eax, [pmm_page_c]
    je pmm_duplicate_page_failed

    call pmm_get_free_pages
    mov edx, [pmm_initial_free_pages]
    sub edx, 3
    cmp eax, edx
    jne pmm_count_failed

    mov esi, pmm_multi_pass_msg
    call serial_print

    ; ========================================================
    ; PMM Test 7: Free all three pages.
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
    ; Heap Test 1: Initialize the heap.
    ; ========================================================

    mov esi, heap_init_msg
    call serial_print

    call heap_init
    cmp eax, 1
    jne heap_init_failed

    mov esi, heap_init_pass_msg
    call serial_print

    ; ========================================================
    ; Heap Test 2: Allocate three differently sized blocks.
    ; ========================================================

    mov eax, 32
    call kmalloc
    test eax, eax
    jz heap_alloc_failed
    mov [heap_ptr_a], eax

    mov eax, 64
    call kmalloc
    test eax, eax
    jz heap_alloc_failed
    mov [heap_ptr_b], eax

    mov eax, 96
    call kmalloc
    test eax, eax
    jz heap_alloc_failed
    mov [heap_ptr_c], eax

    ; Allocated payload pointers must be distinct.
    mov eax, [heap_ptr_a]
    cmp eax, [heap_ptr_b]
    je heap_test_failed

    cmp eax, [heap_ptr_c]
    je heap_test_failed

    mov eax, [heap_ptr_b]
    cmp eax, [heap_ptr_c]
    je heap_test_failed

    mov esi, heap_alloc_pass_msg
    call serial_print

    ; ========================================================
    ; Heap Test 3: Free B and reject a double free.
    ; ========================================================

    mov eax, [heap_ptr_b]
    call kfree
    cmp eax, 1
    jne heap_free_failed

    mov eax, [heap_ptr_b]
    call kfree
    test eax, eax
    jnz heap_double_free_failed

    mov esi, heap_double_pass_msg
    call serial_print

    ; ========================================================
    ; Heap Test 4: Reuse the freed B block.
    ; A 48-byte request fits into B's 80-byte block,
    ; but cannot split it into two usable blocks.
    ; ========================================================

    mov eax, 48
    call kmalloc
    test eax, eax
    jz heap_alloc_failed

    mov [heap_ptr_d], eax

    cmp eax, [heap_ptr_b]
    jne heap_reuse_failed

    mov esi, heap_reuse_pass_msg
    call serial_print

    ; Release all three live blocks.
    mov eax, [heap_ptr_a]
    call kfree
    cmp eax, 1
    jne heap_free_failed

    mov eax, [heap_ptr_d]
    call kfree
    cmp eax, 1
    jne heap_free_failed

    mov eax, [heap_ptr_c]
    call kfree
    cmp eax, 1
    jne heap_free_failed

    mov esi, heap_free_pass_msg
    call serial_print

    ; ========================================================
    ; Heap Test 5: Verify adjacent-block coalescing.
    ;
    ; Allocate A, B, C. Free A and B, then request 128
    ; bytes. A and B must merge into a 160-byte block.
    ; The 144-byte total request fits only after merging.
    ; ========================================================

    mov eax, 64
    call kmalloc
    test eax, eax
    jz heap_alloc_failed
    mov [heap_ptr_a], eax

    mov eax, 64
    call kmalloc
    test eax, eax
    jz heap_alloc_failed
    mov [heap_ptr_b], eax

    mov eax, 64
    call kmalloc
    test eax, eax
    jz heap_alloc_failed
    mov [heap_ptr_c], eax

    mov eax, [heap_ptr_a]
    call kfree
    cmp eax, 1
    jne heap_free_failed

    mov eax, [heap_ptr_b]
    call kfree
    cmp eax, 1
    jne heap_free_failed

    mov eax, 128
    call kmalloc
    test eax, eax
    jz heap_coalesce_failed

    mov [heap_ptr_d], eax

    ; First-fit should reuse the merged A+B region.
    cmp eax, [heap_ptr_a]
    jne heap_coalesce_failed

    mov esi, heap_coalesce_pass_msg
    call serial_print

    ; Free the merged allocation and the remaining C block.
    mov eax, [heap_ptr_d]
    call kfree
    cmp eax, 1
    jne heap_free_failed

    mov eax, [heap_ptr_c]
    call kfree
    cmp eax, 1
    jne heap_free_failed

    ; ========================================================
    ; Heap Test 6: The entire 4096-byte page must be reusable.
    ; A 4080-byte payload plus its 16-byte header consumes
    ; the entire heap page. This also verifies full coalescing.
    ; ========================================================

    mov eax, 4080
    call kmalloc
    test eax, eax
    jz heap_coalesce_failed

    mov [heap_ptr_d], eax

    mov esi, heap_full_page_pass_msg
    call serial_print

    mov eax, [heap_ptr_d]
    call kfree
    cmp eax, 1
    jne heap_free_failed

    ; ========================================================
    ; Heap Test: Corrupted block metadata must be rejected.
    ; ========================================================

    mov eax, 32
    call kmalloc
    test eax, eax
    jz heap_alloc_failed

    ; Save the allocated block header and its original size.
    sub eax, 16
    mov [heap_corrupt_header], eax
    mov ebx, [eax]
    mov [heap_corrupt_original_size], ebx

    ; An impossible, unaligned block size must be rejected.
    mov dword [eax], 0xFFFFFFF8
    mov eax, 8
    call kmalloc
    mov [heap_corrupt_result], eax

    ; Restore the header before doing any further heap operation.
    mov eax, [heap_corrupt_header]
    mov ebx, [heap_corrupt_original_size]
    mov [eax], ebx

    ; Allocation must have failed while metadata was corrupted.
    cmp dword [heap_corrupt_result], 0
    jne heap_metadata_failed

    ; The restored block must still be freeable.
    mov eax, [heap_corrupt_header]
    add eax, 16
    call kfree
    cmp eax, 1
    jne heap_metadata_failed

    ; --------------------------------------------------------
    ; Reject an invalid free flag (only 0 and 1 are valid).
    ; --------------------------------------------------------

    mov eax, [heap_corrupt_header]
    mov ebx, [eax + 4]
    mov dword [eax + 4], 2

    mov eax, 8
    call kmalloc
    mov [heap_corrupt_result], eax

    mov eax, [heap_corrupt_header]
    mov [eax + 4], ebx

    cmp dword [heap_corrupt_result], 0
    jne heap_metadata_failed

    ; kfree must also reject the corrupted region.
    mov eax, [heap_corrupt_header]
    mov ebx, [eax + 4]
    mov dword [eax + 4], 2

    mov eax, [heap_corrupt_header]
    add eax, 16
    call kfree
    mov [heap_corrupt_result], eax

    mov eax, [heap_corrupt_header]
    mov [eax + 4], ebx

    cmp dword [heap_corrupt_result], 0
    jne heap_metadata_failed

    ; --------------------------------------------------------
    ; Reject an invalid previous-block link.
    ; --------------------------------------------------------

    mov eax, [heap_corrupt_header]
    mov ebx, [eax + 8]
    mov dword [eax + 8], 0x12345678

    mov eax, 8
    call kmalloc
    mov [heap_corrupt_result], eax

    mov eax, [heap_corrupt_header]
    mov [eax + 8], ebx

    cmp dword [heap_corrupt_result], 0
    jne heap_metadata_failed

    mov eax, [heap_corrupt_header]
    mov ebx, [eax + 8]
    mov dword [eax + 8], 0x12345678

    mov eax, [heap_corrupt_header]
    add eax, 16
    call kfree
    mov [heap_corrupt_result], eax

    mov eax, [heap_corrupt_header]
    mov [eax + 8], ebx

    cmp dword [heap_corrupt_result], 0
    jne heap_metadata_failed

    ; --------------------------------------------------------
    ; Reject an invalid next-block link.
    ; --------------------------------------------------------

    mov eax, [heap_corrupt_header]
    mov ebx, [eax + 12]
    mov dword [eax + 12], 0x12345678

    mov eax, 8
    call kmalloc
    mov [heap_corrupt_result], eax

    mov eax, [heap_corrupt_header]
    mov [eax + 12], ebx

    cmp dword [heap_corrupt_result], 0
    jne heap_metadata_failed

    mov eax, [heap_corrupt_header]
    mov ebx, [eax + 12]
    mov dword [eax + 12], 0x12345678

    mov eax, [heap_corrupt_header]
    add eax, 16
    call kfree
    mov [heap_corrupt_result], eax

    mov eax, [heap_corrupt_header]
    mov [eax + 12], ebx

    cmp dword [heap_corrupt_result], 0
    jne heap_metadata_failed

    ; --------------------------------------------------------
    ; Reject an aligned, in-page but incorrect next-block link.
    ; --------------------------------------------------------

    mov eax, [heap_corrupt_header]
    mov ebx, [eax + 12]
    mov edx, [heap_corrupt_header]
    mov [eax + 12], edx

    mov eax, 8
    call kmalloc
    mov [heap_corrupt_result], eax

    ; Restore the original link before checking the result.
    mov eax, [heap_corrupt_header]
    mov [eax + 12], ebx

    cmp dword [heap_corrupt_result], 0
    jne heap_metadata_failed

    ; Repeat the corruption and verify kfree rejects it too.
    mov eax, [heap_corrupt_header]
    mov ebx, [eax + 12]
    mov edx, [heap_corrupt_header]
    mov [eax + 12], edx

    mov eax, [heap_corrupt_header]
    add eax, 16
    call kfree
    mov [heap_corrupt_result], eax

    mov eax, [heap_corrupt_header]
    mov [eax + 12], ebx

    cmp dword [heap_corrupt_result], 0
    jne heap_metadata_failed

    ; --------------------------------------------------------
    ; Reject an aligned, in-page but incorrect next-block link.
    ; --------------------------------------------------------

    mov eax, [heap_corrupt_header]
    mov ebx, [eax + 12]
    mov edx, [heap_corrupt_header]
    mov [eax + 12], edx

    mov eax, 8
    call kmalloc
    mov [heap_corrupt_result], eax

    ; Restore the original link before checking the result.
    mov eax, [heap_corrupt_header]
    mov [eax + 12], ebx

    cmp dword [heap_corrupt_result], 0
    jne heap_metadata_failed

    ; Repeat the corruption and verify kfree rejects it too.
    mov eax, [heap_corrupt_header]
    mov ebx, [eax + 12]
    mov edx, [heap_corrupt_header]
    mov [eax + 12], edx

    mov eax, [heap_corrupt_header]
    add eax, 16
    call kfree
    mov [heap_corrupt_result], eax

    mov eax, [heap_corrupt_header]
    mov [eax + 12], ebx

    cmp dword [heap_corrupt_result], 0
    jne heap_metadata_failed

    ; Verify the restored heap remains usable.
    mov eax, 16
    call kmalloc
    test eax, eax
    jz heap_metadata_failed

    call kfree
    cmp eax, 1
    jne heap_metadata_failed

    mov esi, heap_metadata_pass_msg
    call serial_print


    ; ========================================================
    ; Heap Test: Reject corrupted region registry counts.
    ; ========================================================

    ; Allocate a valid block that must remain freeable after
    ; the corrupted registry count is restored.
    mov eax, 16
    call kmalloc
    test eax, eax
    jz heap_test_failed
    mov [heap_ptr_d], eax

    ; Count zero: kmalloc and kfree must both reject it.
    mov eax, [heap_region_count]
    mov [heap_registry_original_count], eax
    mov dword [heap_region_count], 0

    mov eax, 8
    call kmalloc
    mov [heap_registry_kmalloc_result], eax

    mov eax, [heap_ptr_d]
    call kfree
    mov [heap_registry_kfree_result], eax

    mov eax, [heap_registry_original_count]
    mov [heap_region_count], eax

    cmp dword [heap_registry_kmalloc_result], 0
    jne heap_registry_failed
    cmp dword [heap_registry_kfree_result], 0
    jne heap_registry_failed

    mov eax, [heap_ptr_d]
    call kfree
    cmp eax, 1
    jne heap_free_failed

    ; Count above capacity: both APIs must reject it.
    mov eax, 16
    call kmalloc
    test eax, eax
    jz heap_test_failed
    mov [heap_ptr_d], eax

    mov eax, [heap_region_count]
    mov [heap_registry_original_count], eax
    mov dword [heap_region_count], 257

    mov eax, 8
    call kmalloc
    mov [heap_registry_kmalloc_result], eax

    mov eax, [heap_ptr_d]
    call kfree
    mov [heap_registry_kfree_result], eax

    mov eax, [heap_registry_original_count]
    mov [heap_region_count], eax

    cmp dword [heap_registry_kmalloc_result], 0
    jne heap_registry_failed
    cmp dword [heap_registry_kfree_result], 0
    jne heap_registry_failed

    ; Restored registry must still allow valid free operations.
    mov eax, [heap_ptr_d]
    call kfree
    cmp eax, 1
    jne heap_free_failed

    ; Reject an unaligned registered region base.
    mov eax, 16
    call kmalloc
    test eax, eax
    jz heap_registry_failed
    mov [heap_ptr_d], eax

    mov eax, [heap_region_bases]
    mov [heap_registry_original_base], eax
    mov dword [heap_region_bases], 0x00100001

    mov eax, 8
    call kmalloc
    mov [heap_registry_kmalloc_result], eax

    mov eax, [heap_ptr_d]
    call kfree
    mov [heap_registry_kfree_result], eax

    mov eax, [heap_registry_original_base]
    mov [heap_region_bases], eax

    cmp dword [heap_registry_kmalloc_result], 0
    jne heap_registry_failed
    cmp dword [heap_registry_kfree_result], 0
    jne heap_registry_failed

    mov eax, [heap_ptr_d]
    call kfree
    cmp eax, 1
    jne heap_registry_failed

    ; Reject a region base at the exclusive PMM upper bound.
    mov eax, 16
    call kmalloc
    test eax, eax
    jz heap_registry_failed
    mov [heap_ptr_d], eax

    mov eax, [heap_region_bases]
    mov [heap_registry_original_base], eax
    mov dword [heap_region_bases], 0x08000000

    mov eax, 8
    call kmalloc
    mov [heap_registry_kmalloc_result], eax

    mov eax, [heap_ptr_d]
    call kfree
    mov [heap_registry_kfree_result], eax

    mov eax, [heap_registry_original_base]
    mov [heap_region_bases], eax

    cmp dword [heap_registry_kmalloc_result], 0
    jne heap_registry_failed
    cmp dword [heap_registry_kfree_result], 0
    jne heap_registry_failed

    mov eax, [heap_ptr_d]
    call kfree
    cmp eax, 1
    jne heap_registry_failed

    mov esi, heap_registry_pass_msg
    call serial_print

    ; ========================================================
    ; Heap Test 7: Reject invalid allocation/free requests.
    ; ========================================================

    ; kmalloc(0) must fail.
    xor eax, eax
    call kmalloc
    test eax, eax
    jnz heap_test_failed

    ; An overflowing request must fail.
    mov eax, 0xFFFFFFFF
    call kmalloc
    test eax, eax
    jnz heap_test_failed

    ; An oversized request must fail without consuming a page.
    ; 4081 bytes + 16-byte header exceeds the 4096-byte limit.
    call pmm_get_free_pages
    push eax

    mov eax, 4081
    call kmalloc
    mov ebx, eax

    ; Compare PMM free-page counts before and after the request.
    call pmm_get_free_pages
    pop edx

    test ebx, ebx
    jnz heap_test_failed

    cmp eax, edx
    jne heap_test_failed

    ; kfree(NULL) must fail.
    xor eax, eax
    call kfree
    test eax, eax
    jnz heap_test_failed

    ; Allocate a small block for invalid-pointer tests.
    mov eax, 64
    call kmalloc
    test eax, eax
    jz heap_alloc_failed
    mov [heap_ptr_a], eax

    ; An aligned address outside the heap must be rejected.
    mov eax, 0x20000000
    call kfree
    test eax, eax
    jnz heap_test_failed

    ; A pointer inside the heap, but not at a payload start,
    ; must be rejected. +8 remains aligned but is not valid.
    mov eax, [heap_ptr_a]
    add eax, 8
    call kfree
    test eax, eax
    jnz heap_test_failed

    ; The original pointer must remain valid after failed frees.
    mov eax, [heap_ptr_a]
    call kfree
    cmp eax, 1
    jne heap_free_failed

    ; The heap must still be usable after rejected requests.
    mov eax, 64
    call kmalloc
    test eax, eax
    jz heap_alloc_failed
    mov [heap_ptr_a], eax

    mov eax, [heap_ptr_a]
    call kfree
    cmp eax, 1
    jne heap_free_failed

    mov esi, heap_invalid_pass_msg
    call serial_print

    ; ========================================================
    ; Heap Test 8: Force allocation from a second heap page.
    ; Keep the first 3000-byte allocation alive so the second
    ; allocation cannot fit in the remaining space of page 1.
    ; ========================================================

    mov eax, 3000
    call kmalloc
    test eax, eax
    jz heap_growth_failed
    mov [heap_ptr_a], eax

    mov eax, 3000
    call kmalloc
    test eax, eax
    jz heap_growth_failed
    mov [heap_ptr_b], eax

    ; Both allocations must be distinct.
    mov eax, [heap_ptr_a]
    cmp eax, [heap_ptr_b]
    je heap_growth_failed

    ; Their page-aligned addresses must be different.
    and eax, 0xFFFFF000
    mov edx, eax

    mov eax, [heap_ptr_b]
    and eax, 0xFFFFF000
    cmp eax, edx
    je heap_growth_failed

    ; Free the second region first, then the first region.
    mov eax, [heap_ptr_b]
    call kfree
    cmp eax, 1
    jne heap_free_failed

    mov eax, [heap_ptr_a]
    call kfree
    cmp eax, 1
    jne heap_free_failed

    mov esi, heap_growth_pass_msg
    call serial_print

    ; The first region should be reusable after coalescing.
    mov eax, 3000
    call kmalloc
    test eax, eax
    jz heap_growth_failed

    cmp eax, [heap_ptr_a]
    jne heap_growth_failed

    call kfree
    cmp eax, 1
    jne heap_free_failed

    mov esi, heap_growth_reuse_pass_msg
    call serial_print

    mov esi, heap_test_pass_msg
    call serial_print

    ; ========================================================
    ; Memory exhaustion regression test.
    ; Fill every heap region, then exhaust the remaining PMM.
    ; Each allocation stores the previous list head in its
    ; own payload, avoiding a large bookkeeping array.
    ; ========================================================

    mov dword [exhaust_heap_head], 0
    mov dword [exhaust_heap_alloc_count], 0

exhaust_heap_fill_loop:
    mov eax, 4080
    call kmalloc
    test eax, eax
    jz exhaust_heap_fill_done

    mov edx, [exhaust_heap_head]
    mov [eax], edx
    mov [exhaust_heap_head], eax
    inc dword [exhaust_heap_alloc_count]
    jmp exhaust_heap_fill_loop

exhaust_heap_fill_done:
    ; The heap must be full while substantial PMM memory remains.
    call pmm_get_free_pages
    cmp eax, 1000
    jb heap_test_failed
    mov [exhaust_baseline_pages], eax

    mov dword [exhaust_page_head], 0
    mov dword [exhaust_page_alloc_count], 0

exhaust_pmm_loop:
    call pmm_alloc_page
    test eax, eax
    jz exhaust_pmm_done

    mov edx, [exhaust_page_head]
    mov [eax], edx
    mov [exhaust_page_head], eax
    inc dword [exhaust_page_alloc_count]
    jmp exhaust_pmm_loop

exhaust_pmm_done:
    call pmm_get_free_pages
    test eax, eax
    jnz heap_test_failed

    ; Another physical allocation must also fail.
    call pmm_alloc_page
    test eax, eax
    jnz heap_test_failed

    ; All heap regions are full and the PMM has no free pages.
    mov eax, 4080
    call kmalloc
    test eax, eax
    jnz heap_test_failed

    ; Restore all physical pages owned by this test.
    mov esi, [exhaust_page_head]

exhaust_pmm_free_loop:
    test esi, esi
    jz exhaust_pmm_free_done

    mov edx, [esi]
    mov eax, esi
    call pmm_free_page
    cmp eax, 1
    jne pmm_free_failed

    mov esi, edx
    jmp exhaust_pmm_free_loop

exhaust_pmm_free_done:
    call pmm_get_free_pages
    cmp eax, [exhaust_baseline_pages]
    jne heap_test_failed

    mov esi, exhaust_pmm_pass_msg
    call serial_print

    ; Free the heap allocations created by this test.
    ; Their physical regions remain registered with the heap.
    mov esi, [exhaust_heap_head]

exhaust_heap_free_loop:
    test esi, esi
    jz exhaust_heap_free_done

    mov edx, [esi]
    mov eax, esi
    call kfree
    cmp eax, 1
    jne heap_free_failed

    mov esi, edx
    jmp exhaust_heap_free_loop

exhaust_heap_free_done:
    mov esi, exhaust_heap_pass_msg
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
    jmp failure_hang

heap_init_failed:
    cli
    mov esi, heap_init_error_msg
    call serial_print
    jmp failure_hang

heap_alloc_failed:
    cli
    mov esi, heap_alloc_error_msg
    call serial_print
    jmp failure_hang

heap_free_failed:
    cli
    mov esi, heap_free_error_msg
    call serial_print
    jmp failure_hang

heap_double_free_failed:
    cli
    mov esi, heap_double_error_msg
    call serial_print
    jmp failure_hang

heap_reuse_failed:
    cli
    mov esi, heap_reuse_error_msg
    call serial_print
    jmp failure_hang

heap_coalesce_failed:
    cli
    mov esi, heap_coalesce_error_msg
    call serial_print
    jmp failure_hang

heap_growth_failed:
    cli
    mov esi, heap_growth_error_msg
    call serial_print
    jmp failure_hang

heap_test_failed:
    cli
    mov esi, heap_test_error_msg
    call serial_print
    jmp failure_hang

heap_registry_failed:
    cli
    mov esi, heap_registry_error_msg
    call serial_print
    jmp failure_hang

heap_metadata_failed:
    cli
    mov esi, heap_metadata_error_msg
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

heap_init_msg:
    db "[HEAP] Initializing kernel heap.", 13, 10, 0

heap_init_pass_msg:
    db "[HEAP TEST] Initialization: PASS", 13, 10, 0

heap_alloc_pass_msg:
    db "[HEAP TEST] Multiple allocations: PASS", 13, 10, 0

heap_double_pass_msg:
    db "[HEAP TEST] Double free rejected: PASS", 13, 10, 0

heap_reuse_pass_msg:
    db "[HEAP TEST] Freed block reused: PASS", 13, 10, 0

heap_free_pass_msg:
    db "[HEAP TEST] Blocks freed successfully: PASS", 13, 10, 0

heap_coalesce_pass_msg:
    db "[HEAP TEST] Adjacent blocks coalesced: PASS", 13, 10, 0

heap_full_page_pass_msg:
    db "[HEAP TEST] Full page allocation after coalescing: PASS", 13, 10, 0

heap_metadata_pass_msg:
    db "[HEAP TEST] Corrupted block metadata rejected and recovery verified: PASS", 13, 10, 0

heap_invalid_pass_msg:
    db "[HEAP TEST] Invalid inputs and pointers rejected: PASS", 13, 10, 0
heap_registry_pass_msg:
    db "[HEAP TEST] Invalid registry counts rejected and recovery verified: PASS", 13, 10, 0

heap_test_pass_msg:
    db "[HEAP] All runtime tests PASSED.", 13, 10, 0

heap_init_error_msg:
    db "[HEAP ERROR] Heap initialization failed.", 13, 10, 0

heap_alloc_error_msg:
    db "[HEAP ERROR] Allocation failed unexpectedly.", 13, 10, 0

heap_free_error_msg:
    db "[HEAP ERROR] Free operation failed.", 13, 10, 0

heap_double_error_msg:
    db "[HEAP ERROR] Double free was incorrectly accepted.", 13, 10, 0

heap_reuse_error_msg:
    db "[HEAP ERROR] Freed block was not reused as expected.", 13, 10, 0

heap_coalesce_error_msg:
    db "[HEAP ERROR] Block coalescing or full-page reuse failed.", 13, 10, 0

heap_test_error_msg:
    db "[HEAP ERROR] Allocation pointers are not distinct.", 13, 10, 0

heap_registry_error_msg:
    db "[HEAP ERROR] Invalid registry count was accepted or recovery failed.", 13, 10, 0

heap_metadata_error_msg:
    db "[HEAP ERROR] Heap metadata corruption test failed.", 13, 10, 0

heap_growth_pass_msg:
    db "[HEAP TEST] Multi-page growth and independent frees: PASS", 13, 10, 0

heap_growth_reuse_pass_msg:
    db "[HEAP TEST] Multi-page freed region reused: PASS", 13, 10, 0

heap_growth_error_msg:
    db "[HEAP ERROR] Multi-page growth or reuse failed.", 13, 10, 0

exhaust_pmm_pass_msg:
    db "[PMM TEST] Exhaustion and free-page recovery: PASS", 13, 10, 0

exhaust_heap_pass_msg:
    db "[HEAP TEST] Allocation fails when heap and PMM are exhausted: PASS", 13, 10, 0

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

heap_ptr_a:
    resd 1

heap_ptr_b:
    resd 1

heap_ptr_c:
    resd 1

heap_ptr_d:
    resd 1

heap_corrupt_header:
    resd 1

heap_corrupt_original_size:
    resd 1

heap_corrupt_result:
    resd 1
heap_registry_original_count:
    resd 1

heap_registry_original_base:
    resd 1

heap_registry_kmalloc_result:
    resd 1

heap_registry_kfree_result:
    resd 1

exhaust_heap_head:
    resd 1

exhaust_heap_alloc_count:
    resd 1

exhaust_page_head:
    resd 1

exhaust_page_alloc_count:
    resd 1

exhaust_baseline_pages:
    resd 1
