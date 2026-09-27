[bits 32]

section .text

global shell_init
global shell_update

extern keyboard_get_input
extern keyboard_command_ready
extern keyboard_print_prompt
extern keyboard_set_cursor

extern console_print
extern console_newline
extern console_clear
extern console_get_cursor
extern console_set_cursor


; ============================================================
; VertexOS Shell
;
; Commands:
;
;   help
;   about
;   version
;   info
;   clear
;   echo <text>
;
; Architecture:
;
;   Keyboard Driver
;          ↓
;        Shell
;          ↓
;       Console
;          ↓
;      VGA Memory
;
; The Shell does NOT directly manipulate VGA memory.
;
; ============================================================


; ============================================================
; CONSTANTS
; ============================================================

VGA_MEMORY          equ 0xB8000

SCREEN_WIDTH        equ 80
SCREEN_HEIGHT       equ 25

VGA_ROW_SIZE        equ SCREEN_WIDTH * 2

SHELL_START_ROW     equ 3

SHELL_BUFFER_SIZE   equ 128


; ============================================================
; SHELL INITIALIZATION
; ============================================================

shell_init:

    mov byte [shell_initialized], 1

    ret


; ============================================================
; SHELL UPDATE
;
; Called repeatedly by the kernel.
;
; Checks whether the keyboard driver has completed a command.
;
; ============================================================

shell_update:

    ; --------------------------------------------------------
    ; Has ENTER been pressed?
    ; --------------------------------------------------------

    cmp byte [keyboard_command_ready], 1

    jne shell_update_done


    ; --------------------------------------------------------
    ; Clear command-ready flag.
    ; --------------------------------------------------------

    mov byte [keyboard_command_ready], 0


    ; --------------------------------------------------------
    ; Copy command from keyboard driver.
    ;
    ; EDI = destination buffer
    ; EAX = command length
    ; --------------------------------------------------------

    mov edi, shell_buffer

    call keyboard_get_input


    ; --------------------------------------------------------
    ; Save command length.
    ; --------------------------------------------------------

    mov [shell_command_length], eax


    ; --------------------------------------------------------
    ; Execute command.
    ; --------------------------------------------------------

    call shell_execute


shell_update_done:

    ret


; ============================================================
; SHELL EXECUTE
; ============================================================

shell_execute:

    ; --------------------------------------------------------
    ; Empty command.
    ; --------------------------------------------------------

    cmp dword [shell_command_length], 0

    je shell_execute_done


    ; ========================================================
    ; HELP
    ; ========================================================

    mov esi, shell_buffer
    mov edi, cmd_help

    call strings_equal

    cmp eax, 1

    je shell_cmd_help


    ; ========================================================
    ; ABOUT
    ; ========================================================

    mov esi, shell_buffer
    mov edi, cmd_about

    call strings_equal

    cmp eax, 1

    je shell_cmd_about


    ; ========================================================
    ; VERSION
    ; ========================================================

    mov esi, shell_buffer
    mov edi, cmd_version

    call strings_equal

    cmp eax, 1

    je shell_cmd_version


    ; ========================================================
    ; INFO
    ; ========================================================

    mov esi, shell_buffer
    mov edi, cmd_info

    call strings_equal

    cmp eax, 1

    je shell_cmd_info


    ; ========================================================
    ; CLEAR
    ; ========================================================

    mov esi, shell_buffer
    mov edi, cmd_clear

    call strings_equal

    cmp eax, 1

    je shell_cmd_clear


    ; ========================================================
    ; ECHO
    ; ========================================================

    mov esi, shell_buffer
    mov edi, cmd_echo

    call string_starts_with_argument

    cmp eax, 1

    je shell_cmd_echo


    ; ========================================================
    ; UNKNOWN COMMAND
    ; ========================================================

    call console_newline

    mov esi, unknown_msg

    call console_print

    call console_newline

    call shell_print_prompt

    jmp shell_execute_done


; ============================================================
; HELP
; ============================================================

shell_cmd_help:

    call console_newline

    mov esi, help_title
    call console_print

    call console_newline

    mov esi, help_line1
    call console_print

    call console_newline

    mov esi, help_line2
    call console_print

    call console_newline

    mov esi, help_line3
    call console_print

    call console_newline

    mov esi, help_line4
    call console_print

    call console_newline

    mov esi, help_line5
    call console_print

    call console_newline

    mov esi, help_line6
    call console_print

    call console_newline

    call shell_print_prompt

    jmp shell_execute_done


; ============================================================
; ABOUT
; ============================================================

shell_cmd_about:

    call console_newline

    mov esi, about_line1
    call console_print

    call console_newline

    mov esi, about_line2
    call console_print

    call console_newline

    mov esi, about_line3
    call console_print

    call console_newline

    mov esi, about_line4
    call console_print

    call console_newline

    call shell_print_prompt

    jmp shell_execute_done


; ============================================================
; VERSION
; ============================================================

shell_cmd_version:

    call console_newline

    mov esi, version_msg
    call console_print

    call console_newline

    call shell_print_prompt

    jmp shell_execute_done


; ============================================================
; INFO
; ============================================================

shell_cmd_info:

    call console_newline

    mov esi, info_line1
    call console_print

    call console_newline

    mov esi, info_line2
    call console_print

    call console_newline

    mov esi, info_line3
    call console_print

    call console_newline

    mov esi, info_line4
    call console_print

    call console_newline

    mov esi, info_line5
    call console_print

    call console_newline

    call shell_print_prompt

    jmp shell_execute_done


