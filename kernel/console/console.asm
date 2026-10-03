[bits 32]

section .text

global console_init
global console_clear
global console_putc
global console_print
global console_newline
global console_scroll
global console_get_cursor
global console_set_cursor
global console_draw_cursor
global console_remove_cursor
global console_backspace

; ============================================================
; VertexOS Console Subsystem
;
; VGA text mode console
;
; VGA memory:
;   0xB8000
;
; Screen:
;   80 columns × 25 rows
;
; Each VGA cell:
;   byte 0 = character
;   byte 1 = attribute
;
; The Console subsystem owns:
;
;   - VGA memory
;   - console cursor position
;   - character output
;   - newline handling
;   - scrolling
;   - cursor rendering
;   - backspace
;
; ============================================================


; ============================================================
; CONSTANTS
; ============================================================

VGA_MEMORY          equ 0xB8000

SCREEN_WIDTH        equ 80
SCREEN_HEIGHT       equ 25

VGA_ROW_SIZE        equ SCREEN_WIDTH * 2
VGA_SCREEN_SIZE     equ SCREEN_WIDTH * SCREEN_HEIGHT * 2

VGA_SCREEN_END      equ VGA_MEMORY + VGA_SCREEN_SIZE

DEFAULT_ATTRIBUTE   equ 0x0F
CLEAR_ATTRIBUTE     equ 0x07


; ============================================================
; console_init
;
; Initialize the console.
; ============================================================

console_init:

    call console_clear

    ret


; ============================================================
; console_clear
;
; Clear the complete VGA screen.
; Cursor returns to top-left.
; ============================================================

console_clear:

    push eax
    push ecx
    push edi

    mov edi, VGA_MEMORY

    mov ecx, SCREEN_WIDTH * SCREEN_HEIGHT

    mov ax, 0x0720

console_clear_loop:

    mov [edi], ax

    add edi, 2

    loop console_clear_loop

    mov dword [console_cursor], VGA_MEMORY

    pop edi
    pop ecx
    pop eax

    ret


; ============================================================
; console_putc
;
; Input:
;   AL = character
;
; Handles:
;   10 = newline
;
; Normal characters are written at the current cursor.
; ============================================================

console_putc:

    cmp al, 10
    je console_putc_newline

    push eax
    push edi

    mov edi, [console_cursor]

    ; --------------------------------------------------------
    ; Safety check.
    ;
    ; Never write outside VGA memory.
    ; --------------------------------------------------------

    cmp edi, VGA_SCREEN_END - 2
    ja console_putc_done

    ; --------------------------------------------------------
    ; Write character.
    ; --------------------------------------------------------

    mov [edi], al
    mov byte [edi + 1], DEFAULT_ATTRIBUTE

    ; --------------------------------------------------------
    ; Advance cursor.
    ; --------------------------------------------------------

    add edi, 2

    mov [console_cursor], edi

    ; --------------------------------------------------------
    ; If cursor reached the end of the screen,
    ; scroll and place it on the bottom row.
    ; --------------------------------------------------------

    cmp edi, VGA_SCREEN_END
    jb console_putc_done

    call console_scroll

    mov dword [console_cursor], \
        VGA_MEMORY + ((SCREEN_HEIGHT - 1) * VGA_ROW_SIZE)

console_putc_done:

    pop edi
    pop eax

    ret


console_putc_newline:

    call console_newline

    ret


; ============================================================
; console_print
;
; Input:
;   ESI = null-terminated string
; ============================================================

console_print:

    push eax

console_print_loop:

    lodsb

    test al, al

    jz console_print_done

    call console_putc

    jmp console_print_loop


console_print_done:

    pop eax

    ret


; ============================================================
; console_newline
;
; Move cursor to the beginning of the next row.
;
; If the cursor is already on the last row:
;   scroll upward
;   keep cursor on bottom row
; ============================================================

console_newline:

    push eax
    push ebx
    push edx
    push edi

    mov edi, [console_cursor]

    ; --------------------------------------------------------
    ; Keep cursor inside valid screen range.
    ; --------------------------------------------------------

    cmp edi, VGA_SCREEN_END
    jb console_newline_cursor_valid

    mov edi, VGA_SCREEN_END - 2

console_newline_cursor_valid:

    sub edi, VGA_MEMORY

    ; --------------------------------------------------------
    ; Convert byte offset to row.
    ; --------------------------------------------------------

    mov eax, edi

    xor edx, edx

    mov ebx, VGA_ROW_SIZE

    div ebx

    ; --------------------------------------------------------
    ; Next row.
    ; --------------------------------------------------------

    inc eax

    ; --------------------------------------------------------
    ; Need to scroll?
    ; --------------------------------------------------------

    cmp eax, SCREEN_HEIGHT
    jb console_newline_no_scroll

    call console_scroll

    mov eax, SCREEN_HEIGHT - 1

console_newline_no_scroll:

    imul eax, VGA_ROW_SIZE

    add eax, VGA_MEMORY

    mov [console_cursor], eax

    pop edi
    pop edx
    pop ebx
    pop eax

    ret


