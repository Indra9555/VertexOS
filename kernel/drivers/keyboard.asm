[bits 32]

section .text

global keyboard_handler
global input_buffer
global input_buffer_write
global keyboard_get_input
global keyboard_print_prompt
global keyboard_command_ready


; ============================================================
; VertexOS Keyboard Driver
;
; IRQ1 = Keyboard
; Keyboard data port = 0x60
; PIC master command port = 0x20
;
; Features:
;   - Normal characters
;   - Shift
;   - Enter
;   - Backspace
;   - Input buffer
;   - Command-line editing
;   - Prompt protection
;   - Visible "_" cursor
; ============================================================


; ============================================================
; CONSTANTS
; ============================================================

VGA_MEMORY          equ 0xB8000

SCREEN_WIDTH        equ 80
SCREEN_HEIGHT       equ 25

VGA_ROW_SIZE        equ SCREEN_WIDTH * 2

INPUT_START         equ VGA_MEMORY + (3 * VGA_ROW_SIZE)

INPUT_BUFFER_SIZE   equ 128

MAX_INPUT_LENGTH    equ 76


; ============================================================
; KEYBOARD INTERRUPT HANDLER
; ============================================================

keyboard_handler:

    pushad

    ; --------------------------------------------------------
    ; Read keyboard scancode
    ; --------------------------------------------------------

    in al, 0x60


    ; --------------------------------------------------------
    ; Ignore key-release scancodes
    ; Bit 7 = 1 means key released
    ; --------------------------------------------------------

    test al, 0x80
    jnz keyboard_key_release


    ; --------------------------------------------------------
    ; LEFT SHIFT
    ; --------------------------------------------------------

    cmp al, 0x2A
    je keyboard_shift_press


    ; --------------------------------------------------------
    ; RIGHT SHIFT
    ; --------------------------------------------------------

    cmp al, 0x36
    je keyboard_shift_press


    ; --------------------------------------------------------
    ; ENTER
    ; --------------------------------------------------------

    cmp al, 0x1C
    je keyboard_enter


    ; --------------------------------------------------------
    ; BACKSPACE
    ; --------------------------------------------------------

    cmp al, 0x0E
    je keyboard_backspace


    ; --------------------------------------------------------
    ; Convert scancode to character
    ; --------------------------------------------------------

    movzx eax, al

    cmp eax, 0x39
    ja keyboard_done


    ; --------------------------------------------------------
    ; Check Shift state
    ; --------------------------------------------------------

    cmp byte [shift_pressed], 0
    je keyboard_normal_character


    mov al, [shift_table + eax]

    jmp keyboard_character_ready


keyboard_normal_character:

    mov al, [keyboard_table + eax]


keyboard_character_ready:

    ; --------------------------------------------------------
    ; Ignore unmapped keys
    ; --------------------------------------------------------

    test al, al
    jz keyboard_done


    ; --------------------------------------------------------
    ; Prevent input buffer overflow
    ; --------------------------------------------------------

    cmp dword [input_length], MAX_INPUT_LENGTH
    jae keyboard_done


    ; --------------------------------------------------------
    ; Current cursor points to "_"
    ;
    ; Replace "_" with typed character.
    ; --------------------------------------------------------

    mov edi, [cursor_position]

    mov [edi], al
    mov byte [edi + 1], 0x0F


    ; --------------------------------------------------------
    ; Save character in input buffer
    ; --------------------------------------------------------

    call buffer_write


    ; --------------------------------------------------------
    ; Move cursor forward
    ; --------------------------------------------------------

    add edi, 2

    mov [cursor_position], edi


    ; --------------------------------------------------------
    ; Increase input length
    ; --------------------------------------------------------

    inc dword [input_length]


    ; --------------------------------------------------------
    ; Draw new cursor
    ; --------------------------------------------------------

    call keyboard_draw_cursor

    jmp keyboard_done


; ============================================================
; SHIFT PRESS
; ============================================================

keyboard_shift_press:

    mov byte [shift_pressed], 1

    jmp keyboard_done


; ============================================================
; KEY RELEASE
; ============================================================

keyboard_key_release:

    ; Left Shift release

    cmp al, 0xAA
    je keyboard_shift_release


    ; Right Shift release

    cmp al, 0xB6
    je keyboard_shift_release


    jmp keyboard_done


; ============================================================
; SHIFT RELEASE
; ============================================================

keyboard_shift_release:

    mov byte [shift_pressed], 0

    jmp keyboard_done


; ============================================================
; ENTER
; ============================================================

