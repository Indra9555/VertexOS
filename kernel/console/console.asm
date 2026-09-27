[bits 32]

section .text

global console_init
global console_clear
global console_putc
global console_print
global console_newline
global console_scroll

; ============================================================
; VertexOS Console
;
; VGA text-mode console
;
; VGA memory:
;   0xB8000
;
; Each screen cell:
;   byte 0 = character
;   byte 1 = attribute
;
; Screen:
;   80 columns
;   25 rows
;
; ============================================================


; ============================================================
; CONSTANTS
; ============================================================

VGA_MEMORY      equ 0xB8000

SCREEN_WIDTH    equ 80
SCREEN_HEIGHT   equ 25

VGA_ROW_SIZE    equ SCREEN_WIDTH * 2

DEFAULT_ATTRIBUTE equ 0x0F


; ============================================================
; console_init
;
; Initializes the console.
;
; For now:
;   - Clear screen
;   - Reset cursor
;
; ============================================================

console_init:

    call console_clear

    ret


; ============================================================
; console_clear
;
; Clears the entire VGA screen.
;
; Cursor is reset to the top-left.
;
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
; AL = character
;
; Handles:
;
;   normal character
;   newline
; ============================================================

console_putc:

    cmp al, 10
    je console_putc_newline


    push eax
    push edi

    mov edi, [console_cursor]

    mov [edi], al
    mov byte [edi + 1], DEFAULT_ATTRIBUTE

    add edi, 2

    mov [console_cursor], edi

    pop edi
    pop eax

    ret


console_putc_newline:

    call console_newline

    ret


; ============================================================
; console_print
;
; ESI = null-terminated string
;
; Prints the string one character at a time.
;
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
; Moves cursor to beginning of next row.
;
; If the screen is full, scrolls the screen.
;
; ============================================================

console_newline:

    push eax
    push ebx
    push edx
    push edi

    mov edi, [console_cursor]

    sub edi, VGA_MEMORY

    mov eax, edi

    xor edx, edx

    mov ebx, VGA_ROW_SIZE

    div ebx

    inc eax

    ; --------------------------------------------------------
    ; If next row is still inside the screen
    ; --------------------------------------------------------

    cmp eax, SCREEN_HEIGHT

    jb console_newline_same_screen


    ; --------------------------------------------------------
    ; Screen is full
    ; --------------------------------------------------------

    call console_scroll

    mov eax, SCREEN_HEIGHT - 1


console_newline_same_screen:

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
; Moves rows 1-24 upward.
;
; Row 0 is replaced by row 1.
; Row 24 becomes blank.
;
; ============================================================

console_scroll:

    push eax
    push ecx
    push esi
    push edi


    ; --------------------------------------------------------
    ; Source:
    ;
    ; Row 1
    ; --------------------------------------------------------

    mov esi, VGA_MEMORY + VGA_ROW_SIZE


    ; --------------------------------------------------------
    ; Destination:
    ;
    ; Row 0
    ; --------------------------------------------------------

    mov edi, VGA_MEMORY


    ; --------------------------------------------------------
    ; Number of character cells to copy:
    ;
    ; 24 rows × 80 cells
    ; --------------------------------------------------------

    mov ecx, (SCREEN_HEIGHT - 1) * SCREEN_WIDTH


    ; --------------------------------------------------------
    ; Each cell = 16 bits
    ; --------------------------------------------------------

    cld

    rep movsw


    ; --------------------------------------------------------
    ; Clear bottom row
    ; --------------------------------------------------------

    mov edi, VGA_MEMORY + ((SCREEN_HEIGHT - 1) * VGA_ROW_SIZE)

    mov ecx, SCREEN_WIDTH

    mov ax, 0x0720


console_scroll_clear_bottom:

    mov [edi], ax

    add edi, 2

    loop console_scroll_clear_bottom


    pop edi
    pop esi
    pop ecx
    pop eax

    ret


; ============================================================
; DATA
; ============================================================

section .data

console_cursor:

    dd VGA_MEMORY
