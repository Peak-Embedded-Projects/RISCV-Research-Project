# Simple RV32I program demonstrating beq instruction
# Loads two values, compares them, branches if equal, and stores a result.

.text
.global _start
_start:
    # Derive 64 KiB-aligned base from current PC and keep it in gp (x3)
    auipc x3, 0
    srli x3, x3, 16
    slli x3, x3, 16

    lw x5, 0(x3)           # x5 = mem[0x1000] = 0x00000003
    lw x6, 4(x3)           # x6 = mem[0x1004] = 0x00000003
    beq x5, x6, equal       # If x5 == x6, jump to equal
    j loop                  # If not equal, skip to loop
equal:
    lw x7, 8(x3)           # x5 = mem[0x1008] = 0x00000005
    sw x7, 0xC(x3)          # Store x7 to mem[0xC]
loop:
    j loop                  # Jump to loop