keyboard_enter:

    ; --------------------------------------------------------
    ; Do nothing if input line is empty
    ; --------------------------------------------------------

    cmp dword [input_length], 0
    je keyboard_done


    ; --------------------------------------------------------
    ; Erase old cursor
    ; --------------------------------------------------------

    mov edi, [cursor_position]

    mov byte [edi], ' '
    mov byte [edi + 1], 0x0F


    ; --------------------------------------------------------
    ; Mark command as ready
    ; --------------------------------------------------------

    mov byte [keyboard_command_ready], 1


    ; --------------------------------------------------------
    ; Calculate next VGA row
    ; --------------------------------------------------------

    mov edi, [cursor_position]

    sub edi, VGA_MEMORY

    mov eax, edi

    xor edx, edx

    mov ebx, VGA_ROW_SIZE

    div ebx

    inc eax


    ; --------------------------------------------------------
    ; Prevent going beyond bottom of screen
    ; --------------------------------------------------------

    cmp eax, SCREEN_HEIGHT

    jb keyboard_enter_same_screen


    ; --------------------------------------------------------
    ; Screen full
    ; Clear screen and restart input area
    ; --------------------------------------------------------

    call keyboard_clear_screen

    mov eax, 3


keyboard_enter_same_screen:

    imul eax, VGA_ROW_SIZE

    add eax, VGA_MEMORY

    mov [cursor_position], eax


    ; --------------------------------------------------------
    ; Print new prompt
    ; This also draws the new "_"
    ; --------------------------------------------------------

    call keyboard_print_prompt


    ; --------------------------------------------------------
    ; Reset current input line
    ; --------------------------------------------------------

    mov dword [input_length], 0

    mov dword [input_buffer_write], 0

    call buffer_clear


    jmp keyboard_done


; ============================================================
; BACKSPACE
; ============================================================

keyboard_backspace:

    ; --------------------------------------------------------
    ; Nothing to delete
    ; --------------------------------------------------------

    cmp dword [input_length], 0
    je keyboard_done


    ; --------------------------------------------------------
    ; IMPORTANT:
    ;
    ; cursor_position currently points to the visible "_".
    ;
    ; Erase that OLD cursor first.
    ; This prevents the "_" trail bug.
    ; --------------------------------------------------------

    mov edi, [cursor_position]

    mov byte [edi], ' '
    mov byte [edi + 1], 0x0F


    ; --------------------------------------------------------
    ; Move cursor backwards to previous character
    ; --------------------------------------------------------

    sub edi, 2


    ; --------------------------------------------------------
    ; Never move before current prompt
    ; --------------------------------------------------------

    cmp edi, [input_start]

    jb keyboard_backspace_restore_cursor


    ; --------------------------------------------------------
    ; Erase previous character
    ; --------------------------------------------------------

    mov byte [edi], ' '
    mov byte [edi + 1], 0x0F


    ; --------------------------------------------------------
    ; Update cursor position
    ; --------------------------------------------------------

    mov [cursor_position], edi


    ; --------------------------------------------------------
    ; Remove character from input buffer
    ; --------------------------------------------------------

    call buffer_backspace


    ; --------------------------------------------------------
    ; Decrease input length
    ; --------------------------------------------------------

    dec dword [input_length]


    ; --------------------------------------------------------
    ; Draw new cursor
    ; --------------------------------------------------------

    call keyboard_draw_cursor

    jmp keyboard_done


keyboard_backspace_restore_cursor:

    ; --------------------------------------------------------
    ; Safety case:
    ; Restore cursor at current position
    ; --------------------------------------------------------

    mov [cursor_position], edi

    call keyboard_draw_cursor

    jmp keyboard_done


; ============================================================
; KEYBOARD HANDLER EXIT
; ============================================================

keyboard_done:

    ; --------------------------------------------------------
    ; Send End Of Interrupt to master PIC
    ; --------------------------------------------------------

    mov al, 0x20
    out 0x20, al

    popad

    iretd


; ============================================================
; BUFFER WRITE
;
; AL = character
; ============================================================

buffer_write:

    push eax
    push ebx

    mov ebx, [input_buffer_write]


    ; --------------------------------------------------------
    ; Prevent buffer overflow
    ; --------------------------------------------------------

    cmp ebx, INPUT_BUFFER_SIZE - 1
    jae buffer_write_done


    ; --------------------------------------------------------
    ; Store character
    ; --------------------------------------------------------

    mov [input_buffer + ebx], al

    inc ebx

    mov [input_buffer_write], ebx


buffer_write_done:

    pop ebx
    pop eax

    ret


; ============================================================
; BUFFER BACKSPACE
; ============================================================

buffer_backspace:

    push eax
    push ebx

    mov ebx, [input_buffer_write]

    cmp ebx, 0
    je buffer_backspace_done

    dec ebx

    mov byte [input_buffer + ebx], 0

    mov [input_buffer_write], ebx


buffer_backspace_done:

    pop ebx
    pop eax

    ret


; ============================================================
; BUFFER CLEAR
; ============================================================

buffer_clear:

    push eax
    push ecx

    xor eax, eax


buffer_clear_loop:

    cmp eax, INPUT_BUFFER_SIZE
    jae buffer_clear_done

    mov byte [input_buffer + eax], 0

    inc eax

    jmp buffer_clear_loop


buffer_clear_done:

    pop ecx
    pop eax

    ret


; ============================================================
; CLEAR VGA SCREEN
; ============================================================

