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
; CONSTANTS
; ============================================================

MAX_INPUT_LENGTH    equ 76
INPUT_BUFFER_SIZE   equ MAX_INPUT_LENGTH + 1

PS2_STATUS_PORT     equ 0x64
PS2_DATA_PORT       equ 0x60

PS2_STATUS_INPUT    equ 0x02

KEYBOARD_SET_LEDS   equ 0xED
KEYBOARD_ACK        equ 0xFA


; ============================================================
; KEYBOARD INTERRUPT HANDLER
; ============================================================

keyboard_handler:

    pushad

    in al, PS2_DATA_PORT

    ; --------------------------------------------------------
    ; Ignore key-release scancodes.
    ; --------------------------------------------------------

    test al, 0x80
    jnz keyboard_key_release

    ; --------------------------------------------------------
    ; Left Shift.
    ; --------------------------------------------------------

    cmp al, 0x2A
    je keyboard_shift_press

    ; --------------------------------------------------------
    ; Right Shift.
    ; --------------------------------------------------------

    cmp al, 0x36
    je keyboard_shift_press

    ; --------------------------------------------------------
    ; Caps Lock.
    ;
    ; Set-1 scancode: 0x3A
    ; --------------------------------------------------------

    cmp al, 0x3A
    je keyboard_caps_lock

    ; --------------------------------------------------------
    ; Enter.
    ; --------------------------------------------------------

    cmp al, 0x1C
    je keyboard_enter

    ; --------------------------------------------------------
    ; Backspace.
    ; --------------------------------------------------------

    cmp al, 0x0E
    je keyboard_backspace

    ; --------------------------------------------------------
    ; Convert scancode to character.
    ; --------------------------------------------------------

    movzx eax, al

    cmp eax, 0x39
    ja keyboard_done

    ; --------------------------------------------------------
    ; Select shifted or normal table.
    ;
    ; Shift controls symbols.
    ; Caps Lock only affects letters.
    ; --------------------------------------------------------

    cmp byte [shift_pressed], 0
    jne keyboard_shifted_character

    mov al, [keyboard_table + eax]

    jmp keyboard_character_ready


keyboard_shifted_character:

    mov al, [shift_table + eax]


keyboard_character_ready:

    ; --------------------------------------------------------
    ; Ignore unmapped keys.
    ; --------------------------------------------------------

    test al, al
    jz keyboard_done

    ; --------------------------------------------------------
    ; Apply Caps Lock to alphabetic characters.
    ; --------------------------------------------------------

    cmp al, 'a'
    jb keyboard_check_uppercase

    cmp al, 'z'
    ja keyboard_check_uppercase

    ; --------------------------------------------------------
    ; AL is lowercase.
    ;
    ; Caps ON + Shift OFF → uppercase
    ; --------------------------------------------------------

    cmp byte [caps_lock_pressed], 0
    je keyboard_character_ready_final

    cmp byte [shift_pressed], 0
    jne keyboard_character_ready_final

    sub al, 'a' - 'A'

    jmp keyboard_character_ready_final


keyboard_check_uppercase:

    cmp al, 'A'
    jb keyboard_character_ready_final

    cmp al, 'Z'
    ja keyboard_character_ready_final

    ; --------------------------------------------------------
    ; AL is uppercase.
    ;
    ; Caps ON + Shift ON → lowercase
    ; --------------------------------------------------------

    cmp byte [caps_lock_pressed], 0
    je keyboard_character_ready_final

    cmp byte [shift_pressed], 0
    je keyboard_character_ready_final

    add al, 'a' - 'A'


keyboard_character_ready_final:

    ; --------------------------------------------------------
    ; Prevent input overflow.
    ; --------------------------------------------------------

    cmp dword [input_length], MAX_INPUT_LENGTH
    jae keyboard_done

    ; --------------------------------------------------------
    ; Save character in input buffer.
    ; --------------------------------------------------------

    call buffer_write

    ; --------------------------------------------------------
    ; Display character through Console.
    ; --------------------------------------------------------

    call console_putc

    ; --------------------------------------------------------
    ; Increase input length.
    ; --------------------------------------------------------

    inc dword [input_length]

    ; --------------------------------------------------------
    ; Draw visible cursor.
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
; CAPS LOCK
; ============================================================

keyboard_caps_lock:

    ; --------------------------------------------------------
    ; Toggle software Caps Lock state.
    ; --------------------------------------------------------

    xor byte [caps_lock_pressed], 1

    ; --------------------------------------------------------
    ; Synchronize physical keyboard LED.
    ; --------------------------------------------------------

    call keyboard_update_led

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
; ============================================================

