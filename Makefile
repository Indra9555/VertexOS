ASM = nasm
QEMU = qemu-system-x86_64

BOOT_SRC = boot/boot.asm
BOOT_BIN = build/boot.bin

KERNEL_SRC = kernel/kernel.asm
KERNEL_BIN = build/kernel.bin

OS_IMAGE = build/VertexOS.img

.PHONY: all boot kernel image run clean

all: image

boot: $(BOOT_BIN)

kernel: $(KERNEL_BIN)

image: $(OS_IMAGE)

$(BOOT_BIN): $(BOOT_SRC)
	@mkdir -p build
	$(ASM) -f bin $(BOOT_SRC) -o $(BOOT_BIN)

$(KERNEL_BIN): $(KERNEL_SRC)
	@mkdir -p build
	$(ASM) -f bin $(KERNEL_SRC) -o $(KERNEL_BIN)

$(OS_IMAGE): $(BOOT_BIN) $(KERNEL_BIN)
	cat $(BOOT_BIN) $(KERNEL_BIN) > $(OS_IMAGE)

run: image
	$(QEMU) -drive format=raw,file=$(OS_IMAGE)

clean:
	rm -f $(BOOT_BIN) $(KERNEL_BIN) $(OS_IMAGE)
