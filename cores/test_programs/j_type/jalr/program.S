# Simple RV32I program using to test the JALR instruction
# Uses store instructions and JAL

.text
.global _start

_start:
    # Derive 64 KiB-aligned base from current PC and keep it in gp (x3)
    auipc x3, 0
    srli x3, x3, 16
    slli x3, x3, 16

    nop
    jal    x1, target1        # Jump to target1, x1 = pc + 4 = 0x1014
    sw     x7, 0x04(x3)       # show that we jumped back to the correct spot
    li     x8, 7              # save special value
    jr     4(x2)              # JALR with offset

    nop
    nop
    j loop

target1:
    sw     x1, 0x00(x3)       # show we have been here and pc+4 was saved correctly
    li     x7, 42             # load special value that is saved after returning
    jalr   x2, x1             # return and save pc+4 in x2 (= 0x1038)

    # this instruction should be skipped due to offset
    addi   x8, x8, 100
    # jal with offset lands here 
    sw     x8, 0x08(x3)


loop:
    j loop
