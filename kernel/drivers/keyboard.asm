[bits 32]

section .text

global keyboard_handler
global keyboard_service
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
extern timer_ticks


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

    ; Handle ACK bytes separately from normal key scancodes.
    cmp al, KEYBOARD_ACK
    jne keyboard_dispatch_scancode

    cmp byte [keyboard_led_state], 1
    je keyboard_led_command_ack

    cmp byte [keyboard_led_state], 2
    je keyboard_led_data_ack

    ; Ignore unexpected or late ACKs.
    jmp keyboard_done

keyboard_led_command_ack:
    mov byte [keyboard_led_state], 3
    jmp keyboard_done

keyboard_led_data_ack:
    mov byte [keyboard_led_state], 4
    jmp keyboard_done

keyboard_dispatch_scancode:

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

    cmp byte [keyboard_command_ready], 1
    je keyboard_done

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

    ; Queue an LED update; never wait for PS/2 hardware in IRQ1.
    mov al, [caps_lock_pressed]
    shl al, 2
    mov [keyboard_led_value], al
    mov byte [keyboard_led_pending], 1

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

    cmp byte [keyboard_command_ready], 1
    je keyboard_done

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

    cmp byte [keyboard_command_ready], 1
    je keyboard_done

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
; NON-BLOCKING KEYBOARD LED SERVICE
;
; keyboard_led_state:
;   0 = idle
;   1 = waiting for ACK to 0xED
;   2 = waiting for ACK to LED data
;   3 = ACK received; send LED data next
;   4 = LED data ACK received; finish
;   5 = timeout recovery cooldown
;
; Timeout: 100 timer ticks, approximately one second.
; After a timeout, wait another second before retrying.
; ============================================================

KEYBOARD_LED_TIMEOUT_TICKS equ 100

keyboard_service:
    pushad

    ; Check whether either ACK wait has timed out.
    cmp byte [keyboard_led_state], 1
    je keyboard_led_check_timeout
    cmp byte [keyboard_led_state], 2
    je keyboard_led_check_timeout
    cmp byte [keyboard_led_state], 5
    je keyboard_led_cooldown

    cmp byte [keyboard_led_state], 4
    je keyboard_led_finish
    cmp byte [keyboard_led_state], 3
    je keyboard_led_send_value
    cmp byte [keyboard_led_state], 0
    jne keyboard_led_service_done

    cmp byte [keyboard_led_pending], 1
    jne keyboard_led_service_done

    ; Send only when the controller input buffer is clear.
    in al, PS2_STATUS_PORT
    test al, PS2_STATUS_INPUT
    jnz keyboard_led_service_done

    mov byte [keyboard_led_pending], 0
    mov byte [keyboard_led_state], 1
    mov eax, [timer_ticks]
    mov [keyboard_led_started_tick], eax
    mov al, KEYBOARD_SET_LEDS
    out PS2_DATA_PORT, al
    jmp keyboard_led_service_done

keyboard_led_check_timeout:
    mov eax, [timer_ticks]
    sub eax, [keyboard_led_started_tick]
    cmp eax, KEYBOARD_LED_TIMEOUT_TICKS
    jb keyboard_led_service_done

    ; Recover from a missing ACK without blocking keyboard input.
    ; Preserve a retry request for the latest LED value.
    mov byte [keyboard_led_pending], 1
    mov byte [keyboard_led_state], 5
    mov eax, [timer_ticks]
    mov [keyboard_led_started_tick], eax
    jmp keyboard_led_service_done

keyboard_led_cooldown:
    mov eax, [timer_ticks]
    sub eax, [keyboard_led_started_tick]
    cmp eax, KEYBOARD_LED_TIMEOUT_TICKS
    jb keyboard_led_service_done

    ; Cooldown reduces the chance that a late ACK is mistaken
    ; for the response to a newly issued command.
    mov byte [keyboard_led_state], 0
    jmp keyboard_led_service_done

keyboard_led_send_value:
    in al, PS2_STATUS_PORT
    test al, PS2_STATUS_INPUT
    jnz keyboard_led_service_done

    mov al, [keyboard_led_value]
    mov byte [keyboard_led_state], 2
    mov eax, [timer_ticks]
    mov [keyboard_led_started_tick], eax
    mov al, [keyboard_led_value]
    out PS2_DATA_PORT, al
    jmp keyboard_led_service_done

keyboard_led_finish:
    mov byte [keyboard_led_state], 0

keyboard_led_service_done:
    popad
    ret


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

; Asynchronous PS/2 LED update state.
keyboard_led_pending:
    db 0

keyboard_led_state:
    db 0

keyboard_led_value:
    db 0

keyboard_led_started_tick:
    dd 0

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
