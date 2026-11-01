#!/usr/bin/env python3

MAX_KERNEL_BYTES = 17408
SECTOR_SIZE = 512


def calculate_sectors(size):
    if size <= 0:
        raise ValueError("Kernel size must be positive")

    if size > MAX_KERNEL_BYTES:
        raise ValueError("Kernel exceeds the 34-sector limit")

    return (size + SECTOR_SIZE - 1) // SECTOR_SIZE


def test_valid_sizes():
    cases = {
        1: 1,
        511: 1,
        512: 1,
        513: 2,
        1024: 2,
        1025: 3,
        16384: 32,
        16896: 33,
        17408: 34,
    }

    for size, expected in cases.items():
        actual = calculate_sectors(size)
        assert actual == expected, (
            f"{size} bytes: expected {expected}, got {actual}"
        )


def test_invalid_sizes():
    for size in (0, -1, 17409):
        try:
            calculate_sectors(size)
        except ValueError:
            continue

        raise AssertionError(f"Invalid size {size} was accepted")


if __name__ == "__main__":
    test_valid_sizes()
    test_invalid_sizes()
    print("[TEST] Kernel sector calculations: PASS")
    print("[TEST] Invalid kernel sizes: PASS")
    print("[TEST] All sector boundary tests PASSED.")
