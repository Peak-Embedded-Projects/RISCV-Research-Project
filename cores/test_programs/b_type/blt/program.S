# Simple RV32I program demonstrating beq instruction
# Loads two values, compares them, branches if less than, and stores a result.

.text
.global _start
_start:
    lw x5, 0(x0)           # x5 = mem[0x1000] = 0x00000008
    lw x6, 4(x0)           # x6 = mem[0x1004] = 0x00000005
    blt x6, x5, less_than  # If x6 < x5, jump to less_than
    j loop                 # If not less than, skip to loop
less_than:
    addi x7, x5, 0x2       # x7 = 0x0000000A
    sw x7, 0xC(x0)         # Store x7 to mem[0xC]
loop:
    j loop                  # Jump to loop