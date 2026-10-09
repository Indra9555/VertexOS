ASM = nasm
LD = ld
OBJCOPY = objcopy
QEMU = qemu-system-x86_64

BOOT_SRC = boot/boot.asm
BOOT_BIN = build/boot.bin

STAGE2_SRC = boot/stage2.asm
STAGE2_BIN = build/stage2.bin
STAGE2_SIZE = 2048

KERNEL_SOURCES = \
	kernel/kernel.asm \
	kernel/console/console.asm \
	kernel/drivers/keyboard.asm \
	kernel/drivers/serial.asm \
	kernel/interrupts/idt.asm \
	kernel/interrupts/pic.asm \
	kernel/interrupts/timer.asm \
	kernel/interrupts/exceptions.asm \
	kernel/lib/string.asm \
	kernel/lib/number.asm \
	kernel/panic/panic.asm \
	kernel/shell/shell.asm \
	kernel/time/time.asm

KERNEL_OBJECTS = $(patsubst kernel/%.asm,build/%.o,$(KERNEL_SOURCES))

KERNEL_ELF = build/kernel.elf
KERNEL_BIN = build/kernel.bin
LINKER_SCRIPT = kernel/linker.ld
OS_IMAGE = build/VertexOS.img

.PHONY: all boot stage2 kernel image run clean

all: image

boot: $(BOOT_BIN)

$(BOOT_BIN): $(BOOT_SRC)
	mkdir -p build
	$(ASM) -f bin $< -o $@
	test "$$(stat -c %s $@)" -eq 512

stage2: $(STAGE2_BIN)

$(STAGE2_BIN): $(STAGE2_SRC)
	mkdir -p build
	$(ASM) -f bin $< -o $@
	test "$$(stat -c %s $@)" -le $(STAGE2_SIZE)
	truncate -s $(STAGE2_SIZE) $@

kernel: $(KERNEL_BIN)

build/%.o: kernel/%.asm
	mkdir -p $(dir $@)
	$(ASM) -f elf32 $< -o $@

$(KERNEL_ELF): $(KERNEL_OBJECTS) $(LINKER_SCRIPT)
	$(LD) -m elf_i386 -T $(LINKER_SCRIPT) \
		-o $@ $(KERNEL_OBJECTS)

$(KERNEL_BIN): $(KERNEL_ELF)
	$(OBJCOPY) -O binary $< $@
	test "$$(stat -c %s $@)" -le 16384

image: $(OS_IMAGE)

$(OS_IMAGE): $(BOOT_BIN) $(STAGE2_BIN) $(KERNEL_BIN)
	cat $(BOOT_BIN) $(STAGE2_BIN) $(KERNEL_BIN) > $@
	truncate -s 20480 $@

run: image
	$(QEMU) -drive format=raw,file=$(OS_IMAGE) -serial stdio

clean:
	rm -rf build
