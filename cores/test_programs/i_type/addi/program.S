# Simple RV32I program using ALU I-type, S-type and I-type instructions
# Executes addi and a regular load, then branch equal condition and save to memory.

.text
.global _start
_start:
    # Derive 64 KiB-aligned base from current PC and keep it in gp (x3)
    auipc x3, 0
    srli x3, x3, 16
    slli x3, x3, 16

    # Load words from memory into registers x5, x6
    lw x5, 0(x3)           # x5 = mem[0x0000] = 0x00000005
    addi x6, x5, 0x01       # x6 = x5 + 0x01 = 0x00000006
    addi x7, x7, 0x06       # x7 = x7(0x00) + 0x06 = 0x00000006
    beq x6, x7, if_equal
    j loop

if_equal:
    sub x7, x7, x5          # x7 = x7 - x5 = 0x00000001
    sw x7, 0xC(x3)          # Store x7 to mem[0xC]

loop:
    j loop              # Jump to loop (keeps processor running)