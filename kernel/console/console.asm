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
;   80 columns × 25 rows
;
; Responsibilities:
;   - VGA screen management
;   - Character output
;   - String output
;   - Newlines
;   - Scrolling
;   - Console cursor management
;
; ============================================================


; ============================================================
; CONSTANTS
; ============================================================

VGA_MEMORY          equ 0xB8000

SCREEN_WIDTH        equ 80
SCREEN_HEIGHT       equ 25

VGA_ROW_SIZE        equ SCREEN_WIDTH * 2

DEFAULT_ATTRIBUTE   equ 0x0F


; ============================================================
; console_init
;
; Initializes the console.
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


    ; --------------------------------------------------------
    ; Reset console cursor
    ; --------------------------------------------------------

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
;
; ============================================================

console_putc:

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
    ; Move cursor forward
    ; --------------------------------------------------------

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


    ; --------------------------------------------------------
    ; Get current cursor
    ; --------------------------------------------------------

    mov edi, [console_cursor]

    sub edi, VGA_MEMORY


    ; --------------------------------------------------------
    ; Convert byte offset to row number
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
    ; Check whether next row is inside screen
    ; --------------------------------------------------------

    cmp eax, SCREEN_HEIGHT

    jb console_newline_same_screen


    ; --------------------------------------------------------
    ; Screen full
    ;
    ; Scroll rows upward.
    ; New cursor goes to last row.
    ; --------------------------------------------------------

    call console_scroll

    mov eax, SCREEN_HEIGHT - 1


console_newline_same_screen:

    ; --------------------------------------------------------
    ; Convert row number to VGA address
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
; Moves rows 1-24 upward.
;
; Row 0 <- Row 1
; Row 1 <- Row 2
; ...
; Row 23 <- Row 24
;
; Row 24 is cleared.
;
; ============================================================

console_scroll:

    push eax
    push ecx
    push esi
    push edi


    ; --------------------------------------------------------
    ; Source = row 1
    ; --------------------------------------------------------

    mov esi, VGA_MEMORY + VGA_ROW_SIZE


    ; --------------------------------------------------------
    ; Destination = row 0
    ; --------------------------------------------------------

    mov edi, VGA_MEMORY


    ; --------------------------------------------------------
    ; Copy:
    ;
    ; 24 rows × 80 cells
    ;
    ; Each cell = 16 bits
    ; --------------------------------------------------------

    mov ecx, (SCREEN_HEIGHT - 1) * SCREEN_WIDTH

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
; Used by higher-level components that need to synchronize
; their output position with the console.
;
; ============================================================

console_set_cursor:

    mov [console_cursor], eax

    ret


; ============================================================
; DATA
; ============================================================

section .data


; ============================================================
; Console cursor
;
; Stores the VGA memory address of the next output position.
;
; ============================================================

console_cursor:

    dd VGA_MEMORY
