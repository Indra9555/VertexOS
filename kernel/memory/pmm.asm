
[bits 32]

%define PMM_PAGE_SIZE          4096
%define PMM_MAX_MEMORY         0x08000000
%define PMM_MAX_PAGES          32768
%define PMM_BITMAP_BYTES       4096
%define PMM_FIRST_USABLE_PAGE  256

%define E820_ENTRY_SIZE        24
%define E820_TYPE_USABLE       1

[section .text]

global pmm_init
global pmm_alloc_page
global pmm_free_page
global pmm_get_free_pages

extern __kernel_start
extern __kernel_end

; ============================================================
; pmm_init
;
; Input:
;   EAX = physical address of E820 map
;   EBX = number of E820 entries
;
; Allocation bitmap:
;   1 = unavailable or allocated
;   0 = available
;
; Usable bitmap:
;   1 = eligible for allocation
;   0 = not eligible
;
; Initialization uses two passes:
;   1. Mark enabled usable E820 pages as available.
;   2. Reserve every non-usable or disabled E820 region.
;
; Reserved regions therefore override overlapping usable
; regions, independently of BIOS entry order.
; ============================================================

pmm_init:
    push ebx
    push esi
    push edi
    push ebp

    cld

    mov [pmm_map_ptr], eax
    mov [pmm_map_remaining], ebx
    mov [pmm_init_saved_count], ebx

    ; Start with all pages unavailable.
    mov edi, pmm_bitmap
    mov ecx, PMM_BITMAP_BYTES / 4
    mov eax, 0xFFFFFFFF
    rep stosd

    ; No pages are usable yet.
    mov edi, pmm_usable_bitmap
    mov ecx, PMM_BITMAP_BYTES / 4
    xor eax, eax
    rep stosd

    mov dword [pmm_free_pages], 0

    ; --------------------------------------------------------
    ; Pass 1: mark enabled usable regions.
    ; --------------------------------------------------------

    mov eax, [pmm_map_ptr]
    mov [pmm_entry_ptr], eax

pmm_usable_loop:
    cmp dword [pmm_map_remaining], 0
    je pmm_usable_done

    mov esi, [pmm_entry_ptr]

    ; Ignore regions whose base is above the 4 GiB boundary.
    cmp dword [esi + 4], 0
    jne pmm_usable_next

    ; Only E820 type 1 is usable RAM.
    cmp dword [esi + 16], E820_TYPE_USABLE
    jne pmm_usable_next

    ; The stage2 loader initializes the extended attribute
    ; field to 1 before requesting each 24-byte E820 entry.
    test dword [esi + 20], 1
    jz pmm_usable_next

    mov eax, [esi]

    ; Ignore regions starting at or above the managed limit.
    cmp eax, PMM_MAX_MEMORY
    jae pmm_usable_next

    ; If the upper length is nonzero, the region extends
    ; beyond our managed address window.
    cmp dword [esi + 12], 0
    jne pmm_usable_clip_end

    mov ebx, [esi + 8]
    test ebx, ebx
    jz pmm_usable_next

    ; Clip the end without overflowing the managed window.
    mov ecx, PMM_MAX_MEMORY
    sub ecx, eax
    cmp ebx, ecx
    jae pmm_usable_clip_end

    add ebx, eax
    jmp pmm_usable_end_ready

pmm_usable_clip_end:
    mov ebx, PMM_MAX_MEMORY

pmm_usable_end_ready:
    ; Round the base UP and end DOWN to complete pages.
    add eax, PMM_PAGE_SIZE - 1
    and eax, 0xFFFFF000
    and ebx, 0xFFFFF000

    cmp eax, ebx
    jae pmm_usable_next

    mov [pmm_region_current], eax
    mov [pmm_region_end], ebx

