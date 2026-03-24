# Simple RV32I program demonstrating bne instruction
# Loads two values, compares them, branches if equal, and stores a result.

.text
.global _start
_start:
    lw x5, 0(x11)           # x5 = mem[0x1000] = 0x00000001
    lw x6, 4(x11)           # x6 = mem[0x1004] = 0x00000003
    bne x5, x6, equal       # If x5 == x6, jump to equal
    j loop                  # If not equal, skip to loop
equal:
    lw x7, 8(x11)           # x5 = mem[0x1008] = 0x00000005
    sw x7, 0xC(x0)          # Store x7 to mem[0xC]
loop:
    j loop                  # Jump to loop