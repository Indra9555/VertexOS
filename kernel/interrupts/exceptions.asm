[bits 32]

section .text

global exception_common_handler

global exception_0
global exception_1
global exception_2
global exception_3
global exception_4
global exception_5
global exception_6
global exception_7
global exception_8
global exception_9
global exception_10
global exception_11
global exception_12
global exception_13
global exception_14
global exception_15
global exception_16
global exception_17
global exception_18
global exception_19
global exception_20
global exception_21
global exception_22
global exception_23
global exception_24
global exception_25
global exception_26
global exception_27
global exception_28
global exception_29
global exception_30
global exception_31

extern console_clear
extern console_print
extern console_newline
extern console_putc


; ============================================================
; CPU EXCEPTION STUBS
;
; Common stack layout:
;
;   [esp + 0]  = exception vector
;   [esp + 4]  = error code
;   [esp + 8]  = EIP
;   [esp + 12] = CS
;   [esp + 16] = EFLAGS
; ============================================================

exception_0:
    push dword 0
    push dword 0
    jmp exception_common_handler

exception_1:
    push dword 0
    push dword 1
    jmp exception_common_handler

exception_2:
    push dword 0
    push dword 2
    jmp exception_common_handler

exception_3:
    push dword 0
    push dword 3
    jmp exception_common_handler

exception_4:
    push dword 0
    push dword 4
    jmp exception_common_handler

exception_5:
    push dword 0
    push dword 5
    jmp exception_common_handler

exception_6:
    push dword 0
    push dword 6
    jmp exception_common_handler

exception_7:
    push dword 0
    push dword 7
    jmp exception_common_handler

exception_8:
    push dword 8
    jmp exception_common_handler

exception_9:
    push dword 0
    push dword 9
    jmp exception_common_handler

exception_10:
    push dword 10
    jmp exception_common_handler

exception_11:
    push dword 11
    jmp exception_common_handler

exception_12:
    push dword 12
    jmp exception_common_handler

exception_13:
    push dword 13
    jmp exception_common_handler

exception_14:
    push dword 14
    jmp exception_common_handler

exception_15:
    push dword 0
    push dword 15
    jmp exception_common_handler

exception_16:
    push dword 0
    push dword 16
    jmp exception_common_handler

exception_17:
    push dword 17
    jmp exception_common_handler

exception_18:
    push dword 0
    push dword 18
    jmp exception_common_handler

exception_19:
    push dword 0
    push dword 19
    jmp exception_common_handler

exception_20:
    push dword 0
    push dword 20
    jmp exception_common_handler

exception_21:
    push dword 0
    push dword 21
    jmp exception_common_handler

exception_22:
    push dword 0
    push dword 22
    jmp exception_common_handler

exception_23:
    push dword 0
    push dword 23
    jmp exception_common_handler

exception_24:
    push dword 0
    push dword 24
    jmp exception_common_handler

exception_25:
    push dword 0
    push dword 25
    jmp exception_common_handler

exception_26:
    push dword 0
    push dword 26
    jmp exception_common_handler

exception_27:
    push dword 0
    push dword 27
    jmp exception_common_handler

exception_28:
    push dword 0
    push dword 28
    jmp exception_common_handler

exception_29:
    push dword 0
    push dword 29
    jmp exception_common_handler

exception_30:
    push dword 0
    push dword 30
    jmp exception_common_handler

exception_31:
    push dword 0
    push dword 31
    jmp exception_common_handler


; ============================================================
; COMMON EXCEPTION HANDLER
; ============================================================

