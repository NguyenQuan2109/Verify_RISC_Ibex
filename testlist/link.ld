OUTPUT_ARCH(riscv)
ENTRY(_start)

SECTIONS
{
  . = 0x80000000;
  .text : ALIGN(4) {
    KEEP(*(.vectors))
    *(.text .text.*)
  }
  .rodata : ALIGN(4) { *(.rodata .rodata.*) }
  .data : ALIGN(4) { *(.data .data.*) }
  .bss (NOLOAD) : ALIGN(4) { *(.bss .bss.* COMMON) }
}

