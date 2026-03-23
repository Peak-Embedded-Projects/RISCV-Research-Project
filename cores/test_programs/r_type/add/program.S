# Simple RV32I program using R-type, S-type and I-type instructions
# Executes load instructions, then adds (primary test) and stores the results to main memory

.text
.global _start
_start:
    # Load words from memory into registers x5, x6
    lw x5, 0(x10)           # x5 = mem[0x1000] = 0x00000001
    lw x6, 4(x10)           # x6 = mem[0x1004] = 0x00000002
    add x20, x5, x6         # add values of x5 and x6 and save results to x20
    sw x20, 0xC(x0)         # take value from reg x20 and store it in the memory
                            # provided the address that is in x0 offset by 0xC
    # Infinite loop to prevent undefined behavior
loop:
    j loop              # Jump to loop (keeps processor running)