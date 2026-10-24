from pathlib import Path

root = Path("/tmp/vertexos-timeout-test")
branches = (root / "production_timeout_branches.asm").read_text()

template = r'''
BITS 32
global _start

KEYBOARD_LED_TIMEOUT_TICKS equ 100

section .text
_start:
    ; Normal timeout boundary: 99 ticks must not time out.
    TEST_CASE wait_99, keyboard_led_check_timeout, 1099, 1000, 1, 0, 1, 0, 1000

    ; At 100 ticks, queue a retry and enter cooldown.
    TEST_CASE wait_100, keyboard_led_check_timeout, 1100, 1000, 1, 0, 5, 1, 1100

    ; Cooldown must still be active at 99 ticks.
    TEST_CASE cooldown_99, keyboard_led_cooldown, 2099, 2000, 5, 1, 5, 1, 2000

    ; At 100 cooldown ticks, return to idle.
    TEST_CASE cooldown_100, keyboard_led_cooldown, 2100, 2000, 5, 1, 0, 1, 2000

    ; Unsigned tick subtraction across 32-bit wraparound: 99 ticks.
    TEST_CASE wrap_wait_99, keyboard_led_check_timeout, 0x53, 0xFFFFFFF0, 1, 0, 1, 0, 0xFFFFFFF0

    ; Unsigned tick subtraction across wraparound: 100 ticks.
    TEST_CASE wrap_wait_100, keyboard_led_check_timeout, 0x54, 0xFFFFFFF0, 1, 0, 5, 1, 0x54

    ; Cooldown boundary across 32-bit wraparound: 99 ticks.
    TEST_CASE wrap_cooldown_99, keyboard_led_cooldown, 0x53, 0xFFFFFFF0, 5, 1, 5, 1, 0xFFFFFFF0

    ; Cooldown boundary across 32-bit wraparound: 100 ticks.
    TEST_CASE wrap_cooldown_100, keyboard_led_cooldown, 0x54, 0xFFFFFFF0, 5, 1, 0, 1, 0xFFFFFFF0

    ; All assertions passed.
    mov eax, 4
    mov ebx, 1
    mov ecx, success_message
    mov edx, success_message_end - success_message
    int 0x80

    mov eax, 1
    xor ebx, ebx
    int 0x80

%macro TEST_CASE 9
%%begin:
    mov dword [timer_ticks], %3
    mov dword [keyboard_led_started_tick], %4
    mov byte [keyboard_led_state], %5
    mov byte [keyboard_led_pending], %6

    call %2

    cmp byte [keyboard_led_state], %7
    jne test_failed
    cmp byte [keyboard_led_pending], %8
    jne test_failed
    cmp dword [keyboard_led_started_tick], %9
    jne test_failed
%endmacro

test_failed:
    mov eax, 4
    mov ebx, 1
    mov ecx, failure_message
    mov edx, failure_message_end - failure_message
    int 0x80
    mov eax, 1
    mov ebx, 1
    int 0x80

; Exact production timeout/cooldown branches follow.
BRANCHES_PLACEHOLDER

keyboard_led_service_done:
    ret

section .data
timer_ticks: dd 0
keyboard_led_started_tick: dd 0
keyboard_led_state: db 0
keyboard_led_pending: db 0

success_message: db "PASS: all 8 production-branch tests passed.", 10
success_message_end:
failure_message: db "FAIL: a production-branch assertion failed.", 10
failure_message_end:
'''

source = template.replace("BRANCHES_PLACEHOLDER", branches)
(root / "production_branch_test.asm").write_text(source)
print("Created production_branch_test.asm with 8 test cases.")
