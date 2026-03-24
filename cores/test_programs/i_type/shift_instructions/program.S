# Simple RV32I program using I-type instructions
# Executes sll, sri, slli, srli and sra, srai instructions.

.text
.global _start
_start:
    # Load words from memory into registers x5, x6
    lw x5, 0(x10)           # x5 = mem[0x0000] = 0x0000002A
    lw x6, 4(x10)           # x6 = mem[0x0004] = 0x00000002
    lw x7, 8(x10)           # x7 = mem[0x0008] = 0xFFFFFFD6

    sll x8, x5, x6          # x8 = 0x000000A8 | op= 011 0011    
    slli x9, x5, 2          # x9 = 0x000000A8 | op= 001 0011

    srl x10, x7, x6         # x10 = 0x3FFFFFF5| op= 011 0011
    srli x11, x7, 2         # x11 = 0x3FFFFFF5| op= 001 0011

    sra x12, x7, x6         # x12 = 0xFFFFFFF5| op= 011 0011
    srai x13, x7, 2         # x13 = 0xFFFFFFF5| op= 001 0011

    j loop

loop:
    j loop              # Jump to loop (keeps processor running)
