  .section .vectors, "ax"
  .option norvc
  j trap_handler
  .org 0x80

  .globl _start
_start:
  li   t0, 7
  li   t1, 5
  add  t2, t0, t1
  li   t3, 12
  bne  t2, t3, test_fail

  mul  t2, t0, t1
  li   t3, 35
  bne  t2, t3, test_fail

  li   t4, 0x80001000
  sw   t2, 0(t4)
  lw   t5, 0(t4)
  bne  t2, t5, test_fail

  .option rvc
  c.addi t5, 1
  addi t2, t2, 1
  bne  t2, t5, test_fail

test_pass:
  li   t0, 0x8ffffff8
  li   t1, 0x00000001
  sw   t1, 0(t0)
1:
  j 1b

test_fail:
trap_handler:
  li   t0, 0x8ffffff8
  li   t1, 0x00000101
  sw   t1, 0(t0)
2:
  j 2b

