
[bits 32]

section .text

global keyboard_handler


; ============================================================
; VertexOS Keyboard Driver
;
; IRQ1 = Keyboard
; Keyboard data port = 0x60
; PIC master command port = 0x20
;
; Features:
;   - Normal keyboard input
;   - Shift
;   - Enter
;   - Backspace
;   - Input buffer
;   - VGA text output
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
    ; SHIFT
    ; Left Shift  = 0x2A
    ; Right Shift = 0x36
    ; --------------------------------------------------------

    cmp al, 0x2A
    je keyboard_shift_press

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
    jmp keyboard_print_character


keyboard_normal_character:

    mov al, [keyboard_table + eax]


keyboard_print_character:

    ; Ignore unmapped scancodes

    test al, al
    jz keyboard_done

    ; --------------------------------------------------------
    ; Save character into input buffer
    ; --------------------------------------------------------

    call buffer_write

    ; --------------------------------------------------------
    ; Print character to VGA
    ; --------------------------------------------------------

    mov edi, [cursor_position]

    mov [edi], al
    mov byte [edi + 1], 0x0F

    add edi, 2

    mov [cursor_position], edi

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

    ; Left Shift release = 0xAA

    cmp al, 0xAA
    je keyboard_shift_release

    ; Right Shift release = 0xB6

    cmp al, 0xB6
    je keyboard_shift_release

    jmp keyboard_done


keyboard_shift_release:

    mov byte [shift_pressed], 0

    jmp keyboard_done


; ============================================================
; ENTER
; ============================================================

keyboard_enter:

    ; --------------------------------------------------------
    ; Store newline in input buffer
    ; --------------------------------------------------------

    mov al, 0x0A

    call buffer_write

    ; --------------------------------------------------------
    ; Move cursor to next VGA line
    ;
    ; VGA row = 80 characters
    ; 80 * 2 = 160 bytes
    ; --------------------------------------------------------

    mov edi, [cursor_position]

    sub edi, 0xB8000

    mov eax, edi

    xor edx, edx

    mov ebx, 160

    div ebx

    inc eax

    imul eax, 160

    add eax, 0xB8000

    mov [cursor_position], eax

    jmp keyboard_done


; ============================================================
; BACKSPACE
; ============================================================

keyboard_backspace:

    mov edi, [cursor_position]

    cmp edi, 0xB8000
    jbe keyboard_done

    sub edi, 2

    ; Don't erase kernel information

    cmp edi, 0xB81E0
    jb keyboard_done

    ; Clear VGA character

    mov byte [edi], ' '
    mov byte [edi + 1], 0x0F

    mov [cursor_position], edi

    ; Remove character from input buffer

    call buffer_backspace

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
    ; Prevent overflow
    ; --------------------------------------------------------

    cmp ebx, INPUT_BUFFER_SIZE - 1
    jae buffer_write_full

    ; --------------------------------------------------------
    ; Store character
    ; --------------------------------------------------------

    mov [input_buffer + ebx], al

    inc ebx

    mov [input_buffer_write], ebx


buffer_write_full:

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
; DATA
; ============================================================

section .data


; ============================================================
; Keyboard state
; ============================================================

shift_pressed db 0


; ============================================================
; VGA cursor
;
; Row 0 = 0xB8000
; Row 1 = 0xB80A0
; Row 2 = 0xB8140
; Row 3 = 0xB81E0
; ============================================================

cursor_position dd 0xB81E0


; ============================================================
; INPUT BUFFER
; ============================================================

INPUT_BUFFER_SIZE equ 128

input_buffer:

    times INPUT_BUFFER_SIZE db 0


; Position where next character is written

input_buffer_write:

    dd 0


; Position from which kernel will eventually read

input_buffer_read:

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
