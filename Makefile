ASM = nasm
LD = ld
OBJCOPY = objcopy
QEMU = qemu-system-x86_64


# ============================================================
# SOURCE FILES
# ============================================================

BOOT_SRC = boot/boot.asm
BOOT_BIN = build/boot.bin

KERNEL_SRC = kernel/kernel.asm
KERNEL_OBJ = build/kernel.o

IDT_SRC = kernel/interrupts/idt.asm
IDT_OBJ = build/idt.o

PIC_SRC = kernel/interrupts/pic.asm
PIC_OBJ = build/pic.o

TIMER_SRC = kernel/interrupts/timer.asm
TIMER_OBJ = build/timer.o

EXCEPTIONS_SRC = kernel/interrupts/exceptions.asm
EXCEPTIONS_OBJ = build/exceptions.o

KEYBOARD_SRC = kernel/drivers/keyboard.asm
KEYBOARD_OBJ = build/keyboard.o

SHELL_SRC = kernel/shell/shell.asm
SHELL_OBJ = build/shell.o

CONSOLE_SRC = kernel/console/console.asm
CONSOLE_OBJ = build/console.o


# ============================================================
# KERNEL
# ============================================================

KERNEL_ELF = build/kernel.elf
KERNEL_BIN = build/kernel.bin

LINKER_SCRIPT = kernel/linker.ld


# ============================================================
# DISK IMAGE
# ============================================================

OS_IMAGE = build/VertexOS.img


# ============================================================
# TARGETS
# ============================================================

.PHONY: all boot kernel image run clean

all: image


# ============================================================
# BOOTLOADER
# ============================================================

boot: $(BOOT_BIN)

$(BOOT_BIN): $(BOOT_SRC)
	mkdir -p build
	$(ASM) -f bin $(BOOT_SRC) -o $(BOOT_BIN)


# ============================================================
# KERNEL
# ============================================================

kernel: $(KERNEL_BIN)

$(KERNEL_OBJ): $(KERNEL_SRC)
	mkdir -p build
	$(ASM) -f elf32 $(KERNEL_SRC) -o $(KERNEL_OBJ)


# ============================================================
# INTERRUPT DESCRIPTOR TABLE
# ============================================================

$(IDT_OBJ): $(IDT_SRC)
	mkdir -p build
	$(ASM) -f elf32 $(IDT_SRC) -o $(IDT_OBJ)


# ============================================================
# PROGRAMMABLE INTERRUPT CONTROLLER
# ============================================================

$(PIC_OBJ): $(PIC_SRC)
	mkdir -p build
	$(ASM) -f elf32 $(PIC_SRC) -o $(PIC_OBJ)


# ============================================================
# PROGRAMMABLE INTERVAL TIMER
# ============================================================

$(TIMER_OBJ): $(TIMER_SRC)
	mkdir -p build
	$(ASM) -f elf32 $(TIMER_SRC) -o $(TIMER_OBJ)


# ============================================================
# CPU EXCEPTIONS
# ============================================================

$(EXCEPTIONS_OBJ): $(EXCEPTIONS_SRC)
	mkdir -p build
	$(ASM) -f elf32 $(EXCEPTIONS_SRC) -o $(EXCEPTIONS_OBJ)


# ============================================================
# KEYBOARD DRIVER
# ============================================================

$(KEYBOARD_OBJ): $(KEYBOARD_SRC)
	mkdir -p build
	$(ASM) -f elf32 $(KEYBOARD_SRC) -o $(KEYBOARD_OBJ)


# ============================================================
# SHELL
# ============================================================

$(SHELL_OBJ): $(SHELL_SRC)
	mkdir -p build
	$(ASM) -f elf32 $(SHELL_SRC) -o $(SHELL_OBJ)


# ============================================================
# CONSOLE
# ============================================================

$(CONSOLE_OBJ): $(CONSOLE_SRC)
	mkdir -p build
	$(ASM) -f elf32 $(CONSOLE_SRC) -o $(CONSOLE_OBJ)


# ============================================================
# LINK KERNEL
# ============================================================

$(KERNEL_ELF): \
	$(KERNEL_OBJ) \
	$(IDT_OBJ) \
	$(PIC_OBJ) \
	$(TIMER_OBJ) \
	$(EXCEPTIONS_OBJ) \
	$(KEYBOARD_OBJ) \
	$(SHELL_OBJ) \
	$(CONSOLE_OBJ) \
	$(LINKER_SCRIPT)

	$(LD) -m elf_i386 -T $(LINKER_SCRIPT) \
		-o $(KERNEL_ELF) \
		$(KERNEL_OBJ) \
		$(IDT_OBJ) \
		$(PIC_OBJ) \
		$(TIMER_OBJ) \
		$(EXCEPTIONS_OBJ) \
		$(KEYBOARD_OBJ) \
		$(SHELL_OBJ) \
		$(CONSOLE_OBJ)


# ============================================================
# CONVERT ELF → RAW BINARY
# ============================================================

$(KERNEL_BIN): $(KERNEL_ELF)
	$(OBJCOPY) -O binary $(KERNEL_ELF) $(KERNEL_BIN)


# ============================================================
# CREATE DISK IMAGE
# ============================================================
#
# Bootloader loads:
#
#	32 sectors × 512 bytes = 16384 bytes
#
# Kernel starts immediately after boot sector.
#
# Therefore image contains:
#
#	512 byte boot sector
#	16384 byte kernel area
#
# Total required space = 16896 bytes
#
# We use 20 KB so the OS has additional room to grow.
#
# ============================================================

image: $(OS_IMAGE)

$(OS_IMAGE): $(BOOT_BIN) $(KERNEL_BIN)
	cat $(BOOT_BIN) $(KERNEL_BIN) > $(OS_IMAGE)
	truncate -s 20480 $(OS_IMAGE)


# ============================================================
# RUN
# ============================================================

run: image
	$(QEMU) -drive format=raw,file=$(OS_IMAGE)


# ============================================================
# CLEAN
# ============================================================

clean:
	rm -f $(BOOT_BIN) \
		$(KERNEL_OBJ) \
		$(IDT_OBJ) \
		$(PIC_OBJ) \
		$(TIMER_OBJ) \
		$(EXCEPTIONS_OBJ) \
		$(KEYBOARD_OBJ) \
		$(SHELL_OBJ) \
		$(CONSOLE_OBJ) \
		$(KERNEL_ELF) \
		$(KERNEL_BIN) \
		$(OS_IMAGE)