pmm_usable_page_loop:
    mov eax, [pmm_region_current]
    cmp eax, [pmm_region_end]
    jae pmm_usable_next

    mov edx, eax
    shr edx, 12

    ; Keep the first MiB reserved.
    cmp edx, PMM_FIRST_USABLE_PAGE
    jb pmm_usable_page_next

    ; Avoid double-counting overlapping usable entries.
    bt dword [pmm_usable_bitmap], edx
    jc pmm_usable_page_next

    bts dword [pmm_usable_bitmap], edx
    btr dword [pmm_bitmap], edx
    inc dword [pmm_free_pages]

pmm_usable_page_next:
    add dword [pmm_region_current], PMM_PAGE_SIZE
    jmp pmm_usable_page_loop

pmm_usable_next:
    add dword [pmm_entry_ptr], E820_ENTRY_SIZE
    dec dword [pmm_map_remaining]
    jmp pmm_usable_loop

pmm_usable_done:

    ; --------------------------------------------------------
    ; Pass 2: reserve non-usable and disabled regions.
    ; This ensures reserved entries always take precedence.
    ; --------------------------------------------------------

    mov eax, [pmm_map_ptr]
    mov [pmm_entry_ptr], eax
    mov ebx, [pmm_map_ptr]
    mov [pmm_map_remaining], ebx

    ; Restore the actual count from the saved input.
    ; pmm_init_saved_count was populated before Pass 1.
    mov ebx, [pmm_init_saved_count]
    mov [pmm_map_remaining], ebx

pmm_reserved_loop:
    cmp dword [pmm_map_remaining], 0
    je pmm_reserved_done

    mov esi, [pmm_entry_ptr]

    ; Ignore regions whose base starts above 4 GiB.
    cmp dword [esi + 4], 0
    jne pmm_reserved_next

    mov eax, [esi]

    cmp eax, PMM_MAX_MEMORY
    jae pmm_reserved_next

    ; Enabled usable entries are left alone in this pass.
    cmp dword [esi + 16], E820_TYPE_USABLE
    jne pmm_reserved_process

    test dword [esi + 20], 1
    jnz pmm_reserved_next

pmm_reserved_process:
    ; Ignore zero-length entries.
    mov ebx, [esi + 8]
    cmp dword [esi + 12], 0
    jne pmm_reserved_clip_end

    test ebx, ebx
    jz pmm_reserved_next

    ; Clip the end to the managed address window.
    mov ecx, PMM_MAX_MEMORY
    sub ecx, eax
    cmp ebx, ecx
    jae pmm_reserved_clip_end

    add ebx, eax
    jmp pmm_reserved_end_ready

pmm_reserved_clip_end:
    mov ebx, PMM_MAX_MEMORY

pmm_reserved_end_ready:
    ; Reserve all pages intersecting this region.
    mov edx, ebx
    call pmm_reserve_range

pmm_reserved_next:
    add dword [pmm_entry_ptr], E820_ENTRY_SIZE
    dec dword [pmm_map_remaining]
    jmp pmm_reserved_loop

pmm_reserved_done:
    ; Reserve the kernel image, including BSS.
    mov eax, __kernel_start
    mov edx, __kernel_end
    call pmm_reserve_range

    ; Reserve the E820 count and buffer used by stage2.
    mov eax, 0x9000
    mov edx, 0x9400
    call pmm_reserve_range
    pop ebp
    pop edi
    pop esi
    pop ebx
    ret


; ============================================================
; pmm_alloc_page
;
; Output:
;   EAX = allocated physical page address
;   EAX = 0 if no page is available
; ============================================================

pmm_alloc_page:
    push ebx
    push ecx
    push edx
    push edi

    mov ecx, PMM_FIRST_USABLE_PAGE

pmm_alloc_search:
    cmp ecx, PMM_MAX_PAGES
    jae pmm_alloc_failed

    bt dword [pmm_bitmap], ecx
    jc pmm_alloc_next

    bts dword [pmm_bitmap], ecx
    dec dword [pmm_free_pages]

    mov eax, ecx
    shl eax, 12
    jmp pmm_alloc_return

pmm_alloc_next:
    inc ecx
    jmp pmm_alloc_search

