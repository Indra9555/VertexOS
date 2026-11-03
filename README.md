# VertexOS

VertexOS is a learning-focused operating system built from scratch for the 32-bit x86 architecture.

The project is being developed incrementally to understand how operating systems work internally, from the boot process and protected mode to interrupts, device drivers, memory management, processes, user mode, filesystems, networking, and eventually a graphical environment.

VertexOS is primarily an educational and experimental operating system project.

---

## Project Goals

The main goal of VertexOS is to understand operating-system internals by implementing its major components step by step rather than relying on an existing kernel or operating-system framework.

The project focuses on understanding:

- How a computer boots
- How the CPU enters protected mode
- How a kernel is loaded and executed
- How interrupts work
- How hardware devices communicate with the CPU
- How physical memory is managed
- How paging and virtual memory work
- How processes and scheduling work
- How user programs interact with the kernel
- How filesystems and storage work
- How networking works at a low level
- How operating-system security mechanisms are designed

---

## Current Status

VertexOS currently boots a custom kernel in 32-bit x86 protected mode and provides a functional kernel environment with hardware interrupt handling, keyboard input, a command shell, timekeeping, physical memory management, a kernel heap, kernel panic handling, and serial debugging.

### Implemented

- Custom BIOS bootloader
- BIOS disk access using INT 13h extensions
- x86 protected mode
- Global Descriptor Table (GDT)
- 32-bit kernel
- VGA text-mode console
- Console cursor management
- Screen scrolling
- Keyboard driver
- Shift and Caps Lock handling
- Physical Caps Lock LED synchronization
- Interrupt Descriptor Table (IDT)
- Programmable Interrupt Controller (PIC)
- CPU exception handling
- Programmable Interval Timer (PIT)
- Kernel tick counter
- Kernel uptime
- Kernel timekeeping interface
- Interactive kernel shell
- Kernel utility library
  - String operations
  - Memory operations
  - Number conversion utilities
- Physical memory manager (PMM)
- E820 memory-map processing
- Physical page allocation and freeing
- Physical memory usage statistics
- Kernel heap
- Kernel panic system
- COM1 serial debugging
- Kernel image size validation
- Boot image validation
- Automated kernel-sector boundary tests
- QEMU-based development and testing

### Currently Being Developed

- Paging
- Virtual memory
- Improved memory diagnostics
- Storage subsystem
- Process management
- Scheduler
- User mode

### Planned

- ATA/disk driver
- Filesystem
- Virtual File System (VFS)
- Improved shell
- System calls
- User programs
- Inter-process communication
- Hardware abstraction
- Networking
- Security mechanisms
- Graphical interface

---

## Architecture

### Target Architecture

| Component | Details |
|---|---|
| CPU architecture | x86 |
| Kernel mode | 32-bit protected mode |
| Kernel type | Custom experimental kernel |
| Boot method | BIOS |
| Bootloader | Custom bootloader |
| Console | VGA text mode |
| Interrupt controller | 8259 PIC |
| Timer | Intel 8253/8254-compatible PIT |
| Keyboard interface | PS/2 |
| Serial interface | COM1 UART |
| Emulator | QEMU |

---

## Development Environment

VertexOS is currently developed inside Ubuntu running through WSL2.

### Tools

- NASM
- GNU ld
- GNU objcopy
- GNU Make
- GNU binutils
- Git
- QEMU
- Ubuntu on WSL2

---

## Boot Process

The current boot process is intentionally implemented from scratch.

The basic flow is:

```text
BIOS
  |
  v
Custom Boot Sector
  |
  v
Load Stage 2 Bootloader
  |
  v
Read E820 Memory Map
  |
  v
Load Kernel from Disk
  |
  v
Load GDT
  |
  v
Enter 32-bit Protected Mode
  |
  v
Jump to Kernel
  |
  v
Kernel Initialization
  |
  +--> Console
  |
  +--> Serial Debugging
  |
  +--> IDT
  |
  +--> PIC
  |
  +--> PIT / Timekeeping
  |
  +--> Keyboard
  |
  +--> Physical Memory Manager
  |
  +--> Kernel Heap
  |
  +--> Shell
  |
  v
Kernel Main Loop
```

The bootloader currently loads the kernel from disk into memory at:

```text
0x1000
```

The E820 memory map is passed to the kernel during the protected-mode handoff.

---

## Kernel

The VertexOS kernel is currently implemented primarily in x86 assembly.

The kernel is linked to execute at:

```text
0x1000
```

The kernel binary is converted from ELF to a flat binary image and then combined with the boot sector and stage 2 bootloader to create the final disk image.

The build system calculates the number of sectors required by the kernel and validates the kernel size against the bootloader's loading limit.

---

## Interrupt System

