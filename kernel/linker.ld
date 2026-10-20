
OUTPUT_FORMAT("elf32-i386")
OUTPUT_ARCH(i386)
ENTRY(kernel_start)

PHDRS
{
    code PT_LOAD FLAGS(5);
    writable PT_LOAD FLAGS(6);
}

SECTIONS
{
    . = 0x1000;
    __kernel_start = .;

    .text ALIGN(16) :
    {
        __text_start = .;
        *(.text .text.*)
        __text_end = .;
    } :code

    .rodata ALIGN(16) :
    {
        __rodata_start = .;
        *(.rodata .rodata.*)
        __rodata_end = .;
    } :code

    .data ALIGN(16) :
    {
        __data_start = .;
        *(.data .data.*)
        __data_end = .;
    } :writable

    .bss ALIGN(512) (NOLOAD) :
    {
        __bss_start = .;
        *(COMMON)
        *(.bss .bss.*)
        . = ALIGN(16);
        __bss_end = .;
    } :writable

    . = ALIGN(4096);
    __kernel_end = .;

    /DISCARD/ :
    {
        *(.comment)
        *(.note*)
        *(.eh_frame*)
    }
}
