# Simple RV32I program using I-type, U-type instructions to load values.
# Primarly verifies lui and auipc

.text
.global _start
_start:
    lw x5, 0(x10)           # x5 = mem[0x1000] = 0x00000001   | pc=0x00
    lw x6, 4(x10)           # x6 = mem[0x1004] = 0x00000002   | pc=0x04
    lw x7, 8(x10)           # x6 = mem[0x1004] = 0x00000003   | pc=0x08
    auipc x8, 0x200         # x8 = 0x200000 + 0x0c = 0x20000c | pc=0x0c
    lui x9, 0x2f2fa         # x9 = 0x2f2fa000                 | pc=0x10
    j loop
    
loop:
    j loop              # Jump to loop (keeps processor running)