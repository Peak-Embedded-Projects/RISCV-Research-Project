# Simple RV32I program using S-type and I-type instructions
# Executes load word instruction and then store instruction

.text
.global _start
_start:
    # Derive 64 KiB-aligned base from current PC and keep it in gp (x3)
    auipc x3, 0
    srli x3, x3, 16
    slli x3, x3, 16

    # Load words from memory into registers x6
    lw x6, 4(x3)           # x6 = mem[0x1004] = 0x00000008
    sw x6, 0xC(x3)          # take value from reg x6 and store it in the memory
                            # provided the address that is in x0 offset by 0xC
    # Infinite loop to prevent undefined behavior
loop:
    j loop              # Jump to loop (keeps processor running)