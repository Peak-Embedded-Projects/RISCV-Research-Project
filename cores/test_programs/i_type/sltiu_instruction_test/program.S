# Simple RV32I program using ALU I-type, S-type and I-type instructions
# Executes load, sltiu and store instructions.

.text
.global _start

_start:
    # Load word from memory into register x5
    lw x5, 0(x10)           # x5 = mem[0x0000] = 0x00000005
    sltiu x6, x5, 0x8       # x5 (5) < 0x8 (8), x6 = 1 (unsigned, 8 as signed))
    sltiu x7, x5, 0x6       # x5 (5) < 0x6 (6), x7 = 1 (unsigned, 6 as signed)
    sltiu x8, x5, 0xFE      # x5 (5) < 0xFE (254), x8 = 1 (unsigned, 254 as signed)
    sw x6, 0xC(x0)          # store x6 to mem[0xC]
    sw x7, 0x8(x0)          # store x7 to mem[0x8]
    sw x8, 0x4(x0)          # store x8 to mem[0x4]
    j loop

loop:
    j loop                  # Jump to loop (keeps processor running)