exception_common_handler:

    cli

    pushad


    ; ========================================================
    ; Exception header
    ; ========================================================

    call console_clear

    mov esi, exception_header
    call console_print

    call console_newline

    mov esi, exception_label
    call console_print


    ; ========================================================
    ; Find exception name
    ; ========================================================

    mov eax, [esp + 32]

    cmp eax, 0
    je .exception_0

    cmp eax, 1
    je .exception_1

    cmp eax, 2
    je .exception_2

    cmp eax, 3
    je .exception_3

    cmp eax, 4
    je .exception_4

    cmp eax, 5
    je .exception_5

    cmp eax, 6
    je .exception_6

    cmp eax, 7
    je .exception_7

    cmp eax, 8
    je .exception_8

    cmp eax, 9
    je .exception_9

    cmp eax, 10
    je .exception_10

    cmp eax, 11
    je .exception_11

    cmp eax, 12
    je .exception_12

    cmp eax, 13
    je .exception_13

    cmp eax, 14
    je .exception_14

    cmp eax, 15
    je .exception_15

    cmp eax, 16
    je .exception_16

    cmp eax, 17
    je .exception_17

    cmp eax, 18
    je .exception_18

    cmp eax, 19
    je .exception_19

    cmp eax, 20
    je .exception_20

    cmp eax, 21
    je .exception_21

    cmp eax, 22
    je .exception_22

    cmp eax, 23
    je .exception_23

    cmp eax, 24
    je .exception_24

    cmp eax, 25
    je .exception_25

    cmp eax, 26
    je .exception_26

    cmp eax, 27
    je .exception_27

    cmp eax, 28
    je .exception_28

    cmp eax, 29
    je .exception_29

    cmp eax, 30
    je .exception_30

    cmp eax, 31
    je .exception_31

    jmp .exception_unknown


.exception_0:
    mov esi, exception_name_0
    jmp .print_name

.exception_1:
    mov esi, exception_name_1
    jmp .print_name

.exception_2:
    mov esi, exception_name_2
    jmp .print_name

.exception_3:
    mov esi, exception_name_3
    jmp .print_name

.exception_4:
    mov esi, exception_name_4
    jmp .print_name

.exception_5:
    mov esi, exception_name_5
    jmp .print_name

.exception_6:
    mov esi, exception_name_6
    jmp .print_name

.exception_7:
    mov esi, exception_name_7
    jmp .print_name

.exception_8:
    mov esi, exception_name_8
    jmp .print_name

.exception_9:
    mov esi, exception_name_9
    jmp .print_name

.exception_10:
    mov esi, exception_name_10
    jmp .print_name

.exception_11:
    mov esi, exception_name_11
    jmp .print_name

.exception_12:
    mov esi, exception_name_12
    jmp .print_name

.exception_13:
    mov esi, exception_name_13
    jmp .print_name

.exception_14:
    mov esi, exception_name_14
    jmp .print_name

.exception_15:
    mov esi, exception_name_15
    jmp .print_name

.exception_16:
    mov esi, exception_name_16
    jmp .print_name

.exception_17:
    mov esi, exception_name_17
    jmp .print_name

.exception_18:
    mov esi, exception_name_18
    jmp .print_name

.exception_19:
    mov esi, exception_name_19
    jmp .print_name

.exception_20:
    mov esi, exception_name_20
    jmp .print_name

.exception_21:
    mov esi, exception_name_21
    jmp .print_name

.exception_22:
    mov esi, exception_name_22
    jmp .print_name

.exception_23:
    mov esi, exception_name_23
    jmp .print_name

.exception_24:
    mov esi, exception_name_24
    jmp .print_name

.exception_25:
    mov esi, exception_name_25
    jmp .print_name

.exception_26:
    mov esi, exception_name_26
    jmp .print_name

.exception_27:
    mov esi, exception_name_27
    jmp .print_name

.exception_28:
    mov esi, exception_name_28
    jmp .print_name

.exception_29:
    mov esi, exception_name_29
    jmp .print_name

.exception_30:
    mov esi, exception_name_30
    jmp .print_name

.exception_31:
    mov esi, exception_name_31
    jmp .print_name


.exception_unknown:
    mov esi, exception_name_unknown