VertexOS currently contains an interrupt subsystem based on the x86 Interrupt Descriptor Table.

Implemented interrupt components include:

- Interrupt Descriptor Table (IDT)
- Interrupt handlers
- Programmable Interrupt Controller (PIC)
- Hardware IRQ handling
- CPU exception handling

The PIC is remapped so that hardware IRQs do not conflict with CPU exception vectors.

Current hardware interrupt mapping includes:

```text
IRQ0 -> 0x20 Timer
IRQ1 -> 0x21 Keyboard
```

### CPU Exceptions

VertexOS contains handlers for CPU exceptions.

Exception information can include:

- Exception name
- Interrupt vector
- Error code
- Instruction pointer (EIP)
- Code segment (CS)
- EFLAGS

For example, a divide-by-zero exception can be detected and reported by the kernel before halting the system.

---

## Timer and Timekeeping

VertexOS uses the Programmable Interval Timer (PIT) to generate periodic timer interrupts.

The current timer frequency is approximately:

```text
100 Hz
```

The kernel maintains a global tick counter.

The shell currently provides:

- `ticks`
- `uptime`

These commands allow the kernel timer and basic timekeeping system to be tested interactively.

---

## Keyboard Driver

VertexOS includes a PS/2 keyboard driver.

Current features include:

- Keyboard interrupt handling
- Character input
- Shift key support
- Caps Lock
- Backspace
- Enter
- Input buffering
- Maximum input length protection
- Shell prompt protection
- Caps Lock LED synchronization
- Asynchronous keyboard LED command handling
- Keyboard command timeout and recovery

The keyboard driver communicates directly with the PS/2 controller ports.

---

## Console

VertexOS currently uses VGA text mode for its console.

The console subsystem provides:

- Character output
- String output
- New lines
- Cursor management
- Cursor drawing/removal
- Backspace support
- Screen scrolling
- Screen-boundary protection
- Console clearing

The VGA text buffer is located at:

```text
0xB8000
```

with a standard `80 x 25` text-mode display.

---

## Kernel Shell

VertexOS currently contains an interactive kernel shell.

Available commands include:

| Command | Description |
|---|---|
| `help` | Display available commands |
| `about` | Display information about VertexOS |
| `version` | Display the kernel version |
| `info` | Display system information |
| `clear` | Clear the console |
| `ticks` | Display the kernel tick counter |
| `uptime` | Display kernel uptime |
| `echo` | Print supplied text |
| `mem` | Display physical memory statistics |
| `panic` | Trigger a manual kernel panic |

The `mem` command currently displays:

- Total usable physical pages
- Free physical pages
- Allocated physical pages
- Free physical memory in KiB
- Memory usage percentage

The shell operates directly inside the kernel and is currently not a user-space program.

---

## Physical Memory Manager

VertexOS contains a physical memory manager (PMM) that processes the BIOS E820 memory map.

The PMM currently supports:

- Detecting usable physical memory
- Tracking usable physical pages
- Reserving unavailable memory regions
- Reserving kernel and boot-related memory
- Allocating physical pages
- Freeing physical pages
- Tracking free and total usable pages
- Reporting physical memory usage

The PMM uses a bitmap-based page allocation system.

The current implementation manages physical memory within a configured maximum address range. Paging and virtual memory are planned as separate future milestones.

---

## Kernel Heap

VertexOS includes a kernel heap subsystem for dynamic kernel memory allocation.

The heap is currently part of the kernel's memory-management foundation. Its capabilities will evolve as paging and virtual memory are introduced.

---

## Kernel Panic

VertexOS contains a kernel panic subsystem for unrecoverable conditions and manual testing.

The panic system:

- Disables interrupts
- Displays a panic header
- Displays the panic reason
- Displays a halted-system message
- Permanently halts the CPU

Example:

```text
==================================================
                  KERNEL PANIC
==================================================
Reason: Manual panic test
System halted.
```

---

## Kernel Utility Library

VertexOS contains a small kernel utility library.

Current string and memory functions include:

- `strlen`
- `strcmp`
- `memset`
- `memcpy`
- `memcmp`
- `memmove`

Number conversion utilities include:

- `itoa`
- `itoa_hex`

These utilities will become increasingly important as the kernel grows.

---

## Serial Debugging

VertexOS includes a COM1 serial debugging driver.

The serial subsystem currently supports:

- `serial_init`
- `serial_write`
- `serial_print`
- `serial_write_hex`

COM1 is configured for:

| Setting | Value |
|---|---|
| Baud rate | 38400 |
| Data bits | 8 |
| Stop bits | 1 |
| Parity | None |

Serial output can be captured through QEMU.

Example:

```text
[SERIAL] COM1 initialized. Test value: 0x1234ABCD
```

Serial debugging will be used extensively as VertexOS becomes more complex, especially during memory management, paging, interrupt, and process development.

