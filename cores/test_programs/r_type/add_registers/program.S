# Simple RV32I program using R-type instruction
# Adds two numbers (5 and 6) and stores result in x4

.text
.global _start
_start:
    # Derive 64 KiB-aligned base from current PC and keep it in gp (x3)
    auipc x3, 0
    srli x3, x3, 16
    slli x3, x3, 16

    # Initialize registers with values
    addi x1, x0, 5      # x1 = 0 + 5
    addi x2, x0, 6      # x2 = 0 + 6

    # R-type instruction: ADD
    add x4, x1, x2      # x4 = x1 + x2 (5 + 6 = 11)

    # Infinite loop to prevent undefined behavior
loop:
    j loop              # Jump to loop (keeps processor running)
