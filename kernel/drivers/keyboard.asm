[bits 32]

section .text

global keyboard_handler
global input_buffer
global input_buffer_write
global keyboard_get_input
global keyboard_print_prompt
global keyboard_command_ready
global keyboard_set_cursor
global keyboard_get_cursor


; ============================================================
; EXTERNAL CONSOLE
; ============================================================

extern console_putc
extern console_get_cursor
extern console_set_cursor
extern console_draw_cursor
extern console_remove_cursor
extern console_backspace


; ============================================================
; VertexOS Keyboard Driver
;
; IRQ1 = Keyboard
; Keyboard data port = 0x60
; PIC master command port = 0x20
;
; Responsibilities:
;
;   - Read keyboard scancodes
;   - Translate keys
;   - Handle Shift
;   - Handle Enter
;   - Handle Backspace
;   - Maintain input buffer
;   - Maintain command-ready state
;   - Manage command-line editing
;
; Display output is handled through the Console subsystem.
;
; Architecture:
;
;   Keyboard Driver
;        ↓
;     Console
;        ↓
;       VGA
;
; ============================================================


; ============================================================
; CONSTANTS
; ============================================================

MAX_INPUT_LENGTH    equ 76

INPUT_BUFFER_SIZE   equ MAX_INPUT_LENGTH + 1


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
    ; --------------------------------------------------------

    test al, 0x80

    jnz keyboard_key_release


    ; --------------------------------------------------------
    ; Left Shift
    ; --------------------------------------------------------

    cmp al, 0x2A

    je keyboard_shift_press


    ; --------------------------------------------------------
    ; Right Shift
    ; --------------------------------------------------------

    cmp al, 0x36

    je keyboard_shift_press


    ; --------------------------------------------------------
    ; Enter
    ; --------------------------------------------------------

    cmp al, 0x1C

    je keyboard_enter


    ; --------------------------------------------------------
    ; Backspace
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
    ; Prevent input overflow
    ; --------------------------------------------------------

    cmp dword [input_length], MAX_INPUT_LENGTH

    jae keyboard_done


    ; --------------------------------------------------------
    ; Save character in input buffer
    ; --------------------------------------------------------

    call buffer_write


    ; --------------------------------------------------------
    ; Display character through Console.
    ;
    ; AL = character
    ; --------------------------------------------------------

    call console_putc


    ; --------------------------------------------------------
    ; Increase input length.
    ; --------------------------------------------------------

    inc dword [input_length]


    ; --------------------------------------------------------
    ; Draw visible cursor.
    ;
    ; Console owns cursor rendering.
    ; --------------------------------------------------------

    call console_draw_cursor


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

    cmp al, 0xAA

    je keyboard_shift_release


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
;
; The keyboard driver does not execute commands.
;
; It only:
;
;   - removes the visible cursor
;   - moves to the next line
;   - marks the command ready
;
; The shell retrieves the command later.
; ============================================================

keyboard_enter:

    ; --------------------------------------------------------
    ; Ignore Enter when input is empty.
    ; --------------------------------------------------------

    cmp dword [input_length], 0

    je keyboard_done


    ; --------------------------------------------------------
    ; Remove visible cursor.
    ; --------------------------------------------------------

    call console_remove_cursor


    ; --------------------------------------------------------
    ; Move to next line.
    ;
    ; Console owns newline and scrolling.
    ; --------------------------------------------------------

    mov al, 10

    call console_putc


    ; --------------------------------------------------------
    ; Mark command ready.
    ; --------------------------------------------------------

    mov byte [keyboard_command_ready], 1


    ; --------------------------------------------------------
    ; Do NOT:
    ;
    ; - clear input buffer
    ; - reset input length
    ; - print a new prompt
    ;
    ; Shell performs those operations after execution.
    ; --------------------------------------------------------

    jmp keyboard_done


; ============================================================
; BACKSPACE
; ============================================================

