[bits 32]

section .text

global keyboard_handler


; ============================================================
; VertexOS Keyboard Driver
;
; IRQ1 = Keyboard
; Keyboard data port = 0x60
; PIC master command port = 0x20
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
    ;
    ; Bit 7 = 1 means key released
    ; --------------------------------------------------------

    test al, 0x80
    jnz .key_release


    ; --------------------------------------------------------
    ; Check SHIFT key
    ; Left Shift  = 0x2A
    ; Right Shift = 0x36
    ; --------------------------------------------------------

    cmp al, 0x2A
    je .shift_press

    cmp al, 0x36
    je .shift_press


    ; --------------------------------------------------------
    ; Check ENTER
    ; --------------------------------------------------------

    cmp al, 0x1C
    je .enter


    ; --------------------------------------------------------
    ; Check BACKSPACE
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


    ; Shifted character
    mov al, [shift_table + eax]

    jmp .print_character


.normal_character:

    mov al, [keyboard_table + eax]


.print_character:

    ; Ignore unmapped scancodes
    test al, al
    jz .done


    ; --------------------------------------------------------
    ; Print character to VGA
    ; --------------------------------------------------------

    mov edi, [cursor_position]

    mov [edi], al
    mov byte [edi + 1], 0x0F

    add edi, 2

    mov [cursor_position], edi

    jmp .done


.shift_press:

    mov byte [shift_pressed], 1

    jmp .done


.key_release:

    ; Left Shift release = 0xAA
    cmp al, 0xAA
    je .shift_release

    ; Right Shift release = 0xB6
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

    mov edi, [cursor_position]

    ; Calculate next line.
    ; VGA row size = 80 characters = 160 bytes.
    ;
    ; Keep the cursor inside the text area.
    ;

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

    mov edi, [cursor_position]

    cmp edi, 0xB8000
    jbe .done


    ; Move one character backwards

    sub edi, 2


    ; Don't erase the status lines
    cmp edi, 0xB81E0
    jb .done


    ; Clear character

    mov byte [edi], ' '
    mov byte [edi + 1], 0x0F

    mov [cursor_position], edi

    jmp .done


; ============================================================
; Send End Of Interrupt to PIC
; ============================================================

.done:

    ; IRQ1 came from the master PIC.
    mov al, 0x20
    out 0x20, al

    popad

    iretd


; ============================================================
; Keyboard state
; ============================================================

shift_pressed db 0


; ============================================================
; Current VGA cursor position
;
; Row 0 = 0xB8000
; Row 1 = 0xB80A0
; Row 2 = 0xB8140
; Row 3 = 0xB81E0
; ============================================================

cursor_position dd 0xB81E0


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
