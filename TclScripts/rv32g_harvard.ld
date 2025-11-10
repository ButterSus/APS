/* GNU LinkerScript */

/*
 * Entry metadata for ELF executable.
 * While kernel uses it as initial PC for bootloader
 * CPU jump, we don't have "bootloader", therefore
 * we just need to make sure that _start has address of 0x00.
 */
ENTRY(_start)

MEMORY  /* Segments = "Memory regions" */
{
    /* Origin here is VMA, substituted to section binaries */
    ROM (RX!W) : ORIGIN = 0x00000000, LENGTH = 1K
    RAM (RW!X) : ORIGIN = 0x00000000, LENGTH = 2K
    /* LinkerScript uses lengths to assert if sections fit into segments */
}

/* Minimal (guaranteed) stack sizes */
_trap_stack_size = 0x280;  /* 640 bytes */
_stack_size      = 0x280;  /* 640 bytes */

SECTIONS {
    .text : {
        ASSERT (_start == 0x00000000,
                "Bootloader doesn't support PC initialization other than 0x00000000.");

        *(.boot);
        *(.text*);
    } > ROM

    /*
     * AT directive will put it in Flash memory region,
     * while keeping addresses normal
     */
    .data : AT (0x00800000) {
        /* Put gbl_ptr in a middle of 4KB range */
        _gbl_ptr = . + 2048;

        *(.*data*)
        *(.sdata*)  /* For small variables */
    } > RAM

    /* Aligned data is easier to access */
    . = ALIGN (4);

    /*
     * On some platforms, some or all of the bss
     * section is initialized to zeroes. Unix-like
     * systems and Windows initialize the bss
     * section to zero
     */
    .bss : {
        _bss_start = .;
        *(.bss*)
        *(.sbss*)  /* For small variables */
        _bss_end   = .;
    } > RAM

    /*
     * .rodata section is merged with .text sometimes.
     * In our case, we don't have any kernel that will
     * find utilize such optimizations.
     */
    /* NO .rodata : { .. } */

    /*
     * RISC-V ABIs Specification: "The stack grows downwards
     * (towards lower addresses) and the stack pointer shall
     * be aligned to a 128-bit boundary upon procedure entry."
     */
    _trap_stack_ptr = LENGTH (RAM) - LENGTH (RAM) % 16;
    _stack_ptr = (_trap_stack_ptr - _trap_stack_size) - (_trap_stack_ptr - _trap_stack_size) % 16;

    /*
     * Please, be careful, GNU LinkerScript is such an
     * old dinosaur, that it uses unsigned integer logic
     * meaning it doesn't support negative values
     */
    ASSERT (. + _stack_size <= _stack_ptr,
            "Stack pointer exceed memory size")

    /*
     * Remove redundant sections
     */
    /DISCARD/ : {
        *(.riscv.attributes)
        *(.comment)
    }
}
