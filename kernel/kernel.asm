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


; Interrupt subsystem
extern idt_init
extern pic_init


; Timer subsystem
extern timer_init


; Keyboard subsystem
extern keyboard_print_prompt
extern keyboard_set_cursor


; Shell subsystem
extern shell_init
extern shell_update
extern time_init

; ============================================================
; VertexOS Kernel Entry Point
;
; Kernel responsibilities:
;
;   - Initialize core subsystems
;   - Display kernel startup information
;   - Initialize IDT
;   - Initialize PIC
;   - Initialize PIT timer
;   - Initialize shell
;   - Start the main kernel loop
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
    ; INITIALIZE PIT TIMER
    ;
    ; Configures PIT channel 0 for approximately 100 Hz.
    ;
    ; PIT IRQ0 → PIC IRQ0 → IDT vector 0x20
    ; ========================================================

    call timer_init
    call time_init

    ; ========================================================
    ; ENABLE TIMER IRQ0 AND KEYBOARD IRQ1
    ;
    ; IRQ0 = PIT timer
    ; IRQ1 = keyboard
    ;
    ; PIC master data port = 0x21
    ;
    ; Bit 0:
    ;   0 = IRQ0 enabled
    ;   1 = IRQ0 masked
    ;
    ; Bit 1:
    ;   0 = IRQ1 enabled
    ;   1 = IRQ1 masked
    ;
    ; 0xFC = 11111100b
    ;
    ; Therefore:
    ;
    ;   IRQ0 → enabled
    ;   IRQ1 → enabled
    ;   IRQ2-7 → masked
    ;
    ; ========================================================

    in al, 0x21

    and al, 0xFC

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
    ; keyboard_print_prompt uses the Console subsystem to
    ; print "> " and therefore advances the Console cursor
    ; automatically.
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
;   Console cursor automatically advances
;
; keyboard_print_prompt is now Console-based.
; It does NOT directly manipulate VGA memory.
; ============================================================

shell_print_initial_prompt:

    ; --------------------------------------------------------
    ; Get current Console cursor.
    ; --------------------------------------------------------

    call console_get_cursor


    ; --------------------------------------------------------
    ; Synchronize keyboard input position with Console.
    ; --------------------------------------------------------

    call keyboard_set_cursor


    ; --------------------------------------------------------
    ; Print the prompt.
    ;
    ; keyboard_print_prompt internally uses console_putc(),
    ; so the Console cursor advances automatically.
    ; --------------------------------------------------------

    call keyboard_print_prompt

    ret


; ============================================================
; KERNEL STARTUP MESSAGES
; ============================================================

section .data

title_msg:

    db "VertexOS - Protected Mode Kernel", 0


status_msg:

    db "Kernel loaded successfully.", 0


arch_msg:

    db "Architecture: x86 32-bit Protected Mode", 0
