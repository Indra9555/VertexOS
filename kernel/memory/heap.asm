[bits 32]

%define HEAP_PAGE_SIZE       4096
%define HEAP_ALIGNMENT       8
%define HEAP_HEADER_SIZE     16
%define HEAP_MAX_REGIONS     256

[section .text]

global heap_init
global kmalloc
global kfree

extern pmm_alloc_page

; Block header:
; +0  total block size, including header
; +4  free flag (1 = free, 0 = allocated)
; +8  previous block header within this region
; +12 next block header within this region

; ------------------------------------------------------------
; heap_init
; Output: EAX = 1 on success, 0 on failure.
; Allocates and registers the first heap page.
; ------------------------------------------------------------

heap_init:
    push ebx
    push edi

    cmp dword [heap_ready], 1
    je .already_ready

    mov dword [heap_region_count], 0

    call pmm_alloc_page
    test eax, eax
    jz .failed

    mov [heap_region_bases], eax
    mov [heap_region_heads], eax

    mov dword [eax], HEAP_PAGE_SIZE
    mov dword [eax + 4], 1
    mov dword [eax + 8], 0
    mov dword [eax + 12], 0

    mov dword [heap_region_count], 1
    mov dword [heap_ready], 1

.already_ready:
    mov eax, 1
    jmp .done

.failed:
    xor eax, eax

.done:
    pop edi
    pop ebx
    ret


; ------------------------------------------------------------
; kmalloc
; Input:  EAX = requested payload size
; Output: EAX = payload pointer, or 0 on failure.
;
; Searches existing regions first. If none can satisfy the
; request, allocates and registers another page, then retries.
; ------------------------------------------------------------

kmalloc:
    push ebx
    push ecx
    push edx
    push esi
    push edi

    cmp dword [heap_ready], 1
    jne .fail

    test eax, eax
    jz .fail

    ; Round payload size up to 8-byte alignment.
    add eax, HEAP_ALIGNMENT - 1
    jc .fail
    and eax, 0xFFFFFFF8

    ; Include the block header and reject overflow.
    add eax, HEAP_HEADER_SIZE
    jc .fail

    ; A single allocation must fit inside one page.
    cmp eax, HEAP_PAGE_SIZE
    ja .fail

    mov [heap_request_size], eax

.search_regions:
    mov dword [heap_region_index], 0

.search_region:
    mov ecx, [heap_region_index]
    cmp ecx, [heap_region_count]
    jae .grow

    mov eax, [heap_region_bases + ecx * 4]
    call heap_validate_region
    test eax, eax
    jz .fail

    mov esi, [heap_region_heads + ecx * 4]
    cmp esi, [heap_region_bases + ecx * 4]
    jne .fail

.search_block:
    test esi, esi
    jz .next_region

    cmp dword [esi + 4], 1
    jne .next_block

    mov edx, [esi]
    cmp edx, [heap_request_size]
    jb .next_block

    ; Split if the remainder can hold a header and payload.
    mov ecx, edx
    sub ecx, [heap_request_size]
    cmp ecx, HEAP_HEADER_SIZE + HEAP_ALIGNMENT
    jb .allocate_whole

    ; Create the remainder block after the allocation.
    mov edi, esi
    add edi, [heap_request_size]

    mov [edi], ecx
    mov dword [edi + 4], 1
    mov [edi + 8], esi

    mov eax, [esi + 12]
    mov [edi + 12], eax

    ; Update the following block's previous link.
    test eax, eax
    jz .split_linked
    mov [eax + 8], edi

.split_linked:
    mov [esi + 12], edi
    mov eax, [heap_request_size]
    mov [esi], eax
    jmp .mark_allocated

.allocate_whole:
    ; Retain the whole block when splitting would leave
    ; an unusable remainder.

.mark_allocated:
    mov dword [esi + 4], 0
    lea eax, [esi + HEAP_HEADER_SIZE]
    jmp .done

.next_block:
    mov esi, [esi + 12]
    jmp .search_block

.next_region:
    inc dword [heap_region_index]
    jmp .search_region

.grow:
    ; Refuse growth when the registry is full.
    mov eax, [heap_region_count]
    cmp eax, HEAP_MAX_REGIONS
    jae .fail

    ; Request another physical page from the PMM.
    call pmm_alloc_page
    test eax, eax
    jz .fail

    mov [heap_new_base], eax

    ; Register this region as an independent block list.
    mov ecx, [heap_region_count]
    mov [heap_region_bases + ecx * 4], eax
    mov [heap_region_heads + ecx * 4], eax

    mov dword [eax], HEAP_PAGE_SIZE
    mov dword [eax + 4], 1
    mov dword [eax + 8], 0
    mov dword [eax + 12], 0

    inc dword [heap_region_count]

    ; Retry the original request against every region.
    jmp .search_regions

.fail:
    xor eax, eax

.done:
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret


