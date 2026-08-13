OUTPUT_ARCH(riscv)
ENTRY(rvtest_entry_point)

MEMORY
{
    IMEM (rx)  : ORIGIN = 0x00000000, LENGTH = 0x00000100
    DMEM (rw)  : ORIGIN = 0x10000000, LENGTH = 0x00001000
}

SECTIONS
{
    .text.init :
    {
        KEEP(*(.text.init))
    } > IMEM

    .text.rvtest :
    {
        *(.text.rvtest)
        *(.text.rvtest.*)
    } > IMEM

    /* ACT4 requires .data to precede .text.rvmodel in section order. */
    .data :
    {
        *(.data)
        *(.data.*)
        *(.rodata)
        *(.rodata.*)
    } > DMEM

    .text.rvmodel :
    {
        *(.text.rvmodel)
        *(.text.rvmodel.*)
        *(.text)
        *(.text.*)
    } > IMEM

    .bss (NOLOAD) :
    {
        *(.bss)
        *(.bss.*)
        *(COMMON)
    } > DMEM

    .test_status 0x10000ff0 :
    {
        KEEP(*(.test_status))
    } > DMEM

    _end = .;

    /DISCARD/ :
    {
        *(.comment)
        *(.note*)
        *(.eh_frame*)
        *(.riscv.attributes)
    }
}

ASSERT(DEFINED(rvtest_entry_point), "ACT link error: rvtest_entry_point is missing")
ASSERT(SIZEOF(.text.init) + SIZEOF(.text.rvtest) + SIZEOF(.text.rvmodel) <= LENGTH(IMEM),
       "ACT link error: code exceeds the current 256-byte IMEM")
ASSERT(ADDR(.bss) + SIZEOF(.bss) <= 0x10000ff0,
       "ACT link error: data overlaps the reserved test status word")
