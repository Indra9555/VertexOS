[bits 32]
[section .text]

global kernel_start


extern console_init
extern console_print
extern console_newline

extern idt_init
extern pic_init

extern keyboard_print_prompt

extern shell_init
extern shell_update


; ============================================================
; VertexOS Kernel Entry Point
;
; Kernel output is handled by the Console subsystem.
;
; ============================================================

kernel_start:

    ; ========================================================
    ; INITIALIZE CONSOLE
    ; ========================================================

    call console_init


    ; ========================================================
    ; PRINT KERNEL TITLE
    ; ========================================================

    mov esi, title_msg

    call console_print

    call console_newline


    ; ========================================================
    ; PRINT KERNEL STATUS
    ; ========================================================

    mov esi, status_msg

    call console_print

    call console_newline


    ; ========================================================
    ; PRINT ARCHITECTURE INFORMATION
    ; ========================================================

    mov esi, arch_msg

    call console_print

    call console_newline


    ; ========================================================
    ; INITIALIZE IDT
    ; ========================================================

    call idt_init


    ; ========================================================
    ; INITIALIZE PIC
    ; ========================================================

    call pic_init


    ; ========================================================
    ; ENABLE KEYBOARD IRQ1
    ; ========================================================

    in al, 0x21

    and al, 0xFD

    out 0x21, al


    ; ========================================================
    ; INITIALIZE SHELL
    ; ========================================================

    call shell_init


    ; ========================================================
    ; PRINT INITIAL SHELL PROMPT
    ;
    ; At this point the console cursor is already at:
    ;
    ;   row 3, column 0
    ;
    ; because the kernel printed three lines.
    ;
    ; keyboard_print_prompt will be synchronized by the shell.
    ;
    ; ========================================================

    call shell_print_initial_prompt


    ; ========================================================
    ; ENABLE CPU INTERRUPTS
    ; ========================================================

    sti


    ; ========================================================
    ; MAIN KERNEL LOOP
    ; ========================================================

kernel_loop:

    call shell_update

    hlt

    jmp kernel_loop


; ============================================================
; INITIAL SHELL PROMPT
;
; The shell normally synchronizes the console and keyboard
; cursors through shell_print_prompt.
;
; For the first prompt, the console cursor is already at the
; correct position after the three kernel messages.
;
; ============================================================

shell_print_initial_prompt:

    ; --------------------------------------------------------
    ; The console cursor currently points at:
    ;
    ;   Row 3, Column 0
    ;
    ; Synchronize keyboard cursor with it.
    ; --------------------------------------------------------

    extern console_get_cursor
    extern keyboard_set_cursor

    call console_get_cursor

    call keyboard_set_cursor


    ; --------------------------------------------------------
    ; Draw:
    ;
    ;   > _
    ; --------------------------------------------------------

    call keyboard_print_prompt


    ; --------------------------------------------------------
    ; keyboard_print_prompt advances its cursor by:
    ;
    ;   '>' = 2 bytes
    ;   ' ' = 2 bytes
    ;
    ; Keep console cursor synchronized.
    ; --------------------------------------------------------

    call console_get_cursor

    add eax, 4

    extern console_set_cursor

    call console_set_cursor

    ret


; ============================================================
; KERNEL MESSAGES
; ============================================================

title_msg:

    db "VertexOS - Protected Mode Kernel", 0


status_msg:

    db "Kernel loaded successfully.", 0


arch_msg:

    db "Architecture: x86 32-bit Protected Mode", 0
