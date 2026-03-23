# RISC-V program to test xori, ori, andi instructions using only registers.

.text
.global _start

_start:
    # Initialize registers with test values
    lw x5, 0(x0)    # x5 = 0x0000000A (10 in decimal)
    lw x6, 4(x0)    # x6 = 0x00000005 (5 in decimal)

    # Test xori (XOR with immediate)
    xori x7, x5, 0x00F   # x7 = x5 ^ 0x00F (0xA ^ 0xF = 0x5)

    # Test ori (OR with immediate)
    ori x8, x5, 0x030    # x8 = x5 | 0x030 (0xA | 0x30 = 0x3A)

    # Test andi (AND with immediate)
    andi x9, x6, 0x00C   # x9 = x6 & 0x00C (0x5 & 0xC = 0x4)

    j loop

loop:
    j loop               # Infinite loop to keep processor running