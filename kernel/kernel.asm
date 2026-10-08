[bits 32]
[section .text]

global kernel_start

; ============================================================
; Console
; ============================================================

extern console_init
extern console_print
extern console_newline
extern console_get_cursor


; ============================================================
; Serial
; ============================================================

extern serial_init
extern serial_print
extern serial_write_hex


; ============================================================
; Interrupt subsystem
; ============================================================

extern idt_init
extern pic_init


; ============================================================
; Timer
; ============================================================

extern timer_init
extern time_init


; ============================================================
; Keyboard
; ============================================================

extern keyboard_print_prompt
extern keyboard_set_cursor


; ============================================================
; Shell
; ============================================================

extern shell_init
extern shell_update


; ============================================================
; Kernel entry
; ============================================================

kernel_start:

    ; --------------------------------------------------------
    ; Initialize console
    ; --------------------------------------------------------

    call console_init


    ; --------------------------------------------------------
    ; Initialize COM1 serial port
    ; --------------------------------------------------------

    call serial_init


    ; --------------------------------------------------------
    ; Serial debugging test
    ; --------------------------------------------------------

    mov esi, serial_test_msg
    call serial_print

    mov eax, 0x1234ABCD
    call serial_write_hex

    mov esi, serial_newline
    call serial_print


    ; --------------------------------------------------------
    ; Display kernel information on VGA
    ; --------------------------------------------------------

    mov esi, title_msg
    call console_print
    call console_newline

    mov esi, status_msg
    call console_print
    call console_newline

    mov esi, arch_msg
    call console_print
    call console_newline


    ; --------------------------------------------------------
    ; Initialize interrupt subsystem
    ; --------------------------------------------------------

    call idt_init
    call pic_init


    ; --------------------------------------------------------
    ; Initialize timer and timekeeping
    ; --------------------------------------------------------

    call timer_init
    call time_init


    ; --------------------------------------------------------
    ; Unmask:
    ;
    ; IRQ0 = timer
    ; IRQ1 = keyboard
    ; --------------------------------------------------------

    in al, 0x21
    and al, 0xFC
    out 0x21, al


    ; --------------------------------------------------------
    ; Initialize shell
    ; --------------------------------------------------------

    call shell_init
    call shell_print_initial_prompt


    ; --------------------------------------------------------
    ; Enable interrupts
    ; --------------------------------------------------------

    sti


; ============================================================
; Kernel main loop
; ============================================================

kernel_loop:

    call shell_update

    hlt

    jmp kernel_loop


; ============================================================
; Print initial shell prompt
; ============================================================

shell_print_initial_prompt:

    call console_get_cursor

    call keyboard_set_cursor

    call keyboard_print_prompt

    ret


; ============================================================
; Kernel messages
; ============================================================

section .data

title_msg:
    db "VertexOS - Protected Mode Kernel", 0

status_msg:
    db "Kernel loaded successfully.", 0

arch_msg:
    db "Architecture: x86 32-bit Protected Mode", 0


; ============================================================
; Serial test messages
; ============================================================

serial_test_msg:
    db "[SERIAL] COM1 initialized. Test value: 0x", 0

serial_newline:
    db 13, 10, 0
