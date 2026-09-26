[bits 32]

section .text

global shell_init
global shell_update

extern keyboard_get_input
extern keyboard_command_ready
extern keyboard_print_prompt
extern keyboard_set_cursor


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
; Features:
;
;   - Command processing
;   - VGA text output
;   - Screen scrolling
;   - Prompt synchronization
;   - Clear command
;   - Echo command
; ============================================================


; ============================================================
; CONSTANTS
; ============================================================

VGA_MEMORY        equ 0xB8000

SCREEN_WIDTH      equ 80
SCREEN_HEIGHT     equ 25

VGA_ROW_SIZE      equ SCREEN_WIDTH * 2

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
; Checks whether ENTER was pressed.
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
    ; EDI = destination
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

    call print_newline

    mov esi, unknown_msg

    call print_string

    call print_newline

    call shell_print_prompt

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

    mov esi, help_line5
    call print_string

    call print_newline

    mov esi, help_line6
    call print_string

    call print_newline

    call shell_print_prompt

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

    call shell_print_prompt

    jmp shell_execute_done


; ============================================================
; VERSION
; ============================================================

shell_cmd_version:

    call print_newline

    mov esi, version_msg
    call print_string

    call print_newline

    call shell_print_prompt

    jmp shell_execute_done


; ============================================================
; INFO
; ============================================================

shell_cmd_info:

    call print_newline

    mov esi, info_line1
    call print_string

    call print_newline

    mov esi, info_line2
    call print_string

    call print_newline

    mov esi, info_line3
    call print_string

    call print_newline

    mov esi, info_line4
    call print_string

    call print_newline

    mov esi, info_line5
    call print_string

    call print_newline

    call shell_print_prompt

    jmp shell_execute_done


; ============================================================
; CLEAR
; ============================================================

shell_cmd_clear:

    ; --------------------------------------------------------
    ; Clear entire VGA screen
    ; --------------------------------------------------------

    call clear_screen


    ; --------------------------------------------------------
    ; Restart shell output position
    ;
    ; Keep the first three rows for kernel information.
    ; --------------------------------------------------------

    mov dword [print_cursor], VGA_MEMORY + (3 * VGA_ROW_SIZE)


    ; --------------------------------------------------------
    ; Synchronize keyboard prompt with shell cursor
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
; Only "echo " is accepted.
;
; "echohello" is NOT accepted.
; ============================================================

shell_cmd_echo:

    call print_newline


    ; --------------------------------------------------------
    ; Find space after "echo"
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
    ; Skip the first space
    ; --------------------------------------------------------

    inc esi


    ; --------------------------------------------------------
    ; Print echo argument
    ; --------------------------------------------------------

    call print_string

    call print_newline

    call shell_print_prompt

    jmp shell_execute_done


shell_echo_empty:

    call print_newline

    call shell_print_prompt


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
; The prefix must be followed by a space or null.
;
; Example:
;
;   echo hello   → match
;   echo test    → match
;   echo         → match
;
;   echohello    → no match
;   echoworld    → no match
;
; Returns:
;
;   EAX = 1 → match
;   EAX = 0 → no match
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
; PRINT STRING
;
; ESI = null-terminated string
;
; Writes characters starting at print_cursor.
; ============================================================

print_string:

    push eax
    push edi


    mov edi, [print_cursor]


print_string_loop:

    lodsb

    test al, al

    jz print_string_done


    ; --------------------------------------------------------
    ; Write character
    ; --------------------------------------------------------

    mov [edi], al

    mov byte [edi + 1], 0x0F

    add edi, 2


    ; --------------------------------------------------------
    ; Keep cursor inside VGA memory.
    ;
    ; Normally shell strings are short enough to fit on one
    ; line, but this prevents the cursor from going past the
    ; VGA buffer.
    ; --------------------------------------------------------

    mov eax, edi

    sub eax, VGA_MEMORY

    cmp eax, SCREEN_WIDTH * SCREEN_HEIGHT * 2

    jb print_string_loop


    ; --------------------------------------------------------
    ; If string reached the end of screen, scroll.
    ; --------------------------------------------------------

    call scroll_screen

    mov edi, VGA_MEMORY + ((SCREEN_HEIGHT - 1) * VGA_ROW_SIZE)


    jmp print_string_loop