; ============================================================
; CLEAR
; ============================================================

shell_cmd_clear:

    ; --------------------------------------------------------
    ; Clear complete screen through console subsystem.
    ; --------------------------------------------------------

    call console_clear


    ; --------------------------------------------------------
    ; Console cursor is now at top-left.
    ;
    ; Kernel information occupies rows:
    ;
    ;   Row 0 = title
    ;   Row 1 = kernel status
    ;   Row 2 = architecture
    ;
    ; Shell starts at row 3.
    ; --------------------------------------------------------

    mov eax, VGA_MEMORY + (SHELL_START_ROW * VGA_ROW_SIZE)

    call console_set_cursor


    ; --------------------------------------------------------
    ; Create shell prompt.
    ; --------------------------------------------------------

    call shell_print_prompt

    jmp shell_execute_done


; ============================================================
; ECHO
;
; Syntax:
;
;   echo hello
;
; ============================================================

shell_cmd_echo:

    call console_newline


    ; --------------------------------------------------------
    ; Find the space after "echo".
    ; --------------------------------------------------------

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

    ; --------------------------------------------------------
    ; Skip space.
    ; --------------------------------------------------------

    inc esi


    ; --------------------------------------------------------
    ; Print argument.
    ; --------------------------------------------------------

    call console_print

    call console_newline

    call shell_print_prompt

    jmp shell_execute_done


shell_echo_empty:

    call console_newline

    call shell_print_prompt


; ============================================================
; SHELL EXECUTION DONE
; ============================================================

shell_execute_done:

    ret


; ============================================================
; SHELL PRINT PROMPT
;
; IMPORTANT:
;
; Console owns the output cursor.
;
; Keyboard driver owns the input cursor.
;
; This function synchronizes them.
;
; Current console position:
;
;       ↓
;   console cursor
;
;       ↓
;   keyboard cursor
;
;       ↓
;      > _
;
; After drawing "> " the console cursor is advanced too.
;
; ============================================================

shell_print_prompt:

    ; --------------------------------------------------------
    ; Get current console cursor.
    ; --------------------------------------------------------

    call console_get_cursor


    ; --------------------------------------------------------
    ; Give same position to keyboard driver.
    ; --------------------------------------------------------

    call keyboard_set_cursor


    ; --------------------------------------------------------
    ; Keyboard driver draws:
    ;
    ;   > _
    ;
    ; and advances its own cursor by 4 bytes.
    ; --------------------------------------------------------

    call keyboard_print_prompt


    ; --------------------------------------------------------
    ; Synchronize console cursor.
    ;
    ; keyboard_print_prompt does:
    ;
    ;   cursor + 4 bytes
    ;
    ; because:
    ;
    ;   '>' = 2 bytes
    ;   ' ' = 2 bytes
    ;
    ; --------------------------------------------------------

    call console_get_cursor

    add eax, 4

    call console_set_cursor

    ret


; ============================================================
; STRINGS_EQUAL
;
; ESI = string 1
; EDI = string 2
;
; Returns:
;
;   EAX = 1 → equal
;   EAX = 0 → different
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
; STRING_STARTS_WITH_ARGUMENT
;
; ESI = input string
; EDI = command prefix
;
; Prefix must be followed by:
;
;   space
;   or null
;
; ============================================================

string_starts_with_argument:

    push ebx


string_argument_loop:

    mov al, [edi]

    cmp al, 0

    je string_argument_prefix_done


    mov bl, [esi]

    cmp bl, al

    jne string_argument_no


    inc esi

    inc edi

    jmp string_argument_loop


string_argument_prefix_done:

    mov al, [esi]

    cmp al, ' '

    je string_argument_yes


    cmp al, 0

    je string_argument_yes


    jmp string_argument_no


string_argument_yes:

    mov eax, 1

    pop ebx

    ret


string_argument_no:

    xor eax, eax

    pop ebx

    ret


; ============================================================
; DATA
; ============================================================

section .data


; ============================================================
; SHELL STATE
; ============================================================

shell_initialized:

    db 0


shell_command_length:

    dd 0


; ============================================================
; COMMAND BUFFER
; ============================================================

shell_buffer:

    times SHELL_BUFFER_SIZE db 0


; ============================================================
; COMMAND STRINGS
; ============================================================

cmd_help:

    db "help", 0


cmd_about:

    db "about", 0


cmd_version:

    db "version", 0


cmd_info:

    db "info", 0


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

    db "  help    - Show available commands", 0


help_line2:

    db "  about   - Show information about VertexOS", 0


help_line3:

    db "  version - Show VertexOS version", 0


help_line4:

    db "  info    - Show system information", 0


help_line5:

    db "  clear   - Clear the screen", 0


help_line6:

    db "  echo    - Print text", 0


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
; VERSION
; ============================================================

version_msg:

    db "VertexOS version 0.1.0", 0


; ============================================================
; INFO
; ============================================================

info_line1:

    db "System: VertexOS", 0


info_line2:

    db "Architecture: x86 32-bit", 0


info_line3:

    db "CPU Mode: Protected Mode", 0


info_line4:

    db "Kernel: Custom NASM Kernel", 0


info_line5:

    db "Shell: VertexOS Shell", 0


; ============================================================
; UNKNOWN COMMAND
; ============================================================

unknown_msg:

    db "Unknown command. Type 'help'.", 0
