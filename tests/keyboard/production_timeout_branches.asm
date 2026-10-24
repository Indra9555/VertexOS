keyboard_led_check_timeout:
    mov eax, [timer_ticks]
    sub eax, [keyboard_led_started_tick]
    cmp eax, KEYBOARD_LED_TIMEOUT_TICKS
    jb keyboard_led_service_done

    ; Recover from a missing ACK without blocking keyboard input.
    ; Preserve a retry request for the latest LED value.
    mov byte [keyboard_led_pending], 1
    mov byte [keyboard_led_state], 5
    mov eax, [timer_ticks]
    mov [keyboard_led_started_tick], eax
    jmp keyboard_led_service_done

keyboard_led_cooldown:
    mov eax, [timer_ticks]
    sub eax, [keyboard_led_started_tick]
    cmp eax, KEYBOARD_LED_TIMEOUT_TICKS
    jb keyboard_led_service_done

    ; Cooldown reduces the chance that a late ACK is mistaken
    ; for the response to a newly issued command.
    mov byte [keyboard_led_state], 0
    jmp keyboard_led_service_done

