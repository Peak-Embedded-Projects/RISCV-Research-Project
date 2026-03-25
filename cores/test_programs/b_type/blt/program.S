# Simple RV32I program demonstrating beq instruction
# Loads two values, compares them, branches if less than, and stores a result.

.text
.global _start
_start:
    # Derive 64 KiB-aligned base from current PC and keep it in gp (x3)
    auipc x3, 0
    srli x3, x3, 16
    slli x3, x3, 16

    lw x5, 0(x3)           # x5 = mem[0x1000] = 0x00000008
    lw x6, 4(x3)           # x6 = mem[0x1004] = 0x00000005
    blt x6, x5, less_than  # If x6 < x5, jump to less_than
    j loop                 # If not less than, skip to loop
less_than:
    addi x7, x5, 0x2       # x7 = 0x0000000A
    sw x7, 0xC(x3)         # Store x7 to mem[0xC]
loop:
    j loop                  # Jump to loop