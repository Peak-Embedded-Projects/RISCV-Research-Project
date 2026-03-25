# Simple RV32I program using slt instruction.

.text
.global _start
_start:
    # Derive 64 KiB-aligned base from current PC and keep it in gp (x3)
    auipc x3, 0
    srli x3, x3, 16
    slli x3, x3, 16

    
    addi x5, x0, 0x8 # x5 = 0x00000008
    addi x6, x0, 0xA # x6 = 0x0000000A

    slt x7, x5, x6   # x7 = 0x00000001 (x5 < x6)

    j loop

loop:
    j loop              # Jump to loop (keeps processor running)