---

## Memory Layout

| Region | Address |
|---|---|
| Kernel load address | `0x1000` |
| VGA text buffer | `0xB8000` |
| Initial kernel stack | `0x90000` |

The bootloader uses a protected-mode GDT and establishes a kernel stack before transferring control to the kernel.

The physical memory manager uses the E820 memory map to identify usable and reserved regions.

The memory layout will evolve significantly when paging and virtual memory are introduced.

---

## Build System

VertexOS uses GNU Make to assemble, link, and build the final disk image.

The major build stages are:

```text
NASM
  |
  v
ELF32 Object Files
  |
  v
GNU ld
  |
  v
kernel.elf
  |
  v
objcopy
  |
  v
kernel.bin
  |
  v
Boot Sector + Stage 2 + Kernel
  |
  v
VertexOS.img
```

The build system also performs image validation and automated kernel-sector boundary tests.

---

## Building VertexOS

Clone the repository and enter the project:

```bash
git clone https://github.com/Indra9555/VertexOS.git
cd VertexOS
```

Build the operating system:

```bash
make
```

Run it using QEMU:

```bash
make run
```

Run build and image validation checks:

```bash
make check
```

Clean generated build files:

```bash
make clean
```

---

## Project Structure

```text
VertexOS/
|
├── boot/
│   ├── boot.asm
│   └── stage2.asm
|
├── kernel/
│   ├── kernel.asm
│   │
│   ├── console/
│   │   └── console.asm
│   │
│   ├── drivers/
│   │   ├── keyboard.asm
│   │   └── serial.asm
│   │
│   ├── interrupts/
│   │   ├── idt.asm
│   │   ├── pic.asm
│   │   ├── timer.asm
│   │   └── exceptions.asm
│   │
│   ├── lib/
│   │   ├── string.asm
│   │   └── number.asm
│   │
│   ├── memory/
│   │   ├── pmm.asm
│   │   └── heap.asm
│   │
│   ├── panic/
│   │   └── panic.asm
│   │
│   ├── shell/
│   │   └── shell.asm
│   │
│   ├── time/
│   │   └── time.asm
│   │
│   ├── include/
│   │   ├── string.inc
│   │   └── number.inc
│   │
│   └── linker.ld
│
├── tests/
│   └── test_kernel_sectors.py
│
├── Makefile
└── README.md
```

---

## Development Philosophy

VertexOS is intentionally being developed incrementally.

Each subsystem is implemented, tested, and verified before moving to the next major subsystem.

The development process generally follows:

```text
Design
  ↓
Implement
  ↓
Build
  ↓
Run in QEMU
  ↓
Test
  ↓
Debug
  ↓
Git checkpoint
  ↓
Next subsystem
```

The goal is not simply to produce a bootable operating system, but to understand why each component exists and how the components interact.

---

## Roadmap

### Phase 0 — Foundation

- Project structure
- Build system
- Git repository
- Custom bootloader
- QEMU boot testing

### Phase 1 — Kernel Core

- Protected mode
- GDT
- Kernel entry point
- VGA console
- IDT
- PIC
- CPU exceptions
- Keyboard driver
- Kernel shell

### Phase 2 — Kernel Services

- PIT timer
- Kernel tick counter
- Timekeeping
- Kernel utility library
- Kernel panic system
- Serial debugging

### Phase 3 — Memory Management

- E820 memory map processing
- Physical memory manager
- Physical page allocation and freeing
- Kernel heap
- Paging
- Virtual memory

### Phase 4 — Storage

- Disk driver
- ATA support
- Block device layer
- Filesystem
- Virtual File System

### Phase 5 — Processes

- Process abstraction
- Kernel task management
- Context switching
- Scheduler
- User mode

### Phase 6 — System Interface

- System calls
- User programs
- Process isolation
- Inter-process communication

### Phase 7 — Hardware and Networking

- Hardware abstraction
- Additional device drivers
- Network driver
- Network stack
- Basic networking utilities

### Phase 8 — User Experience

- Advanced shell
- User utilities
- Graphical interface
- Basic desktop environment

### Phase 9 — Hardening and Tooling

- Memory protection
- Kernel/user separation
- Security mechanisms
- Better diagnostics
- Kernel debugging tools
- Automated kernel-sector boundary testing
- Documentation improvements

---

## Current Limitations

VertexOS is an experimental educational operating system and is not intended for production use.

Current limitations include:

- 32-bit protected-mode kernel
- Limited hardware support
- No paging or virtual memory yet
- Limited physical memory management
- No filesystem
- No user mode
- No processes
- No scheduler
- No system calls
- No networking stack
- No graphical environment

These limitations are expected and will be addressed progressively as development continues.

---

## License

License: To be decided.
