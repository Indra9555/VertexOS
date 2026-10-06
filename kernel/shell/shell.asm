[bits 32]

section .text

global shell_init
global shell_update


; ============================================================
; EXTERNAL COMPONENTS
; ============================================================

extern keyboard_get_input
extern keyboard_command_ready
extern keyboard_set_cursor

extern console_clear
extern console_putc
extern console_print
extern console_newline
extern console_get_cursor
extern console_set_cursor

extern time_get_ticks
extern time_get_seconds


; ============================================================
; VertexOS Shell
;
; Responsibilities:
;
;   - Command processing
;   - Command parsing
;   - Shell state
;   - Interaction with keyboard driver
;   - Interaction with console subsystem
;
; The shell does NOT directly manipulate VGA memory.
;
; Output path:
;
;   Shell -> Console -> VGA
;
; Time path:
;
;   Shell -> Time Subsystem -> Timer
;
; ============================================================


; ============================================================
; CONSTANTS
; ============================================================

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
; Called repeatedly by the kernel.
;
; Checks whether the keyboard driver has completed a command.
; ============================================================

shell_update:

    ; --------------------------------------------------------
    ; Check command-ready flag
    ; --------------------------------------------------------

    cmp byte [keyboard_command_ready], 1

    jne shell_update_done


    ; --------------------------------------------------------
    ; Clear command-ready flag
    ; --------------------------------------------------------

    mov byte [keyboard_command_ready], 0


    ; --------------------------------------------------------
    ; Get command from keyboard driver
    ;
    ; EDI = destination buffer
    ; EAX = command length
    ; --------------------------------------------------------

    mov edi, shell_buffer

    call keyboard_get_input


    ; --------------------------------------------------------
    ; Save command length
    ; --------------------------------------------------------

    mov [shell_command_length], eax


    ; --------------------------------------------------------
    ; Execute command
    ; --------------------------------------------------------

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
    ; TICKS
    ; ========================================================

    mov esi, shell_buffer
    mov edi, cmd_ticks

    call strings_equal

    cmp eax, 1

    je shell_cmd_ticks


    ; ========================================================
    ; UPTIME
    ; ========================================================

    mov esi, shell_buffer
    mov edi, cmd_uptime

    call strings_equal

    cmp eax, 1

    je shell_cmd_uptime


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

    mov esi, help_line7
    call console_print

    call console_newline

    mov esi, help_line8
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
    ; Clear the entire console
    ; --------------------------------------------------------

    call console_clear


    ; --------------------------------------------------------
    ; Reserve the first three rows for kernel information.
    ;
    ; Start shell output at row 3.
    ; --------------------------------------------------------

    call console_get_cursor

    add eax, 3 * 160

    call console_set_cursor


    ; --------------------------------------------------------
    ; Synchronize keyboard and print new prompt.
    ; --------------------------------------------------------

    call shell_print_prompt

    jmp shell_execute_done


; ============================================================
; TICKS
;
; Displays the number of timer interrupts received.
;
; The shell accesses the timer through the Time subsystem.
;
; ============================================================

shell_cmd_ticks:

    call console_newline

    mov esi, ticks_label
    call console_print

    call time_get_ticks

    call shell_print_decimal

    call console_newline

    call shell_print_prompt

    jmp shell_execute_done


; ============================================================
; UPTIME
;
; Displays the number of seconds since the kernel started.
;
; The Time subsystem converts timer ticks into seconds.
;
; ============================================================

shell_cmd_uptime:

    call console_newline

    mov esi, uptime_label
    call console_print

    call time_get_seconds

    call shell_print_decimal

    mov esi, seconds_label
    call console_print

    call console_newline

    call shell_print_prompt

    jmp shell_execute_done


; ============================================================
; PRINT DECIMAL
;
; EAX = unsigned 32-bit integer
;
; Prints the value in decimal.
;
; Example:
;
;     EAX = 1234
;
; Output:
;
;     1234
; ============================================================

shell_print_decimal:

    ; --------------------------------------------------------
    ; Special case: zero
    ; --------------------------------------------------------

    cmp eax, 0

    jne shell_decimal_nonzero

    mov al, '0'
    call console_putc

    ret


