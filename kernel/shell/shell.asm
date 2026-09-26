[bits 32]

section .text

global shell_init
global shell_update


extern keyboard_get_input
extern keyboard_command_ready
extern keyboard_print_prompt
extern keyboard_get_cursor
extern keyboard_set_cursor


; ============================================================
; VertexOS Shell
;
; Commands:
;
;   help
;   about
;   clear
;   echo <text>
; ============================================================


; ============================================================
; CONSTANTS
; ============================================================

VGA_MEMORY       equ 0xB8000
SCREEN_WIDTH     equ 80
SCREEN_HEIGHT    equ 25
VGA_ROW_SIZE     equ 160

SHELL_BUFFER_SIZE equ 128


; ============================================================
; SHELL INITIALIZATION
; ============================================================

shell_init:

    mov byte [shell_initialized], 1

    ret


; ============================================================
; SHELL UPDATE
;
; Called by kernel after an interrupt wakes the CPU.
; ============================================================

shell_update:

    ; Check whether Enter was pressed
    cmp byte [keyboard_command_ready], 1

    jne shell_update_done


    ; Clear command-ready flag
    mov byte [keyboard_command_ready], 0


    ; --------------------------------------------------------
    ; Get command from keyboard driver
    ; --------------------------------------------------------

    mov edi, shell_buffer

    call keyboard_get_input

    mov [shell_command_length], eax


    ; Execute command
    call shell_execute


shell_update_done:

    ret


; ============================================================
; SHELL EXECUTE
; ============================================================

shell_execute:

    ; --------------------------------------------------------
    ; Empty command
    ; --------------------------------------------------------

    cmp dword [shell_command_length], 0

    je shell_execute_done


    ; --------------------------------------------------------
    ; Synchronize shell output cursor with keyboard cursor
    ; --------------------------------------------------------

    call keyboard_get_cursor

    mov [print_cursor], eax


    ; --------------------------------------------------------
    ; HELP
    ; --------------------------------------------------------

    mov esi, shell_buffer

    mov edi, cmd_help

    call strings_equal

    cmp eax, 1

    je shell_cmd_help


    ; --------------------------------------------------------
    ; ABOUT
    ; --------------------------------------------------------

    mov esi, shell_buffer

    mov edi, cmd_about

    call strings_equal

    cmp eax, 1

    je shell_cmd_about


    ; --------------------------------------------------------
    ; CLEAR
    ; --------------------------------------------------------

    mov esi, shell_buffer

    mov edi, cmd_clear

    call strings_equal

    cmp eax, 1

    je shell_cmd_clear


    ; --------------------------------------------------------
    ; ECHO
    ; --------------------------------------------------------

    mov esi, shell_buffer

    mov edi, cmd_echo

    call string_starts_with

    cmp eax, 1

    je shell_cmd_echo


    ; --------------------------------------------------------
    ; UNKNOWN COMMAND
    ; --------------------------------------------------------

    call print_newline

    mov esi, unknown_msg

    call print_string

    call print_newline

    call shell_new_prompt

    jmp shell_execute_done


; ============================================================
; HELP
; ============================================================

shell_cmd_help:

    call print_newline

    mov esi, help_title
    call print_string

    call print_newline

    mov esi, help_line1
    call print_string

    call print_newline

    mov esi, help_line2
    call print_string

    call print_newline

    mov esi, help_line3
    call print_string

    call print_newline

    mov esi, help_line4
    call print_string

    call print_newline

    call shell_new_prompt

    jmp shell_execute_done


; ============================================================
; ABOUT
; ============================================================

shell_cmd_about:

    call print_newline

    mov esi, about_line1
    call print_string

    call print_newline

    mov esi, about_line2
    call print_string

    call print_newline

    mov esi, about_line3
    call print_string

    call print_newline

    mov esi, about_line4
    call print_string

    call print_newline

    call shell_new_prompt

    jmp shell_execute_done


; ============================================================
; CLEAR
; ============================================================

shell_cmd_clear:

    call clear_screen


    ; --------------------------------------------------------
    ; Put cursor at row 3
    ; --------------------------------------------------------

    mov eax, VGA_MEMORY + (3 * VGA_ROW_SIZE)

    call keyboard_set_cursor


    ; Synchronize shell cursor
    mov [print_cursor], eax


    ; Print new prompt
    call keyboard_print_prompt


    jmp shell_execute_done


; ============================================================
; ECHO
;
; Syntax:
;
; echo hello
; ============================================================

shell_cmd_echo:

    ; New line after entered command
    call print_newline


    ; Find space after "echo"
    mov esi, shell_buffer


shell_echo_find_space:

    mov al, [esi]

    cmp al, 0

    je shell_echo_empty


    cmp al, ' '

    je shell_echo_found_space


    inc esi

    jmp shell_echo_find_space


