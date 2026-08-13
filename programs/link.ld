OUTPUT_ARCH(riscv)
ENTRY(_start) /* 定義 _start 為程式的entry point */

MEMORY 
{
    IMEM (rx) : ORIGIN = 0x00000000, LENGTH = 0x00000100
    DMEM (rw) : ORIGIN = 0x10000000, LENGTH = 0x00001000
}

SECTIONS 
{
    .text ORIGIN(IMEM) :
    {
        . = ALIGN(4);

        KEEP(*(.text.start))
        *(.text .text.*)

        *(.rodata .rodata.*)

        . = ALIGN(4);
    } > IMEM

    .data ORIGIN(DMEM) :
    {
        . = ALIGN(4);
        __data_elf_start = .;

        *(.data .data*)

        . = ALIGN(4);
        __data_elf_end = .;
    } > DMEM

    .bss (NOLOAD) :
    {
        . = ALIGN(4);
        __bss_elf_start = .;

        *(.bss .bss*)
        *(COMMON)

        . = ALIGN(4);
        __bss_elf_end = .;
    } > DMEM

    __imem_elf_base = ORIGIN(IMEM);
    __dmem_elf_base = ORIGIN(DMEM);

    __data_runtime_start    = __data_elf_start  -   __dmem_elf_base;
    __data_runtime_end      = __data_elf_end    -   __dmem_elf_base;
    __bss_runtime_start     = __bss_elf_start   -   __dmem_elf_base;
    __bss_runtime_end       = __bss_elf_end     -   __dmem_elf_base;

    /DISCARD/ : 
    {
        *(.comment)
        *(.note*)
        *(.eh_frame*)
        *(.riscv.attributes)
    }
}
ASSERT(DEFINED(_start), "link error: _start is not defined")
ASSERT(_start == ORIGIN(IMEM), "link error: _start must be at reset vector 0x00000000")
ASSERT(SIZEOF(.text) <= LENGTH(IMEM), "link error: .text/.rodata exceed 256 byte IMEM")
ASSERT(SIZEOF(.data) + SIZEOF(.bss) <= LENGTH(DMEM), "link error: .data/.bss exceed 4096 byte DMEM")