pmm_alloc_failed:
    xor eax, eax

pmm_alloc_return:
    pop edi
    pop edx
    pop ecx
    pop ebx
    ret


; ============================================================
; pmm_free_page
;
; Input:
;   EAX = physical address of the page
;
; Output:
;   EAX = 1 on success
;   EAX = 0 if invalid, reserved, or already free
; ============================================================

pmm_free_page:
    push ebx
    push ecx
    push edx
    push edi

    mov edx, eax

    ; Require page alignment.
    test edx, PMM_PAGE_SIZE - 1
    jnz pmm_free_failed

    ; Never free low memory.
    cmp edx, 0x00100000
    jb pmm_free_failed

    cmp edx, PMM_MAX_MEMORY
    jae pmm_free_failed

    shr edx, 12

    ; Only E820-usable pages may be freed.
    bt dword [pmm_usable_bitmap], edx
    jnc pmm_free_failed

    ; Reject double frees.
    bt dword [pmm_bitmap], edx
    jnc pmm_free_failed

    btr dword [pmm_bitmap], edx
    inc dword [pmm_free_pages]

    mov eax, 1
    jmp pmm_free_return

pmm_free_failed:
    xor eax, eax

pmm_free_return:
    pop edi
    pop edx
    pop ecx
    pop ebx
    ret


; ============================================================
; pmm_get_free_pages
;
; Output:
;   EAX = number of free physical pages
; ============================================================

pmm_get_free_pages:
    mov eax, [pmm_free_pages]
    ret


; ============================================================
; Internal helper: reserve a physical address range.
;
; Input:
;   EAX = start address
;   EDX = end address (exclusive)
;
; The range is clipped to the managed address window.
; Any affected page is removed from both usable and free sets.
; ============================================================

pmm_reserve_range:
    cmp eax, PMM_MAX_MEMORY
    jae pmm_reserve_done

    cmp edx, PMM_MAX_MEMORY
    jbe pmm_reserve_end_clipped

    mov edx, PMM_MAX_MEMORY

pmm_reserve_end_clipped:
    cmp eax, edx
    jae pmm_reserve_done

    mov [pmm_reserve_start], eax
    mov [pmm_reserve_end], edx

    ; Round start DOWN and end UP.
    and dword [pmm_reserve_start], 0xFFFFF000
    add dword [pmm_reserve_end], PMM_PAGE_SIZE - 1
    and dword [pmm_reserve_end], 0xFFFFF000

    mov eax, [pmm_reserve_start]
    mov [pmm_reserve_current], eax

pmm_reserve_loop:
    mov eax, [pmm_reserve_current]
    cmp eax, [pmm_reserve_end]
    jae pmm_reserve_done

    mov edx, eax
    shr edx, 12

    cmp edx, PMM_MAX_PAGES
    jae pmm_reserve_next

    ; Mark unavailable. CF is the previous allocation bit.
    bts dword [pmm_bitmap], edx
    jc pmm_reserve_clear_usable

    dec dword [pmm_free_pages]

pmm_reserve_clear_usable:
    btr dword [pmm_usable_bitmap], edx

pmm_reserve_next:
    add dword [pmm_reserve_current], PMM_PAGE_SIZE
    jmp pmm_reserve_loop

pmm_reserve_done:
    ret


[section .bss]

align 4
pmm_init_saved_count:
    resd 1

alignb 16
pmm_bitmap:
    resb PMM_BITMAP_BYTES

alignb 16
pmm_usable_bitmap:
    resb PMM_BITMAP_BYTES

align 4
pmm_free_pages:
    resd 1

pmm_map_ptr:
    resd 1

pmm_map_remaining:
    resd 1

pmm_entry_ptr:
    resd 1

pmm_region_current:
    resd 1

pmm_region_end:
    resd 1

pmm_reserve_start:
    resd 1

pmm_reserve_end:
    resd 1

pmm_reserve_current:
    resd 1
