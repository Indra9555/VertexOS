ASM = nasm
LD = ld
OBJCOPY = objcopy
QEMU = qemu-system-x86_64

BOOT_SRC = boot/boot.asm
BOOT_BIN = build/boot.bin

KERNEL_SRC = kernel/kernel.asm
KERNEL_OBJ = build/kernel.o

IDT_SRC = kernel/interrupts/idt.asm
IDT_OBJ = build/idt.o

KEYBOARD_SRC = kernel/drivers/keyboard.asm
KEYBOARD_OBJ = build/keyboard.o

KERNEL_ELF = build/kernel.elf
KERNEL_BIN = build/kernel.bin

PIC_SRC = kernel/interrupts/pic.asm
PIC_OBJ = build/pic.o

LINKER_SCRIPT = kernel/linker.ld

OS_IMAGE = build/VertexOS.img


.PHONY: all boot kernel image run clean


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
# Interrupt Descriptor Table
# ============================================================

$(IDT_OBJ): $(IDT_SRC)
	@mkdir -p build
	$(ASM) -f elf32 $(IDT_SRC) -o $(IDT_OBJ)


# ============================================================
# Keyboard Driver
# ============================================================

$(KEYBOARD_OBJ): $(KEYBOARD_SRC)
	@mkdir -p build
	$(ASM) -f elf32 $(KEYBOARD_SRC) -o $(KEYBOARD_OBJ)


# ============================================================
# Link Kernel
# ============================================================

$(KERNEL_ELF): $(KERNEL_OBJ) $(IDT_OBJ) $(PIC_OBJ) $(KEYBOARD_OBJ) $(LINKER_SCRIPT)
	$(LD) -m elf_i386 -T $(LINKER_SCRIPT) \
		-o $(KERNEL_ELF) \
		$(KERNEL_OBJ) \
		$(IDT_OBJ) \
                $(PIC_OBJ) \
		$(KEYBOARD_OBJ)

# ============================================================
# Programmable Interrupt Controller
# ============================================================

$(PIC_OBJ): $(PIC_SRC)
	@mkdir -p build
	$(ASM) -f elf32 $(PIC_SRC) -o $(PIC_OBJ)


# ============================================================
# Convert ELF → Raw Binary
# ============================================================

$(KERNEL_BIN): $(KERNEL_ELF)
	$(OBJCOPY) -O binary $(KERNEL_ELF) $(KERNEL_BIN)


# ============================================================
# Create VertexOS Disk Image
# ============================================================

image: $(OS_IMAGE)


$(OS_IMAGE): $(BOOT_BIN) $(KERNEL_BIN)
	cat $(BOOT_BIN) $(KERNEL_BIN) > $(OS_IMAGE)
	truncate -s 4096 $(OS_IMAGE)


# ============================================================
# Run VertexOS
# ============================================================

run: image
	$(QEMU) -drive format=raw,file=$(OS_IMAGE)


# ============================================================
# Clean Build Files
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
