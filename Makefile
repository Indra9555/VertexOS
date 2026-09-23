ASM = nasm
QEMU = qemu-system-x86_64

BOOT_SRC = boot/boot.asm
BOOT_BIN = build/boot.bin

.PHONY: all boot run clean

all: boot

boot: $(BOOT_BIN)

$(BOOT_BIN): $(BOOT_SRC)
	@mkdir -p build
	$(ASM) -f bin $(BOOT_SRC) -o $(BOOT_BIN)

run: all
	$(QEMU) -drive format=raw,file=$(BOOT_BIN)

clean:
	rm -f $(BOOT_BIN)