keyboard_enter:

    cmp dword [input_length], 0
    je keyboard_done

    call console_remove_cursor

    mov al, 10
    call console_putc

    mov byte [keyboard_command_ready], 1

    jmp keyboard_done


; ============================================================
; BACKSPACE
; ============================================================

keyboard_backspace:

    cmp dword [input_length], 0
    je keyboard_done

    ; --------------------------------------------------------
    ; Protect the prompt boundary.
    ; --------------------------------------------------------

    call console_get_cursor

    cmp eax, [input_start]
    je keyboard_done

    call console_remove_cursor

    call console_backspace

    call buffer_backspace

    dec dword [input_length]

    call console_draw_cursor

    jmp keyboard_done


; ============================================================
; KEYBOARD HANDLER EXIT
; ============================================================

keyboard_done:

    mov al, 0x20
    out 0x20, al

    popad

    iretd


; ============================================================
; UPDATE KEYBOARD LED
;
; Uses PS/2 keyboard command:
;
;   0xED = Set LEDs
;
; LED byte:
;
;   bit 0 = Scroll Lock
;   bit 1 = Num Lock
;   bit 2 = Caps Lock
;
; ============================================================

keyboard_update_led:

    push eax
    push ecx


    ; --------------------------------------------------------
    ; Wait until keyboard controller input buffer is clear.
    ;
    ; Status bit 1:
    ;
    ;   0 = controller can accept data
    ;   1 = controller input buffer full
    ;
    ; Use a bounded loop so a broken controller cannot hang
    ; the entire kernel forever.
    ; --------------------------------------------------------

    mov ecx, 0x0000FFFF

keyboard_led_wait_command:

    in al, PS2_STATUS_PORT

    test al, PS2_STATUS_INPUT
    jz keyboard_led_send_command

    loop keyboard_led_wait_command

    jmp keyboard_led_done


keyboard_led_send_command:

    mov al, KEYBOARD_SET_LEDS
    out PS2_DATA_PORT, al


    ; --------------------------------------------------------
    ; Wait for keyboard ACK.
    ;
    ; The keyboard normally responds with 0xFA.
    ;
    ; We poll the controller output buffer.
    ; --------------------------------------------------------

    mov ecx, 0x0000FFFF

keyboard_led_wait_ack:

    in al, PS2_STATUS_PORT

    test al, 0x01
    jnz keyboard_led_read_ack

    loop keyboard_led_wait_ack

    jmp keyboard_led_done


keyboard_led_read_ack:

    in al, PS2_DATA_PORT

    cmp al, KEYBOARD_ACK
    jne keyboard_led_done


    ; --------------------------------------------------------
    ; Wait until keyboard controller input buffer is clear
    ; before sending the LED state byte.
    ; --------------------------------------------------------

    mov ecx, 0x0000FFFF

keyboard_led_wait_data:

    in al, PS2_STATUS_PORT

    test al, PS2_STATUS_INPUT
    jz keyboard_led_send_data

    loop keyboard_led_wait_data

    jmp keyboard_led_done


keyboard_led_send_data:

    xor eax, eax

    ; --------------------------------------------------------
    ; Caps Lock = bit 2.
    ; --------------------------------------------------------

    cmp byte [caps_lock_pressed], 0
    je keyboard_led_caps_off

    mov al, 0x04


keyboard_led_caps_off:

    out PS2_DATA_PORT, al


keyboard_led_done:

    pop ecx
    pop eax

    ret


; ============================================================
; BUFFER WRITE
;
; AL = character
; ============================================================

buffer_write:

    push eax
    push ebx

    mov ebx, [input_buffer_write]

    cmp ebx, MAX_INPUT_LENGTH
    jae buffer_write_done

    mov [input_buffer + ebx], al

    inc ebx

    mov [input_buffer_write], ebx

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
; ============================================================

keyboard_print_prompt:

    push eax

    mov al, '>'
    call console_putc

    mov al, ' '
    call console_putc

    call console_get_cursor
    mov [input_start], eax

    call console_draw_cursor

    pop eax

    ret


; ============================================================
; GET CURSOR
; ============================================================

keyboard_get_cursor:

    call console_get_cursor

    ret


; ============================================================
; SET CURSOR
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

    mov edx, eax

    call buffer_clear

    mov dword [input_buffer_write], 0

    mov dword [input_length], 0

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

shift_pressed:
    db 0

caps_lock_pressed:
    db 0

input_start:
    dd 0

input_length:
    dd 0

keyboard_command_ready:
    db 0

input_buffer:
    times INPUT_BUFFER_SIZE db 0

input_buffer_write:
    dd 0


; ============================================================
; KEYBOARD TABLE
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
; SHIFT TABLE
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
