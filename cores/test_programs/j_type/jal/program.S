# Simple RV32I program using to test the JAL instruction
# Uses store instructions

.text
.global _start

_start:
    # Derive 64 KiB-aligned base from current PC and keep it in gp (x3)
    auipc x3, 0
    srli x3, x3, 16
    slli x3, x3, 16

    nop
    jal x1, target1           # Jump to target1, x1 = pc + 4 = 0x1014
    j loop

target2:
    sw x2, 0x08(x3)           # show we have been here and pc+4 was saved correctly
    j loop

test2:
    li x7, 42
    sw x7, 0x04(x3)           # show we have been here
    jal x2, target2           # Jump to target2, x2 = pc + 4 = 0x102c
    nop
    nop
    j loop

target1:
    sw x1, 0x00(x3)           # show we have been here and pc+4 was saved correctly
    j test2

loop:
    j loop
