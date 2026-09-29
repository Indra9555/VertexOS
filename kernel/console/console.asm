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


; ============================================================
; VertexOS Console Subsystem
;
; VGA text-mode console driver
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
; Responsibilities:
;
;   - Console initialization
;   - Screen clearing
;   - Character output
;   - String output
;   - Newline handling
;   - Automatic scrolling
;   - Cursor management
;   - Cursor rendering
;
; Architecture:
;
;   Higher-level components
;           ↓
;        Console API
;           ↓
;         VGA RAM
;
; The Console subsystem is the owner of VGA memory.
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

DEFAULT_ATTRIBUTE   equ 0x0F
CLEAR_ATTRIBUTE     equ 0x07


; ============================================================
; console_init
;
; Initialize the console subsystem.
;
; Actions:
;
;   1. Clear VGA screen
;   2. Reset console cursor
;
; ============================================================

console_init:

    call console_clear

    ret


; ============================================================
; console_clear
;
; Clear the complete VGA text screen.
;
; After clearing:
;
;   cursor = top-left
;
; ============================================================

console_clear:

    push eax
    push ecx
    push edi

    mov edi, VGA_MEMORY

    mov ecx, SCREEN_WIDTH * SCREEN_HEIGHT

    ; Space character + clear attribute
    mov ax, 0x0720


console_clear_loop:

    mov [edi], ax

    add edi, 2

    loop console_clear_loop


    ; --------------------------------------------------------
    ; Reset cursor
    ; --------------------------------------------------------

    mov dword [console_cursor], VGA_MEMORY


    pop edi
    pop ecx
    pop eax

    ret


; ============================================================
; console_putc
;
; Input:
;
;   AL = character
;
; Handles:
;
;   '\n' = newline
;   normal character = write to VGA
;
; ============================================================

console_putc:

    ; --------------------------------------------------------
    ; Newline?
    ; --------------------------------------------------------

    cmp al, 10

    je console_putc_newline


    push eax
    push edi


    ; --------------------------------------------------------
    ; Get current cursor
    ; --------------------------------------------------------

    mov edi, [console_cursor]


    ; --------------------------------------------------------
    ; Write character
    ; --------------------------------------------------------

    mov [edi], al

    mov byte [edi + 1], DEFAULT_ATTRIBUTE


    ; --------------------------------------------------------
    ; Advance cursor
    ; --------------------------------------------------------

    add edi, 2

    mov [console_cursor], edi


    ; --------------------------------------------------------
    ; Check whether cursor moved past screen.
    ; --------------------------------------------------------

    mov eax, edi

    sub eax, VGA_MEMORY

    cmp eax, VGA_SCREEN_SIZE

    jb console_putc_done


    ; --------------------------------------------------------
    ; Screen reached.
    ;
    ; Scroll one row and keep cursor on bottom row.
    ; --------------------------------------------------------

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
;
;   ESI = pointer to null-terminated string
;
; Prints the complete string.
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
; Move cursor to beginning of next row.
;
; If cursor is already on the last row:
;
;   - Scroll screen
;   - Keep cursor on last row
;
; ============================================================

console_newline:

    push eax
    push ebx
    push edx
    push edi


    ; --------------------------------------------------------
    ; Get current cursor offset
    ; --------------------------------------------------------

    mov edi, [console_cursor]

    sub edi, VGA_MEMORY


    ; --------------------------------------------------------
    ; Convert byte offset -> row number
    ; --------------------------------------------------------

    mov eax, edi

    xor edx, edx

    mov ebx, VGA_ROW_SIZE

    div ebx


    ; --------------------------------------------------------
    ; Move to next row
    ; --------------------------------------------------------

    inc eax


    ; --------------------------------------------------------
    ; Check if next row is visible
    ; --------------------------------------------------------

    cmp eax, SCREEN_HEIGHT

    jb console_newline_no_scroll


    ; --------------------------------------------------------
    ; Screen is full.
    ;
    ; Scroll screen upward.
    ; --------------------------------------------------------

    call console_scroll

    mov eax, SCREEN_HEIGHT - 1


console_newline_no_scroll:

    ; --------------------------------------------------------
    ; Convert row -> VGA address
    ; --------------------------------------------------------

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
; Scroll the VGA screen upward by one row.
;
; Before:
;
;   Row 0
;   Row 1
;   Row 2
;   ...
;   Row 24
;
; After:
;
;   Row 1 -> Row 0
;   Row 2 -> Row 1
;   ...
;   Row 24 -> Row 23
;   Blank  -> Row 24
;
; ============================================================

console_scroll:

    push eax
    push ecx
    push esi
    push edi
    pushfd


    ; --------------------------------------------------------
    ; Copy forward.
    ; --------------------------------------------------------

    cld


    ; --------------------------------------------------------
    ; Source = Row 1
    ; --------------------------------------------------------

    mov esi, VGA_MEMORY + VGA_ROW_SIZE


    ; --------------------------------------------------------
    ; Destination = Row 0
    ; --------------------------------------------------------

    mov edi, VGA_MEMORY


    ; --------------------------------------------------------
    ; Copy:
    ;
    ; 24 rows × 80 cells
    ;
    ; One VGA cell = 16 bits.
    ; --------------------------------------------------------

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
;
;   EAX = current VGA cursor address
;
; ============================================================

console_get_cursor:

    mov eax, [console_cursor]

    ret


; ============================================================
; console_set_cursor
;
; Input:
;
;   EAX = VGA cursor address
;
; Sets the console output position.
;
; ============================================================

console_set_cursor:

    mov [console_cursor], eax

    ret


; ============================================================
; console_draw_cursor
;
; Draw the visible input cursor.
;
; Current representation:
;
;   _
;
; The cursor is drawn at the current console cursor position.
;
; IMPORTANT:
;
; Only the Console subsystem accesses VGA memory.
;
; ============================================================

console_draw_cursor:

    push eax
    push edi


    ; --------------------------------------------------------
    ; Get current console cursor.
    ; --------------------------------------------------------

    mov edi, [console_cursor]


    ; --------------------------------------------------------
    ; Draw visible cursor.
    ; --------------------------------------------------------

    mov byte [edi], '_'

    mov byte [edi + 1], DEFAULT_ATTRIBUTE


    pop edi
    pop eax

    ret


; ============================================================
; console_remove_cursor
;
; Remove the visible input cursor.
;
; Replaces "_" with a blank space.
;
; The console cursor itself does NOT move.
;
; ============================================================

console_remove_cursor:

    push eax
    push edi


    ; --------------------------------------------------------
    ; Get current console cursor.
    ; --------------------------------------------------------

    mov edi, [console_cursor]


    ; --------------------------------------------------------
    ; Replace cursor with blank.
    ; --------------------------------------------------------

    mov byte [edi], ' '

    mov byte [edi + 1], DEFAULT_ATTRIBUTE


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
; Stores the VGA address of the next output position.
;
; ============================================================

console_cursor:

    dd VGA_MEMORY