shell_decimal_nonzero:

    ; --------------------------------------------------------
    ; Preserve registers.
    ; --------------------------------------------------------

    push eax
    push ebx
    push ecx
    push edx


    ; --------------------------------------------------------
    ; Use stack as a temporary digit buffer.
    ;
    ; Each decimal digit is pushed separately.
    ; --------------------------------------------------------

    xor ecx, ecx

    mov ebx, 10


shell_decimal_convert:

    xor edx, edx

    div ebx

    add dl, '0'

    push edx

    inc ecx

    cmp eax, 0

    jne shell_decimal_convert


    ; --------------------------------------------------------
    ; Print digits in correct order.
    ; --------------------------------------------------------

shell_decimal_print:

    pop eax

    call console_putc

    loop shell_decimal_print


    ; --------------------------------------------------------
    ; Restore registers.
    ; --------------------------------------------------------

    pop edx
    pop ecx
    pop ebx
    pop eax

    ret


; ============================================================
; ECHO
;
; Syntax:
;
;   echo hello
;   echo VertexOS
;
; "echohello" is not accepted.
; ============================================================

shell_cmd_echo:

    call console_newline


    ; --------------------------------------------------------
    ; Find the space after "echo"
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
    ; Skip the space
    ; --------------------------------------------------------

    inc esi


    ; --------------------------------------------------------
    ; Print echo argument through console subsystem
    ; --------------------------------------------------------

    call console_print

    call console_newline

    call shell_print_prompt

    jmp shell_execute_done


shell_echo_empty:

    call console_newline

    call shell_print_prompt

    jmp shell_execute_done


; ============================================================
; SHELL EXECUTION DONE
; ============================================================

shell_execute_done:

    ret


; ============================================================
; STRINGS_EQUAL
;
; ESI = string 1
; EDI = string 2
;
; Returns:
;
;   EAX = 1 -> equal
;   EAX = 0 -> different
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
;   or null terminator
;
; Examples:
;
;   echo hello -> match
;   echo test  -> match
;   echo       -> match
;
;   echohello  -> no match
;   echoworld  -> no match
;
; Returns:
;
;   EAX = 1 -> match
;   EAX = 0 -> no match
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

    ; --------------------------------------------------------
    ; Prefix matched.
    ;
    ; Next character must be:
    ;
    ;   space
    ;   or null
    ; --------------------------------------------------------

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
; SHELL PRINT PROMPT
;
; Synchronizes the keyboard driver's cursor with the Console.
;
; Prompt is drawn through the Console subsystem.
;
; Sequence:
;
;   1. Get console cursor
;   2. Give cursor to keyboard driver
;   3. Print "> "
;   4. Get new console cursor
;   5. Give new cursor to keyboard driver
;
; This keeps keyboard input and console output synchronized.
; ============================================================

shell_print_prompt:

    ; --------------------------------------------------------
    ; Get current console cursor.
    ; --------------------------------------------------------

    call console_get_cursor


    ; --------------------------------------------------------
    ; Tell keyboard driver where input begins.
    ; --------------------------------------------------------

    call keyboard_set_cursor


    ; --------------------------------------------------------
    ; Print shell prompt through Console.
    ; --------------------------------------------------------

    mov esi, prompt_text

    call console_print


    ; --------------------------------------------------------
    ; Get console cursor after prompt.
    ; --------------------------------------------------------

    call console_get_cursor


    ; --------------------------------------------------------
    ; Synchronize keyboard driver again.
    ;
    ; Keyboard input will now begin immediately after "> ".
    ; --------------------------------------------------------

    call keyboard_set_cursor

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


cmd_ticks:

    db "ticks", 0


cmd_uptime:

    db "uptime", 0


cmd_echo:

    db "echo", 0


; ============================================================
; PROMPT
; ============================================================

prompt_text:

    db "> ", 0


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


help_line7:

    db "  ticks   - Show timer interrupt count", 0


help_line8:

    db "  uptime  - Show system uptime", 0


; ============================================================
; TIME TEXT
; ============================================================

ticks_label:

    db "Timer ticks: ", 0


uptime_label:

    db "Uptime: ", 0


seconds_label:

    db " seconds", 0


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
