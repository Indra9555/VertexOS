[bits 32]

section .text

global itoa
global itoa_hex


; ============================================================
; itoa
;
; Converts an unsigned 32-bit integer to decimal ASCII.
;
; Input:
;   EAX = unsigned integer
;   EDI = destination buffer
;
; Return:
;   EAX = address of resulting string
;
; Buffer requirement:
;   At least 11 bytes
;
; ============================================================

itoa:

    push edi

    mov ebx, 10

    ; Handle zero separately.
    test eax, eax
    jnz itoa_convert

    mov byte [edi], '0'
    mov byte [edi + 1], 0

    pop eax
    ret


itoa_convert:

    mov esi, edi

    ; Reserve space for:
    ; 10 digits + null terminator
    add edi, 11
    mov byte [edi], 0


itoa_loop:

    xor edx, edx
    div ebx

    add dl, '0'
    dec edi
    mov [edi], dl

    test eax, eax
    jnz itoa_loop


    ; Copy result back to beginning
    ; of destination buffer.
    mov ecx, edi
    sub ecx, esi

    mov edx, ecx
    inc edx


itoa_copy:

    mov al, [edi]
    mov [esi], al

    inc edi
    inc esi
    dec edx

    jnz itoa_copy

    pop eax
    ret


; ============================================================
; itoa_hex
;
; Converts a 32-bit unsigned integer to hexadecimal ASCII.
;
; Input:
;   EAX = unsigned 32-bit integer
;   EDI = destination buffer
;
; Return:
;   EAX = address of resulting string
;
; Output:
;   Always 8 hexadecimal digits.
;
; Example:
;
;   EAX = 0x00001050
;
;   Result:
;   "00001050"
;
; Buffer requirement:
;   At least 9 bytes
;
; ============================================================

itoa_hex:

    push edi

    mov esi, edi
    mov ecx, 8


itoa_hex_loop:

    rol eax, 4

    mov edx, eax
    and edx, 0x0F

    cmp edx, 9
    jbe itoa_hex_digit

    add edx, 'A' - 10
    jmp itoa_hex_store


itoa_hex_digit:

    add edx, '0'


itoa_hex_store:

    mov [edi], dl
    inc edi

    loop itoa_hex_loop

    mov byte [edi], 0

    pop eax
    ret
