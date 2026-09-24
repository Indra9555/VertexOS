[bits 32]

section .text

global keyboard_handler
global input_buffer
global input_length
global command_ready
global clear_input_buffer


; ============================================================
; VertexOS Keyboard Driver
;
; IRQ1 = Keyboard
; Keyboard data port = 0x60
; PIC master command port = 0x20
;
; Features:
;   - Scancode -> ASCII conversion
;   - Shift support
;   - Input buffer
;   - Backspace
;   - Enter
; ============================================================


keyboard_handler:

    ; Save all general-purpose registers
    pushad


    ; --------------------------------------------------------
    ; Read keyboard scancode
    ; --------------------------------------------------------

    in al, 0x60


    ; --------------------------------------------------------
    ; Ignore key-release scancodes
    ; --------------------------------------------------------

    test al, 0x80
    jnz .key_release


    ; --------------------------------------------------------
    ; Check SHIFT
    ; --------------------------------------------------------

    cmp al, 0x2A
    je .shift_press

    cmp al, 0x36
    je .shift_press


    ; --------------------------------------------------------
    ; ENTER
    ; --------------------------------------------------------

    cmp al, 0x1C
    je .enter


    ; --------------------------------------------------------
    ; BACKSPACE
    ; --------------------------------------------------------

    cmp al, 0x0E
    je .backspace


    ; --------------------------------------------------------
    ; Convert scancode to character
    ; --------------------------------------------------------

    movzx eax, al

    cmp eax, 0x39
    ja .done


    ; --------------------------------------------------------
    ; Check Shift state
    ; --------------------------------------------------------

    cmp byte [shift_pressed], 0
    je .normal_character


    mov al, [shift_table + eax]

    jmp .character_ready


.normal_character:

    mov al, [keyboard_table + eax]


.character_ready:

    ; Ignore unmapped scancodes
    test al, al
    jz .done


    ; --------------------------------------------------------
    ; Don't accept characters after Enter
    ; until kernel clears the buffer
    ; --------------------------------------------------------

    cmp byte [command_ready], 1
    je .done


    ; --------------------------------------------------------
    ; Check input buffer limit
    ;
    ; Maximum = 79 characters
    ; One byte is reserved for null terminator.
    ; --------------------------------------------------------

    movzx ecx, byte [input_length]

    cmp ecx, 79
    jae .done


    ; --------------------------------------------------------
    ; Store character in input buffer
    ; --------------------------------------------------------

    mov [input_buffer + ecx], al

    inc byte [input_length]


    ; --------------------------------------------------------
    ; Null terminate string
    ; --------------------------------------------------------

    movzx ecx, byte [input_length]

    mov byte [input_buffer + ecx], 0


    ; --------------------------------------------------------
    ; Print character on VGA
    ; --------------------------------------------------------

    mov edi, [cursor_position]

    mov [edi], al
    mov byte [edi + 1], 0x0F

    add edi, 2

    mov [cursor_position], edi

    jmp .done


; ============================================================
; SHIFT PRESS
; ============================================================

.shift_press:

    mov byte [shift_pressed], 1

    jmp .done


; ============================================================
; KEY RELEASE
; ============================================================

.key_release:

    ; Left Shift release
    cmp al, 0xAA
    je .shift_release

    ; Right Shift release
    cmp al, 0xB6
    je .shift_release

    jmp .done


.shift_release:

    mov byte [shift_pressed], 0

    jmp .done


; ============================================================
; ENTER
; ============================================================

.enter:

    ; Don't accept another Enter until command is processed
    cmp byte [command_ready], 1
    je .done


    ; --------------------------------------------------------
    ; Null terminate input buffer
    ; --------------------------------------------------------

    movzx ecx, byte [input_length]

    mov byte [input_buffer + ecx], 0

    mov byte [command_ready], 1


    ; --------------------------------------------------------
    ; Move cursor to next VGA line
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

    jmp .done


; ============================================================
; BACKSPACE
; ============================================================

.backspace:

    ; Don't modify a completed command
    cmp byte [command_ready], 1
    je .done


    ; Check if buffer is empty
    cmp byte [input_length], 0
    je .done


    ; --------------------------------------------------------
    ; Remove last character from buffer
    ; --------------------------------------------------------

    dec byte [input_length]

    movzx ecx, byte [input_length]

    mov byte [input_buffer + ecx], 0


    ; --------------------------------------------------------
    ; Move VGA cursor backwards
    ; --------------------------------------------------------

    mov edi, [cursor_position]

    cmp edi, 0xB81E0
    jbe .done

    sub edi, 2


    ; --------------------------------------------------------
    ; Clear character on screen
    ; --------------------------------------------------------

    mov byte [edi], ' '
    mov byte [edi + 1], 0x0F

    mov [cursor_position], edi

    jmp .done


; ============================================================
; Send End Of Interrupt
; ============================================================

.done:

    mov al, 0x20
    out 0x20, al

    popad

    iretd


; ============================================================
; Clear input buffer
;
; Called by kernel after processing a command.
; ============================================================

clear_input_buffer:

    pushad

    mov byte [input_length], 0
    mov byte [command_ready], 0

    mov byte [input_buffer], 0

    popad

    ret


; ============================================================
; Keyboard state
; ============================================================

shift_pressed db 0


; ============================================================
; Input buffer
;
; Maximum 79 characters + null terminator
; ============================================================

input_buffer:

    times 80 db 0


input_length:

    db 0


command_ready:

    db 0


; ============================================================
; Current VGA cursor position
;
; Row 0 = 0xB8000
; Row 1 = 0xB80A0
; Row 2 = 0xB8140
; Row 3 = 0xB81E0
; ============================================================

cursor_position:

    dd 0xB81E0


; ============================================================
; Standard US keyboard Set 1 scancode table
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
; Shifted keyboard table
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
