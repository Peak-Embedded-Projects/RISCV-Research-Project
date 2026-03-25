# Simple RV32I program using I-type instructions
# Executes sll, slr and sra instructions.

.text
.global _start
_start:
    # Derive 64 KiB-aligned base from current PC and keep it in gp (x3)
    auipc x3, 0
    srli x3, x3, 16
    slli x3, x3, 16

    # Load words from memory into registers x5, x6
    lw x5, 0(x3)           # x5 = mem[0x0000] = 0x0000002A
    lw x6, 4(x3)           # x6 = mem[0x0004] = 0x00000002
    lw x9, 8(x3)           # X9 = mem[0x0008] = 0xFFFFFFD6

    sll x7, x5, x6          # x7 = 0x000000A8
    srl x8, x5, x6          # x8 = 0x0000000A
    sra x10, x9, x6         # x10 = 0xFFFFFFF5

    j loop

loop:
    j loop              # Jump to loop (keeps processor running)