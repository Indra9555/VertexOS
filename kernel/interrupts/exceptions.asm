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


; ------------------------------------------------------------
; CPU exception stubs
;
; Exceptions without an automatic CPU error code push a
; dummy error code so that every exception has the same
; stack layout.
;
; Stack entering exception_common_handler:
;
;   [esp + 0]  = exception vector
;   [esp + 4]  = error code
;   [esp + 8]  = EIP
;   [esp + 12] = CS
;   [esp + 16] = EFLAGS
; ------------------------------------------------------------

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


; Double Fault already pushes an error code.
exception_8:
    push dword 8
    jmp exception_common_handler


exception_9:
    push dword 0
    push dword 9
    jmp exception_common_handler


; Exceptions 10-14 automatically push an error code.
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

; Vector 17 (Alignment Check) pushes an error code.
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


; ------------------------------------------------------------
; Common exception handler
; ------------------------------------------------------------

exception_common_handler:
    cli

    ; Preserve all general-purpose registers.
    pushad

    ; Exception handling will be expanded in the next step.
    ; For now, stop the CPU safely.
.exception_halt:
    hlt
    jmp .exception_halt
