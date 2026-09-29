[bits 32]
[section .text]

global kernel_start


; ============================================================
; EXTERNAL COMPONENTS
; ============================================================

; Console subsystem
extern console_init
extern console_print
extern console_newline
extern console_get_cursor
extern console_set_cursor


; Interrupt subsystem
extern idt_init
extern pic_init


; Keyboard subsystem
extern keyboard_print_prompt
extern keyboard_set_cursor


; Shell subsystem
extern shell_init
extern shell_update


; ============================================================
; VertexOS Kernel Entry Point
;
; Kernel responsibilities:
;
;   - Initialize core subsystems
;   - Display kernel startup information
;   - Initialize interrupts
;   - Initialize shell
;   - Start the main kernel loop
;
; VGA output is handled through the Console subsystem.
;
; Output architecture:
;
;   Kernel
;      ↓
;   Console
;      ↓
;     VGA
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
    ;
    ; IRQ1 = keyboard
    ;
    ; PIC master data port = 0x21
    ;
    ; Bit 1:
    ;   0 = IRQ1 enabled
    ;   1 = IRQ1 masked
    ;
    ; Therefore:
    ;
    ;   AND 0xFD
    ;
    ; clears bit 1.
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
    ; At this point the Console cursor is at:
    ;
    ;   Row 3, Column 0
    ;
    ; because the kernel printed three lines.
    ;
    ; The keyboard driver still owns the temporary visible
    ; input cursor, so we synchronize it with the Console.
    ; ========================================================

    call shell_print_initial_prompt


    ; ========================================================
    ; ENABLE CPU INTERRUPTS
    ; ========================================================

    sti


    ; ========================================================
    ; MAIN KERNEL LOOP
    ;
    ; The CPU waits for interrupts when there is no shell
    ; work to process.
    ; ========================================================

kernel_loop:

    call shell_update

    hlt

    jmp kernel_loop


; ============================================================
; INITIAL SHELL PROMPT
;
; Synchronization sequence:
;
;   Console cursor
;        ↓
;   Keyboard cursor
;        ↓
;   keyboard_print_prompt
;        ↓
;   Console cursor updated
;
; keyboard_print_prompt currently writes:
;
;   > _
;
; directly to VGA.
;
; This is temporary and will be moved into the Console-based
; architecture during the Keyboard → Console integration.
; ============================================================

shell_print_initial_prompt:

    ; --------------------------------------------------------
    ; Get current Console cursor.
    ;
    ; Expected:
    ;
    ;   VGA_MEMORY + (3 * 160)
    ;
    ; --------------------------------------------------------

    call console_get_cursor


    ; --------------------------------------------------------
    ; Synchronize keyboard input position.
    ;
    ; keyboard_set_cursor also updates input_start.
    ; --------------------------------------------------------

    call keyboard_set_cursor


    ; --------------------------------------------------------
    ; Print:
    ;
    ;   > _
    ;
    ; keyboard_print_prompt currently handles the visible
    ; keyboard cursor.
    ; --------------------------------------------------------

    call keyboard_print_prompt


    ; --------------------------------------------------------
    ; keyboard_print_prompt advances its internal cursor by:
    ;
    ;   '>' = 2 bytes
    ;   ' ' = 2 bytes
    ;
    ; Therefore the Console cursor must advance by 4 bytes.
    ; --------------------------------------------------------

    call console_get_cursor

    add eax, 4

    call console_set_cursor


    ret


; ============================================================
; KERNEL STARTUP MESSAGES
; ============================================================

title_msg:

    db "VertexOS - Protected Mode Kernel", 0


status_msg:

    db "Kernel loaded successfully.", 0


arch_msg:

    db "Architecture: x86 32-bit Protected Mode", 0
