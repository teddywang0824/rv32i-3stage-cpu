#ifndef CPU_BUILD_RVMODEL_MACROS_H
#define CPU_BUILD_RVMODEL_MACROS_H

/*
 * CPU Build has no UART or privileged tohost mechanism.  The architectural
 * testbench observes a retired Store to this reserved word in DMEM:
 *   1 = pass
 *   3 = fail
 */
#define CPU_BUILD_TEST_STATUS 0x10000ff0

#define RVMODEL_DATA_SECTION                                      \
  .pushsection .test_status,"aw",@progbits;                       \
  .align 4;                                                       \
  .global tohost;                                                 \
  tohost: .word 0;                                                \
  .popsection;

/* No DUT-specific boot sequence is required. */
#define RVMODEL_BOOT

#define RVMODEL_HALT_PASS                                         \
  li x1, 1;                                                       \
  li x5, CPU_BUILD_TEST_STATUS;                                   \
  sw x1, 0(x5);                                                   \
1:                                                               \
  j 1b;

#define RVMODEL_HALT_FAIL                                         \
  li x1, 3;                                                       \
  li x5, CPU_BUILD_TEST_STATUS;                                   \
  sw x1, 0(x5);                                                   \
1:                                                               \
  j 1b;

/* This DUT has no console. */
#define RVMODEL_IO_INIT(_R1, _R2, _R3)
#define RVMODEL_IO_WRITE_STR(_R1, _R2, _R3, _STR_PTR)

#endif /* CPU_BUILD_RVMODEL_MACROS_H */
