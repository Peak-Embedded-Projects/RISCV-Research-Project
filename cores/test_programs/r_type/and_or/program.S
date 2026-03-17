# Simple RV32I program using R-type, S-type and I-type instructions
# Executes load instructions, then bit-wise AND & OR and then stores the results to main memory

.text
.global _start
_start:
    # Load words from memory into registers x5, x6
    lw x5, 0(x10)           # x5 = mem[0x1000] = 0x00000003
    lw x6, 4(x10)           # x6 = mem[0x1004] = 0x00000001
    and x7, x5, x6          # bit-wise AND between register x5 and x6
    or x8, x5, x6           # bit-wise OR between registers x5 and x6
    and x9, x8, x7          # bit-wise AND between registers x7 and x8
    # Infinite loop to prevent undefined behavior
loop:
    j loop              # Jump to loop (keeps processor running)