; ============================================================
; console_scroll
;
; Scroll screen upward by one row.
; ============================================================

console_scroll:

    push eax
    push ecx
    push esi
    push edi
    pushfd

    cld

    ; --------------------------------------------------------
    ; Source = row 1
    ; Destination = row 0
    ; --------------------------------------------------------

    mov esi, VGA_MEMORY + VGA_ROW_SIZE

    mov edi, VGA_MEMORY

    ; --------------------------------------------------------
    ; Copy 24 rows × 80 cells.
    ; ========================================================

    mov ecx, (SCREEN_HEIGHT - 1) * SCREEN_WIDTH

    rep movsw

    ; --------------------------------------------------------
    ; Clear bottom row.
    ; --------------------------------------------------------

    mov edi, VGA_MEMORY + ((SCREEN_HEIGHT - 1) * VGA_ROW_SIZE)

    mov ecx, SCREEN_WIDTH

    mov ax, 0x0720

console_scroll_clear_bottom:

    mov [edi], ax

    add edi, 2

    loop console_scroll_clear_bottom

    popfd
    pop edi
    pop esi
    pop ecx
    pop eax

    ret


; ============================================================
; console_get_cursor
;
; Returns:
;   EAX = current cursor address
; ============================================================

console_get_cursor:

    mov eax, [console_cursor]

    ret


; ============================================================
; console_set_cursor
;
; Input:
;   EAX = desired VGA cursor address
;
; Only accepts positions inside the VGA screen.
; ============================================================

console_set_cursor:

    ; --------------------------------------------------------
    ; Reject address before VGA memory.
    ; --------------------------------------------------------

    cmp eax, VGA_MEMORY
    jb console_set_cursor_done

    ; --------------------------------------------------------
    ; Reject address outside the screen.
    ;
    ; VGA_SCREEN_END itself is not a valid cell.
    ; --------------------------------------------------------

    cmp eax, VGA_SCREEN_END
    jae console_set_cursor_done

    ; --------------------------------------------------------
    ; Cursor must point to a VGA cell.
    ; Force alignment to an even byte offset.
    ; --------------------------------------------------------

    sub eax, VGA_MEMORY

    and eax, 0xFFFFFFFE

    add eax, VGA_MEMORY

    mov [console_cursor], eax

console_set_cursor_done:

    ret


; ============================================================
; console_draw_cursor
;
; Draw visible input cursor at current console position.
;
; Cursor representation:
;   _
;
; Does not move the console cursor.
; ============================================================

console_draw_cursor:

    push eax
    push edi

    mov edi, [console_cursor]

    ; --------------------------------------------------------
    ; Never draw outside VGA memory.
    ;
    ; The last valid cell starts at VGA_SCREEN_END - 2.
    ; --------------------------------------------------------

    cmp edi, VGA_SCREEN_END - 2
    ja console_draw_cursor_done

    mov byte [edi], '_'
    mov byte [edi + 1], DEFAULT_ATTRIBUTE

console_draw_cursor_done:

    pop edi
    pop eax

    ret


; ============================================================
; console_remove_cursor
;
; Remove visible input cursor.
;
; Does not move the console cursor.
; ============================================================

console_remove_cursor:

    push eax
    push edi

    mov edi, [console_cursor]

    ; --------------------------------------------------------
    ; Never access outside VGA memory.
    ; --------------------------------------------------------

    cmp edi, VGA_SCREEN_END - 2
    ja console_remove_cursor_done

    mov byte [edi], ' '
    mov byte [edi + 1], DEFAULT_ATTRIBUTE

console_remove_cursor_done:

    pop edi
    pop eax

    ret


; ============================================================
; console_backspace
;
; Erase the character immediately before the cursor.
;
; After the operation:
;
;   cursor = erased character position
;
; ============================================================

console_backspace:

    push eax
    push edi

    mov edi, [console_cursor]

    ; --------------------------------------------------------
    ; Cannot move before VGA memory.
    ; --------------------------------------------------------

    cmp edi, VGA_MEMORY
    jbe console_backspace_done

    ; --------------------------------------------------------
    ; Move to previous cell.
    ; --------------------------------------------------------

    sub edi, 2

    ; --------------------------------------------------------
    ; Safety check.
    ; --------------------------------------------------------

    cmp edi, VGA_MEMORY
    jb console_backspace_done

    ; --------------------------------------------------------
    ; Erase character.
    ; --------------------------------------------------------

    mov byte [edi], ' '
    mov byte [edi + 1], DEFAULT_ATTRIBUTE

    ; --------------------------------------------------------
    ; Cursor now points to erased cell.
    ; --------------------------------------------------------

    mov [console_cursor], edi

console_backspace_done:

    pop edi
    pop eax

    ret


; ============================================================
; DATA
; ============================================================

section .data

; ============================================================
; Console cursor
;
; Address of the next output position.
; ============================================================

console_cursor:

    dd VGA_MEMORY
