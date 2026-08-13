.section .text.start
.globl _start

_start:
    lw     x1, 0(x0)
    lw     x2, 4(x0)
    add    x3, x1, x2
    sw     x3, 8(x0)
    ebreak

.section .data
.align 2

values:
    .word 5
    .word 7
    .word 0