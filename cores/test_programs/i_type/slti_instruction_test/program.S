# Simple RV32I program using ALU I-type, S-type and I-type instructions
# Executes load, slti and store instructions.

.text
.global _start
_start:
    # Load words from memory into registers x5, x6
    lw x5, 0(x10)           # x5 = mem[0x0000] = 0x00000005
    slti x6, x5, 0x7FF      # if x5<0xFFF then x6=1, otherwise x6=0
    slti x7, x5, 0xC        # if x5<0xC then x7=1, otherwise x7=0
    sw x6, 0xC(x0)
    sw x7, 0xA(x0)
    j loop

loop:
    j loop              # Jump to loop (keeps processor running)