keyboard_backspace:

    ; --------------------------------------------------------
    ; Nothing to delete.
    ; --------------------------------------------------------

    cmp dword [input_length], 0

    je keyboard_done


    ; --------------------------------------------------------
    ; Protect the prompt boundary.
    ;
    ; input_start stores the console cursor position at the
    ; beginning of the current user input.
    ; --------------------------------------------------------

    call console_get_cursor

    cmp eax, [input_start]

    je keyboard_done


    ; --------------------------------------------------------
    ; Remove visible cursor.
    ; --------------------------------------------------------

    call console_remove_cursor


    ; --------------------------------------------------------
    ; Console owns backspace behavior.
    ;
    ; This:
    ;
    ;   - moves cursor backward
    ;   - erases previous character
    ;   - keeps cursor at erased position
    ; --------------------------------------------------------

    call console_backspace


    ; --------------------------------------------------------
    ; Remove character from input buffer.
    ; --------------------------------------------------------

    call buffer_backspace


    ; --------------------------------------------------------
    ; Decrease input length.
    ; --------------------------------------------------------

    dec dword [input_length]


    ; --------------------------------------------------------
    ; Draw visible cursor.
    ; --------------------------------------------------------

    call console_draw_cursor


    jmp keyboard_done


; ============================================================
; KEYBOARD HANDLER EXIT
; ============================================================

keyboard_done:

    ; --------------------------------------------------------
    ; Send EOI to master PIC.
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
    ; The input buffer contains:
    ;
    ;   MAX_INPUT_LENGTH characters
    ;   + one byte reserved for '\0'
    ; --------------------------------------------------------

    cmp ebx, MAX_INPUT_LENGTH

    jae buffer_write_done


    mov [input_buffer + ebx], al


    inc ebx

    mov [input_buffer_write], ebx


    ; --------------------------------------------------------
    ; Keep the buffer null terminated.
    ; --------------------------------------------------------

    mov byte [input_buffer + ebx], 0


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
; PRINT PROMPT
;
; Prints:
;
;   > _
;
; The Console owns the output position.
; ============================================================

keyboard_print_prompt:

    push eax

    ; --------------------------------------------------------
    ; Print prompt.
    ; --------------------------------------------------------

    mov al, '>'
    call console_putc

    mov al, ' '
    call console_putc


    ; --------------------------------------------------------
    ; Save beginning of user input.
    ; --------------------------------------------------------

    call console_get_cursor
    mov [input_start], eax


    ; --------------------------------------------------------
    ; Draw cursor.
    ; --------------------------------------------------------

    call console_draw_cursor


    pop eax

    ret


; ============================================================
; GET CURSOR
;
; Returns:
;
;   EAX = current console cursor position
;
; ============================================================

keyboard_get_cursor:

    call console_get_cursor

    ret


; ============================================================
; SET CURSOR
;
; Input:
;
;   EAX = VGA cursor address
;
; Synchronizes the Console cursor.
;
; ============================================================

keyboard_set_cursor:

    call console_set_cursor

    ret


; ============================================================
; GET INPUT
;
; EDI = destination buffer
;
; Returns:
;
;   EAX = number of characters copied
;
; The keyboard buffer is cleared after copying.
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

    ; --------------------------------------------------------
    ; Null terminate destination.
    ; --------------------------------------------------------

    mov byte [edi + eax], 0


    ; --------------------------------------------------------
    ; Save returned length.
    ; --------------------------------------------------------

    mov edx, eax


    ; --------------------------------------------------------
    ; Clear keyboard buffer.
    ; --------------------------------------------------------

    call buffer_clear


    ; --------------------------------------------------------
    ; Reset buffer position.
    ; --------------------------------------------------------

    mov dword [input_buffer_write], 0


    ; --------------------------------------------------------
    ; Reset current input length.
    ; --------------------------------------------------------

    mov dword [input_length], 0


    ; --------------------------------------------------------
    ; Return length.
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
; Start of current input
; ============================================================

input_start:

    dd 0


; ============================================================
; Current input length
; ============================================================

input_length:

    dd 0


; ============================================================
; Command ready flag
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

    db '\','z','x','c','v','b','n','m'

    db ',','.','/'

    db 0

    db '*'

    db 0

    db ' '

    times 0x3A - ($ - keyboard_table) db 0


; ============================================================
; SHIFTED US KEYBOARD SET 1
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

    db '|','Z','X','C','V','B','N','M'

    db '<','>','?'

    db 0

    db '*'

    db 0

    db ' '

    times 0x3A - ($ - shift_table) db 0
