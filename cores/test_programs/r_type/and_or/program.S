# Simple RV32I program using R-type, S-type and I-type instructions
# Executes load instructions, then bit-wise AND & OR and then stores the results to main memory

.text
.global _start
_start:
    # Derive 64 KiB-aligned base from current PC and keep it in gp (x3)
    auipc x3, 0
    srli x3, x3, 16
    slli x3, x3, 16

    # Load words from memory into registers x5, x6
    lw x5, 0(x3)           # x5 = mem[0x1000] = 0x00000003
    lw x6, 4(x3)           # x6 = mem[0x1004] = 0x00000001
    and x7, x5, x6          # bit-wise AND between register x5 and x6
    or x8, x5, x6           # bit-wise OR between registers x5 and x6
    and x9, x8, x7          # bit-wise AND between registers x7 and x8
    # Infinite loop to prevent undefined behavior
loop:
    j loop              # Jump to loop (keeps processor running)