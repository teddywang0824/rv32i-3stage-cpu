/* CPU Build ACT4 memory map.  The simulation adapter will present this
 * logical 32 MiB RAM to both instruction fetch and data access. */
RAM_ORIGIN = 0x00000000;
RAM_LENGTH = 0x02000000;
TEST_BASE = 0x00000000;
NUM_HARTS = 1;
STACK_SIZE = 0x00020000;
TEST_STATUS = 0x01fffff0;

OUTPUT_ARCH(riscv)
ENTRY(rvtest_entry_point)

MEMORY
{
  ram (rwx) : ORIGIN = RAM_ORIGIN, LENGTH = RAM_LENGTH
}

PROVIDE(__stack_size = STACK_SIZE);
PROVIDE(__num_harts = NUM_HARTS);

SECTIONS
{
  ASSERT(TEST_BASE >= ORIGIN(ram) && TEST_BASE < ORIGIN(ram) + LENGTH(ram),
         "TEST_BASE is outside ACT RAM")

  .text.init TEST_BASE : { KEEP(*(.text.init)) } > ram
  .text.rvtest . : { *(.text.rvtest) *(.text.rvtest.*) } > ram

  . = ALIGN(0x4000);
  .rodata . : { *(.rodata) *(.rodata.*) *(.srodata) *(.srodata.*) } > ram
  .data . : { *(.data) *(.data.*) *(.sdata) *(.sdata.*) } > ram

  . = ALIGN(16);
  .bss . (NOLOAD) :
  {
    __bss_start = .;
    *(.sbss) *(.sbss.*) *(.bss) *(.bss.*) *(COMMON)
    . = ALIGN(16);
    __bss_end = .;
  } > ram

  . = ALIGN(16);
  __stack_bottom = .;
  . += __stack_size * __num_harts;
  __stack_top = .;

  . = ALIGN(0x1000);
  .text.rvmodel . :
  {
    *(.text.rvmodel) *(.text.rvmodel.*) *(.text) *(.text.*)
  } > ram

  ASSERT(. <= TEST_STATUS, "ACT ELF overlaps reserved test status word")
  .test_status TEST_STATUS : { KEEP(*(.test_status)) } > ram

  _end = .;
  ASSERT(_end <= ORIGIN(ram) + LENGTH(ram), "ACT ELF exceeds configured RAM")
}
