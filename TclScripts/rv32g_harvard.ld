/* This is GNU's LinkerScript */
/* I geniunely discovered it only today. Turns out
I'm a total noob in Assembly (for now though). */

ENTRY(start)

MEMORY
{
    ROM (rx)  : ORIGIN = 0x00000000, LENGTH = 2k
    RAM (rwx) : ORIGIN = 0x00000800, LENGTH = 2k
}

/* Define stack size */
__stack_size = 1024;

SECTIONS {
    /* Text goes to ROM */
    .text : {
        . = 0x000000;
        *(.text);
    } > ROM

    /* Rest goes to RAM */
    .data : {
        . = 0x000;
        *(.data)
        . = ALIGN(4);
    } > RAM

    .bss : {
        *(.bss)
        . = ALIGN(4);
    } > RAM

    .rodata : {
        *(.rodata)
        . = ALIGN(4);
    } > RAM

    /* Place stack at the top of RAM */
    .stack (NOLOAD) : ALIGN(16)
    {
        . = ORIGIN(RAM) + LENGTH(RAM) - __stack_size;
        __stack_bottom = .;
        . = . + __stack_size;
        __stack_top    = .;
    } > RAM

    /* I don't know what these are */
    /DISCARD/ : {
        *(.note*);
        *(.iplt*);
        *(.igot*);
        *(.rel*);
        *(.comment);
        *(.riscv.attributes);
    }
}