; ------------------------------------------------------------
; kfree
; Input:  EAX = pointer returned by kmalloc
; Output: EAX = 1 on success, 0 on failure.
;
; Validates the pointer against every registered region,
; rejects invalid/double frees, and coalesces adjacent blocks
; only within the same region.
; ------------------------------------------------------------

kfree:
    push ebx
    push ecx
    push edx
    push esi
    push edi

    test eax, eax
    jz .fail

    cmp dword [heap_ready], 1
    jne .fail

    ; Payload pointers must be 8-byte aligned.
    test eax, HEAP_ALIGNMENT - 1
    jnz .fail

    mov [heap_free_ptr], eax
    mov dword [heap_region_index], 0

.find_region:
    mov ecx, [heap_region_index]
    cmp ecx, [heap_region_count]
    jae .fail

    mov eax, [heap_region_bases + ecx * 4]
    call heap_validate_region
    test eax, eax
    jz .fail

    mov esi, [heap_region_bases + ecx * 4]
    mov edx, esi
    add edx, HEAP_PAGE_SIZE

    ; The pointer must be strictly inside this page.
    mov eax, [heap_free_ptr]
    cmp eax, esi
    jbe .next_region
    cmp eax, edx
    jae .next_region

    ; Recover the candidate block header.
    sub eax, HEAP_HEADER_SIZE
    mov edi, eax

    ; Find that exact header in this region's block list.
    mov esi, [heap_region_heads + ecx * 4]

.find_block:
    test esi, esi
    jz .next_region

    cmp esi, edi
    je .found_block

    mov esi, [esi + 12]
    jmp .find_block

.found_block:
    ; A free block cannot be freed again.
    cmp dword [esi + 4], 0
    jne .fail

    mov dword [esi + 4], 1

    ; Merge with the next block when it is free.
    mov edi, [esi + 12]
    test edi, edi
    jz .merge_previous

    cmp dword [edi + 4], 1
    jne .merge_previous

    mov eax, [edi]
    add [esi], eax

    mov eax, [edi + 12]
    mov [esi + 12], eax

    test eax, eax
    jz .merge_previous
    mov [eax + 8], esi

.merge_previous:
    ; Merge into the previous block when it is free.
    mov edi, [esi + 8]
    test edi, edi
    jz .success

    cmp dword [edi + 4], 1
    jne .success

    mov eax, [esi]
    add [edi], eax

    mov eax, [esi + 12]
    mov [edi + 12], eax

    test eax, eax
    jz .success
    mov [eax + 8], edi

.success:
    mov eax, 1
    jmp .done

.next_region:
    inc dword [heap_region_index]
    jmp .find_region

.fail:
    xor eax, eax

.done:
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret


; ------------------------------------------------------------
; heap_validate_region
; Input: EAX = registered region base.
; Output: EAX = 1 if the block chain is consistent, else 0.
; Walks by validated sizes, never by untrusted next pointers.
; ------------------------------------------------------------

heap_validate_region:
    push ebx
    push ecx
    push edx
    push esi
    push edi

    mov ebx, eax
    mov esi, eax
    mov edi, eax
    add edi, HEAP_PAGE_SIZE
    jc .invalid

    xor edx, edx

.check_block:
    cmp esi, edi
    jae .invalid

    ; A complete header must fit in the remaining region.
    mov ecx, edi
    sub ecx, esi
    cmp ecx, HEAP_HEADER_SIZE
    jb .invalid

    ; Validate size and free flag before using block metadata.
    mov eax, [esi]
    cmp eax, HEAP_HEADER_SIZE
    jb .invalid
    test eax, HEAP_ALIGNMENT - 1
    jnz .invalid
    cmp eax, ecx
    ja .invalid
    cmp dword [esi + 4], 1
    ja .invalid

    ; The previous link must match the validated predecessor.
    cmp [esi + 8], edx
    jne .invalid

    ; Calculate the successor without following the stored link.
    mov ecx, esi
    add ecx, eax
    jc .invalid
    cmp ecx, edi
    ja .invalid
    je .last_block

    ; Non-final block must link to the calculated successor.
    cmp [esi + 12], ecx
    jne .invalid

    mov edx, esi
    mov esi, ecx
    jmp .check_block

.last_block:
    ; Final block must end exactly at the region boundary.
    cmp dword [esi + 12], 0
    jne .invalid
    mov eax, 1
    jmp .validate_done

.invalid:
    xor eax, eax

.validate_done:
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret


[section .bss]
alignb 4

heap_ready:
    resd 1

heap_region_count:
    resd 1

heap_region_index:
    resd 1

heap_request_size:
    resd 1

heap_new_base:
    resd 1

heap_free_ptr:
    resd 1

alignb 4
heap_region_bases:
    resd HEAP_MAX_REGIONS

heap_region_heads:
    resd HEAP_MAX_REGIONS
