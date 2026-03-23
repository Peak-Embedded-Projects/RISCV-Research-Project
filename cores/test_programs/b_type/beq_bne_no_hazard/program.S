.text
.global _start
_start:
    # Load words from memory into registers x5, x6 using x11 as base address pointer
    lw x5, 0(x11)           # x5 = mem[0x0] = 0x00000003
    lw x6, 4(x11)           # x6 = mem[0x4] = 0x00000003

    # Compare x5 and x6, branch if equal to perform addition
    beq x5, x6, do_add      # If x5 == x6, jump to do_add
    j loop                  # If not equal, skip to loop

do_add:
    add x7, x5, x6          # x7 = x5 + x6 = 0x00000003 + 0x00000003 = 0x00000006
    sw x7, 0xC(x0)          # Store x7 to mem[0xC]

    # Load the result and compare with a constant from memory
    lw x8, 0xC(x0)          # x8 = mem[0xC] = 0x00000006
    lw x9, 8(x11)           # x9 = mem[0x8] = 0x00000007 (constant for comparison)
    bne x8, x9, do_or       # If x8 != x9, jump to do_or
    j loop                  # If equal, skip to loop

do_or:
    lw x10, 0xC(x11)         # x10 = mem[0xC] = 0x00000006 (second operand for OR, using x11 as base)
    add x0, x0, x0          # acts as NOP
    add x0, x0, x0          # acts as NOP
    or x12, x8, x10         # x12 = x8 | x10 = 0x00000006 | 0x00000006 = 0x00000006 (use x12 to avoid conflict)
    sw x12, 0xC(x0)         # Store x12 to mem[0xC], updating the memory

    # Infinite loop to prevent undefined behavior
loop:
    j loop                  # Jump to loop 