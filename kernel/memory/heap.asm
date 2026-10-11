
[bits 32]

%define HEAP_PAGE_SIZE 4096
%define HEAP_ALIGNMENT 8
%define HEAP_HEADER_SIZE 16

[section .text]

global heap_init
global kmalloc
global kfree

extern pmm_alloc_page

; Block header:
; +0: total block size, including header
; +4: free flag (1 = free, 0 = allocated)
; +8: previous block header
; +12: next block header

heap_init:
    push ebx
    push edi

    call pmm_alloc_page
    test eax, eax
    jz .failed

    mov [heap_start], eax
    mov dword [eax], HEAP_PAGE_SIZE
    mov dword [eax + 4], 1
    mov dword [eax + 8], 0
    mov dword [eax + 12], 0

    mov dword [heap_ready], 1
    mov eax, 1
    jmp .done

.failed:
    xor eax, eax

.done:
    pop edi
    pop ebx
    ret


; kmalloc
; Input:  EAX = requested payload size
; Output: EAX = pointer to payload, or 0 on failure

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

    ; Add header size, rejecting overflow.
    add eax, HEAP_HEADER_SIZE
    jc .fail

    mov [heap_request_size], eax
    mov esi, [heap_start]

.search:
    test esi, esi
    jz .fail

    cmp dword [esi + 4], 1
    jne .next

    mov edx, [esi]
    cmp edx, [heap_request_size]
    jb .next

    ; Split only if the remainder can hold a header
    ; and at least one aligned payload.
    mov ecx, edx
    sub ecx, [heap_request_size]
    cmp ecx, HEAP_HEADER_SIZE + HEAP_ALIGNMENT
    jb .allocate_whole

    ; New block starts immediately after the allocated block.
    mov edi, esi
    add edi, [heap_request_size]

    mov [edi], ecx
    mov dword [edi + 4], 1
    mov [edi + 8], esi
    mov eax, [esi + 12]
    mov [edi + 12], eax

    ; Update next block's back-link.
    mov eax, [edi + 12]
    test eax, eax
    jz .split_linked
    mov [eax + 8], edi

.split_linked:
    mov [esi + 12], edi
    mov eax, [heap_request_size]
    mov [esi], eax
    jmp .mark_allocated

.allocate_whole:
    ; Keep the entire block if splitting would leave
    ; an unusable remainder.
    nop

.mark_allocated:
    mov dword [esi + 4], 0
    lea eax, [esi + HEAP_HEADER_SIZE]
    jmp .done

.next:
    mov esi, [esi + 12]
    jmp .search

.fail:
    xor eax, eax

.done:
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret


; kfree
; Input:  EAX = pointer returned by kmalloc
; Output: EAX = 1 on success, 0 on failure

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

    ; Ensure the pointer belongs to this heap page.
    mov esi, [heap_start]
    lea edx, [esi + HEAP_PAGE_SIZE]
    cmp eax, esi
    jbe .fail
    cmp eax, edx
    jae .fail

    ; Payload pointers must be 8-byte aligned.
    test eax, HEAP_ALIGNMENT - 1
    jnz .fail

    ; Recover header and validate exact payload start.
    sub eax, HEAP_HEADER_SIZE
    cmp eax, esi
    jb .fail
    mov edi, eax

    ; Check that this is an actual block header in the list.
    mov esi, [heap_start]

.find:
    test esi, esi
    jz .fail
    cmp esi, edi
    je .found
    mov esi, [esi + 12]
    jmp .find

.found:
    cmp dword [esi + 4], 0
    jne .fail

    mov dword [esi + 4], 1

    ; Merge with the next free block.
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

.fail:
    xor eax, eax

.done:
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret


[section .bss]
alignb 4
heap_start:
    resd 1
heap_ready:
    resd 1
heap_request_size:
    resd 1
