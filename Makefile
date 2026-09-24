# ============================================================
# VertexOS Build System
# ============================================================

ASM = nasm
LD = ld
OBJCOPY = objcopy
QEMU = qemu-system-x86_64


# ============================================================
# Source files
# ============================================================

BOOT_SRC = boot/boot.asm

KERNEL_SRC = kernel/kernel.asm
IDT_SRC = kernel/interrupts/idt.asm
PIC_SRC = kernel/interrupts/pic.asm
KEYBOARD_SRC = kernel/drivers/keyboard.asm


# ============================================================
# Build files
# ============================================================

BOOT_BIN = build/boot.bin

KERNEL_OBJ = build/kernel.o
IDT_OBJ = build/idt.o
PIC_OBJ = build/pic.o
KEYBOARD_OBJ = build/keyboard.o

KERNEL_ELF = build/kernel.elf
KERNEL_BIN = build/kernel.bin

OS_IMAGE = build/VertexOS.img


# ============================================================
# Default target
# ============================================================

.PHONY: all boot kernel idt pic keyboard image run clean

all: image


# ============================================================
# Bootloader
# ============================================================

boot: $(BOOT_BIN)

$(BOOT_BIN): $(BOOT_SRC)
	@mkdir -p build
	$(ASM) -f bin $(BOOT_SRC) -o $(BOOT_BIN)


# ============================================================
# Kernel
# ============================================================

kernel: $(KERNEL_BIN)


$(KERNEL_OBJ): $(KERNEL_SRC)
	@mkdir -p build
	$(ASM) -f elf32 $(KERNEL_SRC) -o $(KERNEL_OBJ)


# ============================================================
# IDT
# ============================================================

idt: $(IDT_OBJ)


$(IDT_OBJ): $(IDT_SRC)
	@mkdir -p build
	$(ASM) -f elf32 $(IDT_SRC) -o $(IDT_OBJ)


# ============================================================
# PIC
# ============================================================

pic: $(PIC_OBJ)


$(PIC_OBJ): $(PIC_SRC)
	@mkdir -p build
	$(ASM) -f elf32 $(PIC_SRC) -o $(PIC_OBJ)


# ============================================================
# Keyboard Driver
# ============================================================

keyboard: $(KEYBOARD_OBJ)


$(KEYBOARD_OBJ): $(KEYBOARD_SRC)
	@mkdir -p build
	$(ASM) -f elf32 $(KEYBOARD_SRC) -o $(KEYBOARD_OBJ)


# ============================================================
# Link Kernel
# ============================================================

$(KERNEL_ELF): $(KERNEL_OBJ) \
               $(IDT_OBJ) \
               $(PIC_OBJ) \
               $(KEYBOARD_OBJ) \
               kernel/linker.ld

	$(LD) -m elf_i386 \
		-T kernel/linker.ld \
		-o $(KERNEL_ELF) \
		$(KERNEL_OBJ) \
		$(IDT_OBJ) \
		$(PIC_OBJ) \
		$(KEYBOARD_OBJ)


# ============================================================
# Convert ELF → flat binary
# ============================================================

$(KERNEL_BIN): $(KERNEL_ELF)

	$(OBJCOPY) -O binary \
		$(KERNEL_ELF) \
		$(KERNEL_BIN)


# ============================================================
# Create OS image
# ============================================================

image: $(OS_IMAGE)


$(OS_IMAGE): $(BOOT_BIN) $(KERNEL_BIN)
	cat $(BOOT_BIN) $(KERNEL_BIN) > $(OS_IMAGE)
	truncate -s 8192 $(OS_IMAGE)

# ============================================================
# Run VertexOS
# ============================================================

run: image

	$(QEMU) -drive format=raw,file=$(OS_IMAGE)


# ============================================================
# Clean
# ============================================================

clean:

	rm -f $(BOOT_BIN) \
	      $(KERNEL_OBJ) \
	      $(IDT_OBJ) \
	      $(PIC_OBJ) \
	      $(KEYBOARD_OBJ) \
	      $(KERNEL_ELF) \
	      $(KERNEL_BIN) \
	      $(OS_IMAGE)
