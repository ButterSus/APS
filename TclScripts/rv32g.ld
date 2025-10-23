/* This is GNU's LinkerScript */
/* I geniunely discovered it only today. Turns out
I'm a total noob in Assembly (for now though). */

SECTIONS
{
  .text 0x0 : ALIGN(4)
  {
    *(.text)
    *(.text.*)
  }

  .data : ALIGN(4)
  {
    *(.data)
    *(.data.*)
  }

  .bss : ALIGN(4)
  {
    *(.bss)
    *(.bss.*)
  }

  .rodata : ALIGN(4)
  {
    *(.bss)
    *(.bss.*)
  }
}
