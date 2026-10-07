[bits 32]

section .text

global strlen
global strcmp
global memset
global memcpy
global memcmp
global memmove


; ============================================================
; strlen
;
; Input:
;   ESI = address of string
;
; Return:
;   EAX = string length
;
; ============================================================

strlen:

    xor eax, eax


strlen_loop:

    cmp byte [esi + eax], 0

    je strlen_done

    inc eax

    jmp strlen_loop


strlen_done:

    ret


; ============================================================
; strcmp
;
; Input:
;   ESI = address of first string
;   EDI = address of second string
;
; Return:
;   EAX = 1 if strings are equal
;   EAX = 0 if strings are different
;
; ============================================================

strcmp:

strcmp_loop:

    mov al, [esi]
    mov dl, [edi]

    cmp al, dl
    jne strcmp_not_equal

    cmp al, 0
    je strcmp_equal

    inc esi
    inc edi

    jmp strcmp_loop


strcmp_equal:

    mov eax, 1
    ret


strcmp_not_equal:

    xor eax, eax
    ret


; ============================================================
; memset
;
; Input:
;   EDI = destination address
;   AL  = byte value
;   ECX = number of bytes
;
; Return:
;   Nothing
;
; ============================================================

memset:

    test ecx, ecx
    jz memset_done

    cld
    rep stosb


memset_done:

    ret


; ============================================================
; memcpy
;
; Input:
;   ESI = source address
;   EDI = destination address
;   ECX = number of bytes
;
; Return:
;   Nothing
;
; Note:
;   Source and destination must not overlap.
;
; ============================================================

memcpy:

    test ecx, ecx
    jz memcpy_done

    cld
    rep movsb


memcpy_done:

    ret


; ============================================================
; memcmp
;
; Input:
;   ESI = address of first memory block
;   EDI = address of second memory block
;   ECX = number of bytes
;
; Return:
;   EAX = 1 if memory blocks are identical
;   EAX = 0 if different
;
; ============================================================

memcmp:

    test ecx, ecx
    jz memcmp_equal


memcmp_loop:

    mov al, [esi]
    cmp al, [edi]

    jne memcmp_not_equal

    inc esi
    inc edi
    dec ecx

    jnz memcmp_loop


memcmp_equal:

    mov eax, 1
    ret


memcmp_not_equal:

    xor eax, eax
    ret


; ============================================================
; memmove
;
; Copies memory safely when source and destination overlap.
;
; Input:
;   ESI = source address
;   EDI = destination address
;   ECX = number of bytes
;
; Return:
;   Nothing
;
; ============================================================

memmove:

    test ecx, ecx
    jz memmove_done

    ; If destination is before source,
    ; copy forward.
    cmp edi, esi
    jb memmove_forward

    ; If destination is exactly the same as source,
    ; nothing needs to be copied.
    je memmove_done

    ; Destination is after source.
    ; Copy backwards to protect overlapping data.

    add esi, ecx
    add edi, ecx

    dec esi
    dec edi

    std
    rep movsb
    cld

    jmp memmove_done


memmove_forward:

    cld
    rep movsb


memmove_done:

    ret