.print_name:

    call console_print

    call console_newline


    ; ========================================================
    ; Vector
    ; ========================================================

    mov esi, vector_label
    call console_print

    mov eax, [esp + 32]
    call print_hex32

    call console_newline


    ; ========================================================
    ; Error Code
    ; ========================================================

    mov esi, error_label
    call console_print

    mov eax, [esp + 36]
    call print_hex32

    call console_newline


    ; ========================================================
    ; EIP
    ;
    ; [esp + 40] = CPU-saved EIP
    ; ========================================================

    mov esi, eip_label
    call console_print

    mov eax, [esp + 40]
    call print_hex32

    call console_newline


    ; ========================================================
    ; CS
    ;
    ; [esp + 44] = CPU-saved CS
    ; ========================================================

    mov esi, cs_label
    call console_print

    mov eax, [esp + 44]
    call print_hex32

    call console_newline


    ; ========================================================
    ; EFLAGS
    ;
    ; [esp + 48] = CPU-saved EFLAGS
    ; ========================================================

    mov esi, eflags_label
    call console_print

    mov eax, [esp + 48]
    call print_hex32

    call console_newline


    ; ========================================================
    ; Halt message
    ; ========================================================

    mov esi, halted_message
    call console_print


.exception_halt:

    hlt
    jmp .exception_halt


; ============================================================
; print_hex32
;
; Input:
;   EAX = 32-bit value
;
; Output:
;   0xXXXXXXXX
; ============================================================

print_hex32:

    push eax
    push ebx
    push ecx
    push edx

    mov esi, hex_prefix
    call console_print

    mov ebx, eax
    mov ecx, 8


.hex_loop:

    rol ebx, 4

    mov eax, ebx
    and eax, 0x0F

    cmp al, 9
    jbe .hex_digit

    add al, 'A' - 10
    jmp .print_digit

.hex_digit:

    add al, '0'


.print_digit:

    call console_putc

    loop .hex_loop

    pop edx
    pop ecx
    pop ebx
    pop eax

    ret


; ============================================================
; DATA
; ============================================================

section .data

exception_header:
    db "================================", 0

exception_label:
    db "CPU Exception: ", 0

vector_label:
    db "Vector: ", 0

error_label:
    db "Error Code: ", 0

eip_label:
    db "EIP: ", 0

cs_label:
    db "CS: ", 0

eflags_label:
    db "EFLAGS: ", 0

halted_message:
    db "System halted.", 0

hex_prefix:
    db "0x", 0


exception_name_0:
    db "Divide Error", 0

exception_name_1:
    db "Debug", 0

exception_name_2:
    db "Non-Maskable Interrupt", 0

exception_name_3:
    db "Breakpoint", 0

exception_name_4:
    db "Overflow", 0

exception_name_5:
    db "Bound Range Exceeded", 0

exception_name_6:
    db "Invalid Opcode", 0

exception_name_7:
    db "Device Not Available", 0

exception_name_8:
    db "Double Fault", 0

exception_name_9:
    db "Coprocessor Segment Overrun", 0

exception_name_10:
    db "Invalid TSS", 0

exception_name_11:
    db "Segment Not Present", 0

exception_name_12:
    db "Stack-Segment Fault", 0

exception_name_13:
    db "General Protection Fault", 0

exception_name_14:
    db "Page Fault", 0

exception_name_15:
    db "Reserved", 0

exception_name_16:
    db "x87 Floating-Point Exception", 0

exception_name_17:
    db "Alignment Check", 0

exception_name_18:
    db "Machine Check", 0

exception_name_19:
    db "SIMD Floating-Point Exception", 0

exception_name_20:
    db "Virtualization Exception", 0

exception_name_21:
    db "Control Protection Exception", 0

exception_name_22:
    db "Reserved", 0

exception_name_23:
    db "Reserved", 0

exception_name_24:
    db "Reserved", 0

exception_name_25:
    db "Reserved", 0

exception_name_26:
    db "Reserved", 0

exception_name_27:
    db "Reserved", 0

exception_name_28:
    db "Hypervisor Injection Exception", 0

exception_name_29:
    db "VMM Communication Exception", 0

exception_name_30:
    db "Security Exception", 0

exception_name_31:
    db "Reserved", 0

exception_name_unknown:
    db "Unknown Exception", 0
