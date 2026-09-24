ASM = nasm
LD = ld
QEMU = qemu-system-x86_64

BOOT_SRC = boot/boot.asm
BOOT_BIN = build/boot.bin

KERNEL_SRC = kernel/kernel.asm
KERNEL_OBJ = build/kernel.o

IDT_SRC = kernel/interrupts/idt.asm
IDT_OBJ = build/idt.o

LINKER_SCRIPT = kernel/linker.ld
KERNEL_ELF = build/kernel.elf
KERNEL_BIN = build/kernel.bin

OS_IMAGE = build/VertexOS.img

.PHONY: all boot kernel image run clean

all: image

# ------------------------------------------------------------
# Build bootloader
# ------------------------------------------------------------

boot: $(BOOT_BIN)

$(BOOT_BIN): $(BOOT_SRC)
	@mkdir -p build
	$(ASM) -f bin $(BOOT_SRC) -o $(BOOT_BIN)

# ------------------------------------------------------------
# Build kernel
# ------------------------------------------------------------

kernel: $(KERNEL_BIN)

$(KERNEL_OBJ): $(KERNEL_SRC)
	@mkdir -p build
	$(ASM) -f elf32 $(KERNEL_SRC) -o $(KERNEL_OBJ)

$(IDT_OBJ): $(IDT_SRC)
	@mkdir -p build
	$(ASM) -f elf32 $(IDT_SRC) -o $(IDT_OBJ)

$(KERNEL_ELF): $(KERNEL_OBJ) $(IDT_OBJ) $(LINKER_SCRIPT)
	$(LD) -m elf_i386 -T $(LINKER_SCRIPT) -o $(KERNEL_ELF) $(KERNEL_OBJ) $(IDT_OBJ)

$(KERNEL_BIN): $(KERNEL_ELF)
	objcopy -O binary $(KERNEL_ELF) $(KERNEL_BIN)

# ------------------------------------------------------------
# Create bootable OS image
# ------------------------------------------------------------

image: $(OS_IMAGE)

$(OS_IMAGE): $(BOOT_BIN) $(KERNEL_BIN)
	cat $(BOOT_BIN) $(KERNEL_BIN) > $(OS_IMAGE)
	@size=$$(stat -c %s $(OS_IMAGE)); \
	sectors=$$(( (size + 511) / 512 )); \
	truncate -s $$((sectors * 512)) $(OS_IMAGE)

# ------------------------------------------------------------
# Run VertexOS in QEMU
# ------------------------------------------------------------

run: image
	$(QEMU) -drive format=raw,file=$(OS_IMAGE)

# ------------------------------------------------------------
# Remove generated files
# ------------------------------------------------------------

clean:
	rm -f $(BOOT_BIN) \
	      $(KERNEL_OBJ) \
	      $(IDT_OBJ) \
	      $(KERNEL_ELF) \
	      $(KERNEL_BIN) \
	      $(OS_IMAGE)
