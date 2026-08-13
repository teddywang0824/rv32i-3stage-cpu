.section .text.start
.globl _start

_start:
    # OP-IMM: signed/unsigned and shift-boundary values.
    addi   x1,  x0, -1
    slti   x2,  x1, 0
    sltiu  x3,  x1, 1
    xori   x4,  x1, -1
    ori    x5,  x0, 0x55
    andi   x6,  x5, 0x0f
    slli   x7,  x2, 31
    srli   x8,  x7, 31
    srai   x9,  x7, 31

    # OP: every RV32I register-register ALU instruction.
    add    x10, x2, x8
    sub    x11, x10, x2
    sll    x12, x2, x8
    slt    x13, x1, x2
    sltu   x14, x2, x1
    xor    x15, x5, x6
    srl    x16, x7, x8
    sra    x17, x7, x8
    or     x18, x5, x6
    and    x19, x5, x6

    # Upper immediates and all Load/Store widths.
    lui    x20, 0x12345
    auipc  x21, 0
    sw     x20, 0(x0)
    sh     x5,  4(x0)
    sb     x6,  6(x0)
    lw     x22, 0(x0)
    lh     x23, 4(x0)
    lhu    x24, 4(x0)
    lb     x25, 6(x0)
    lbu    x26, 6(x0)

    # All six branches are taken.  A PC+4 target is architecturally valid and
    # lets the testbench count redirects without adding wrong-path padding.
    beq    x2, x8, 1f
1:
    bne    x1, x2, 2f
2:
    blt    x1, x2, 3f
3:
    bge    x2, x1, 4f
4:
    bltu   x2, x1, 5f
5:
    bgeu   x1, x2, 6f
6:
    jal    x27, 7f
7:
    auipc  x29, 0
    addi   x29, x29, 12
    jalr   x28, x29, 0
8:
    fence

    # Golden completion signature.  ECALL is verified in tb_CPU_SYSTEM;
    # EBREAK terminates this directed architectural program through trap cause 3.
    addi   x30, x0, 40
    sw     x30, 8(x0)
    ebreak