keyboard_clear_screen:

    push eax
    push ecx
    push edi

    mov edi, VGA_MEMORY

    mov ecx, SCREEN_WIDTH * SCREEN_HEIGHT

    mov ax, 0x0720


keyboard_clear_screen_loop:

    mov [edi], ax

    add edi, 2

    loop keyboard_clear_screen_loop


    pop edi
    pop ecx
    pop eax

    ret


; ============================================================
; DRAW CURSOR
;
; Draws "_" at the current cursor position.
;
; Example:
;
; > hello_
;
; ============================================================

keyboard_draw_cursor:

    push eax
    push edi

    mov edi, [cursor_position]

    mov byte [edi], '_'
    mov byte [edi + 1], 0x0F

    pop edi
    pop eax

    ret


; ============================================================
; PRINT PROMPT
;
; Prints:
;
; > _
;
; ============================================================

keyboard_print_prompt:

    push eax
    push edi

    mov edi, [cursor_position]


    ; --------------------------------------------------------
    ; Print >
    ; --------------------------------------------------------

    mov byte [edi], '>'
    mov byte [edi + 1], 0x0F

    add edi, 2


    ; --------------------------------------------------------
    ; Print space
    ; --------------------------------------------------------

    mov byte [edi], ' '
    mov byte [edi + 1], 0x0F

    add edi, 2


    ; --------------------------------------------------------
    ; Save input start
    ; --------------------------------------------------------

    mov [cursor_position], edi

    mov [input_start], edi


    ; --------------------------------------------------------
    ; Draw cursor
    ; --------------------------------------------------------

    call keyboard_draw_cursor


    pop edi
    pop eax

    ret


; ============================================================
; GET INPUT
;
; EDI = destination buffer
;
; Returns:
;   EAX = number of characters copied
; ============================================================

keyboard_get_input:

    push ebx
    push ecx
    push edx
    push esi


    xor eax, eax

    mov esi, input_buffer

    mov ecx, [input_buffer_write]


    test ecx, ecx
    jz keyboard_get_input_empty


keyboard_get_input_loop:

    mov bl, [esi + eax]

    mov [edi + eax], bl

    inc eax

    cmp eax, ecx

    jb keyboard_get_input_loop


keyboard_get_input_empty:

    mov byte [edi + eax], 0


    ; --------------------------------------------------------
    ; Save length
    ; --------------------------------------------------------

    mov edx, eax


    ; --------------------------------------------------------
    ; Clear input buffer
    ; --------------------------------------------------------

    call buffer_clear


    ; --------------------------------------------------------
    ; Reset write position
    ; --------------------------------------------------------

    mov dword [input_buffer_write], 0


    ; --------------------------------------------------------
    ; Reset input length
    ; --------------------------------------------------------

    mov dword [input_length], 0


    ; --------------------------------------------------------
    ; Return length
    ; --------------------------------------------------------

    mov eax, edx


    pop esi
    pop edx
    pop ecx
    pop ebx

    ret


; ============================================================
; DATA
; ============================================================

section .data


; ============================================================
; Keyboard state
; ============================================================

shift_pressed:

    db 0


; ============================================================
; Current VGA cursor position
; ============================================================

cursor_position:

    dd INPUT_START


; ============================================================
; Start of current input
;
; Backspace cannot move before this address.
; ============================================================

input_start:

    dd INPUT_START


; ============================================================
; Current input length
; ============================================================

input_length:

    dd 0


; ============================================================
; Command ready flag
;
; 0 = no command submitted
; 1 = Enter pressed
; ============================================================

keyboard_command_ready:

    db 0


; ============================================================
; Input buffer
; ============================================================

input_buffer:

    times INPUT_BUFFER_SIZE db 0


; ============================================================
; Next buffer write position
; ============================================================

input_buffer_write:

    dd 0


; ============================================================
; STANDARD US KEYBOARD SET 1
; ============================================================

keyboard_table:

    db 0
    db 27

    db '1','2','3','4','5','6','7','8','9','0'

    db '-','='

    db 8
    db 9

    db 'q','w','e','r','t','y','u','i','o','p'

    db '[',']'

    db 13
    db 0

    db 'a','s','d','f','g','h','j','k','l'

    db ';',"'" 

    db '`'

    db 0

    db '\'

    db 'z','x','c','v','b','n','m'

    db ',','.','/'

    db 0
    db 0
    db 0

    db ' '

    times 58 db 0


; ============================================================
; SHIFTED KEYBOARD TABLE
; ============================================================

shift_table:

    db 0
    db 27

    db '!','@','#','$','%','^','&','*','(',')'

    db '_','+'

    db 8
    db 9

    db 'Q','W','E','R','T','Y','U','I','O','P'

    db '{','}'

    db 13
    db 0

    db 'A','S','D','F','G','H','J','K','L'

    db ':','"'

    db '~'

    db 0

    db '|'

    db 'Z','X','C','V','B','N','M'

    db '<','>','?'

    db 0
    db 0
    db 0

    db ' '

    times 58 db 0
