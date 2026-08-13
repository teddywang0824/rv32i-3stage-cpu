#ifndef CPU_BUILD_RVMODEL_MACROS_H
#define CPU_BUILD_RVMODEL_MACROS_H

/*
 * CPU Build has no UART or privileged tohost mechanism.  The architectural
 * testbench observes a retired Store to this reserved word in DMEM:
 *   1 = pass
 *   3 = fail
 */
#define CPU_BUILD_TEST_STATUS 0x01fffff0

#define RVMODEL_DATA_SECTION                                      \
  .pushsection .test_status,"aw",@progbits;                       \
  .balign 4;                                                      \
  .global tohost;                                                 \
  tohost: .word 0;                                                \
  .popsection;

/* No DUT-specific boot sequence is required. */
#define RVMODEL_BOOT

/* The RTL has no privileged CSRs; bypass ACT's default M-mode CSR setup. */
#define RVMODEL_BOOT_TO_MMODE

#define RVMODEL_HALT_PASS                                         \
  li x1, 1;                                                       \
  li x5, CPU_BUILD_TEST_STATUS;                                   \
  sw x1, 0(x5);                                                   \
1: j 1b;

#define RVMODEL_HALT_FAIL                                         \
  li x1, 3;                                                       \
  li x5, CPU_BUILD_TEST_STATUS;                                   \
  sw x1, 0(x5);                                                   \
1: j 1b;

/* This DUT has no console. */
#define RVMODEL_IO_INIT(_R1, _R2, _R3)
#define RVMODEL_IO_WRITE_STR(_R1, _R2, _R3, _STR_PTR)

/* Interrupt suites are excluded, but ACT's self-checking epilogue requires
 * every platform hook to exist.  Empty hooks accurately describe this DUT. */
#define RVMODEL_INTERRUPT_LATENCY 0
#define RVMODEL_TIMER_INT_SOON_DELAY 0
#define RVMODEL_SET_MEXT_INT(_R1, _R2)
#define RVMODEL_CLR_MEXT_INT(_R1, _R2)
#define RVMODEL_SET_MSW_INT(_R1, _R2)
#define RVMODEL_CLR_MSW_INT(_R1, _R2)
#define RVMODEL_SET_SEXT_INT(_R1, _R2)
#define RVMODEL_CLR_SEXT_INT(_R1, _R2)
#define RVMODEL_SET_SSW_INT(_R1, _R2)
#define RVMODEL_CLR_SSW_INT(_R1, _R2)

#endif /* CPU_BUILD_RVMODEL_MACROS_H */
