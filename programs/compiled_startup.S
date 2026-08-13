    .option norvc
    .option norelax

    .section .text.init
    .globl rvtest_entry_point
    .type rvtest_entry_point, @function
rvtest_entry_point:
    la      sp, __stack_top

    # Freestanding C startup: clear the complete .bss range.
    la      t0, __bss_start
    la      t1, __bss_end
1:
    bgeu    t0, t1, 2f
    sw      zero, 0(t0)
    addi    t0, t0, 4
    jal     zero, 1b

2:
    call    main
    li      t0, 0x01fffff0
    beq     a0, zero, 3f
    li      t1, 3
    sw      t1, 0(t0)
    jal     zero, 4f
3:
    li      t1, 1
    sw      t1, 0(t0)
4:
    jal     zero, 4b

    .size rvtest_entry_point, .-rvtest_entry_point

    .section .test_status,"aw",@progbits
    .balign 4
    .globl tohost
tohost:
    .word 0
