# Simple RV32I program using I-type instruction
# Executes multiple load word instructions on different registers

.text
.global _start
_start:
    # Derive 64 KiB-aligned base from current PC and keep it in gp (x3)
    auipc x3, 0
    srli x3, x3, 16
    slli x3, x3, 16

    # Load words from memory into registers x5, x6, x7, x8
    lw x5, 0(x3)           # x5 = mem[0x1000] = 0x00000001
    lw x6, 4(x3)           # x6 = mem[0x1004] = 0x00000002
    lw x7, 8(x3)           # x7 = mem[0x1008] = 0x00000003
    lw x8, 12(x3)          # x8 = mem[0x100C] = 0x00000004
    # Infinite loop to prevent undefined behavior
loop:
    j loop              # Jump to loop (keeps processor running)