print_string_done:

    mov [print_cursor], edi

    pop edi
    pop eax

    ret


; ============================================================
; PRINT NEWLINE
;
; Moves shell cursor to the next row.
;
; If the cursor is already beyond the last row,
; scroll the screen upward by one row.
; ============================================================

print_newline:

    push eax
    push ebx
    push edx
    push edi


    ; --------------------------------------------------------
    ; Convert VGA address to row number
    ; --------------------------------------------------------

    mov edi, [print_cursor]

    sub edi, VGA_MEMORY

    mov eax, edi

    xor edx, edx

    mov ebx, VGA_ROW_SIZE

    div ebx


    ; --------------------------------------------------------
    ; Move to next row
    ; --------------------------------------------------------

    inc eax


    ; --------------------------------------------------------
    ; Check bottom of screen
    ; --------------------------------------------------------

    cmp eax, SCREEN_HEIGHT

    jb print_newline_no_scroll


    ; --------------------------------------------------------
    ; Screen is full.
    ;
    ; Scroll everything up one row.
    ; --------------------------------------------------------

    call scroll_screen


    ; --------------------------------------------------------
    ; Continue on last row.
    ; --------------------------------------------------------

    mov eax, SCREEN_HEIGHT - 1


print_newline_no_scroll:

    imul eax, VGA_ROW_SIZE

    add eax, VGA_MEMORY

    mov [print_cursor], eax


    pop edi
    pop edx
    pop ebx
    pop eax

    ret


; ============================================================
; SHELL PRINT PROMPT
;
; Synchronizes the keyboard driver's cursor with the shell's
; output cursor.
;
; This is required after screen scrolling.
; ============================================================

shell_print_prompt:

    ; --------------------------------------------------------
    ; Get shell output cursor
    ; --------------------------------------------------------

    mov eax, [print_cursor]


    ; --------------------------------------------------------
    ; Synchronize keyboard driver
    ;
    ; keyboard_set_cursor also updates input_start.
    ; --------------------------------------------------------

    call keyboard_set_cursor


    ; --------------------------------------------------------
    ; Draw:
    ;
    ; > _
    ; --------------------------------------------------------

    call keyboard_print_prompt

    ret


; ============================================================
; SCROLL SCREEN
;
; Moves rows 1-24 to rows 0-23.
;
; Row 24 is cleared.
;
; Result:
;
;   Row 0  <- Row 1
;   Row 1  <- Row 2
;   ...
;   Row 23 <- Row 24
;   Row 24 <- blank
; ============================================================

scroll_screen:

    push eax
    push ecx
    push esi
    push edi
    pushfd


    ; --------------------------------------------------------
    ; Make sure string instructions move forward.
    ; --------------------------------------------------------

    cld


    ; --------------------------------------------------------
    ; Source:
    ;
    ; Row 1
    ;
    ; Destination:
    ;
    ; Row 0
    ; --------------------------------------------------------

    mov esi, VGA_MEMORY + VGA_ROW_SIZE

    mov edi, VGA_MEMORY


    ; --------------------------------------------------------
    ; Copy rows 1-24 into rows 0-23.
    ;
    ; 24 rows × 80 characters
    ; Each character cell = 2 bytes
    ;
    ; rep movsw copies one 16-bit character cell.
    ; --------------------------------------------------------

    mov ecx, (SCREEN_HEIGHT - 1) * SCREEN_WIDTH

    rep movsw


    ; --------------------------------------------------------
    ; Clear bottom row.
    ; --------------------------------------------------------

    mov edi, VGA_MEMORY + ((SCREEN_HEIGHT - 1) * VGA_ROW_SIZE)

    mov ecx, SCREEN_WIDTH

    mov ax, 0x0720


scroll_clear_bottom:

    mov [edi], ax

    add edi, 2

    loop scroll_clear_bottom


    popfd
    pop edi
    pop esi
    pop ecx
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


    ; --------------------------------------------------------
    ; Reset shell output cursor.
    ; --------------------------------------------------------

    mov dword [print_cursor], VGA_MEMORY


    pop edi
    pop ecx
    pop eax

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