shell_echo_found_space:

    inc esi

    call print_string

    call print_newline

    call shell_new_prompt

    jmp shell_execute_done


shell_echo_empty:

    call print_newline

    call shell_new_prompt

    jmp shell_execute_done


; ============================================================
; CREATE NEW PROMPT
;
; Uses the shell's current output cursor and gives it back
; to the keyboard driver.
; ============================================================

shell_new_prompt:

    mov eax, [print_cursor]

    call keyboard_set_cursor

    call keyboard_print_prompt

    ret


; ============================================================
; SHELL EXECUTION DONE
; ============================================================

shell_execute_done:

    ret


; ============================================================
; STRING EQUAL
;
; ESI = string 1
; EDI = string 2
;
; EAX = 1 if equal
; EAX = 0 otherwise
; ============================================================

strings_equal:

    push ebx


strings_equal_loop:

    mov al, [esi]

    mov bl, [edi]

    cmp al, bl

    jne strings_not_equal


    cmp al, 0

    je strings_equal_yes


    inc esi
    inc edi

    jmp strings_equal_loop


strings_equal_yes:

    mov eax, 1

    pop ebx

    ret


strings_not_equal:

    xor eax, eax

    pop ebx

    ret


; ============================================================
; STRING STARTS WITH
;
; ESI = input
; EDI = prefix
; ============================================================

string_starts_with:

    push ebx


string_starts_loop:

    mov al, [edi]

    cmp al, 0

    je string_starts_yes


    mov bl, [esi]

    cmp bl, al

    jne string_starts_no


    inc esi
    inc edi

    jmp string_starts_loop


string_starts_yes:

    mov eax, 1

    pop ebx

    ret


string_starts_no:

    xor eax, eax

    pop ebx

    ret


; ============================================================
; PRINT STRING
;
; ESI = null-terminated string
; ============================================================

print_string:

    push eax
    push edi


    mov edi, [print_cursor]


print_string_loop:

    lodsb

    test al, al

    jz print_string_done


    mov [edi], al

    mov byte [edi + 1], 0x0F

    add edi, 2

    jmp print_string_loop


print_string_done:

    mov [print_cursor], edi


    pop edi
    pop eax

    ret


; ============================================================
; PRINT NEWLINE
; ============================================================

print_newline:

    push eax
    push ebx
    push edx
    push edi


    mov edi, [print_cursor]

    sub edi, VGA_MEMORY

    mov eax, edi

    xor edx, edx

    mov ebx, VGA_ROW_SIZE

    div ebx

    inc eax

    cmp eax, SCREEN_HEIGHT

    jb print_newline_same_screen


    ; If bottom reached, clear screen
    call clear_screen

    mov eax, 3


print_newline_same_screen:

    imul eax, VGA_ROW_SIZE

    add eax, VGA_MEMORY

    mov [print_cursor], eax


    pop edi
    pop edx
    pop ebx
    pop eax

    ret


; ============================================================
; CLEAR SCREEN
; ============================================================

clear_screen:

    push eax
    push ecx
    push edi


    mov edi, VGA_MEMORY

    mov ecx, SCREEN_WIDTH * SCREEN_HEIGHT

    mov ax, 0x0720


clear_screen_loop:

    mov [edi], ax

    add edi, 2

    loop clear_screen_loop


    mov dword [print_cursor], VGA_MEMORY


    pop edi
    pop ecx
    pop eax

    ret


; ============================================================
; DATA
; ============================================================

section .data


shell_initialized:

    db 0


shell_command_length:

    dd 0


shell_buffer:

    times SHELL_BUFFER_SIZE db 0


; ============================================================
; SHELL OUTPUT CURSOR
; ============================================================

print_cursor:

    dd VGA_MEMORY + (3 * VGA_ROW_SIZE)


; ============================================================
; COMMAND STRINGS
; ============================================================

cmd_help:

    db "help", 0


cmd_about:

    db "about", 0


cmd_clear:

    db "clear", 0


cmd_echo:

    db "echo", 0


; ============================================================
; HELP TEXT
; ============================================================

help_title:

    db "VertexOS Shell - Available Commands", 0


help_line1:

    db "  help  - Show available commands", 0


help_line2:

    db "  about - Show information about VertexOS", 0


help_line3:

    db "  clear - Clear the screen", 0


help_line4:

    db "  echo  - Print text", 0


; ============================================================
; ABOUT TEXT
; ============================================================

about_line1:

    db "VertexOS", 0


about_line2:

    db "A 32-bit x86 operating system", 0


about_line3:

    db "Built from scratch with NASM", 0


about_line4:

    db "Kernel running in Protected Mode", 0


; ============================================================
; UNKNOWN COMMAND
; ============================================================

unknown_msg:

    db "Unknown command. Type 'help'.", 0
