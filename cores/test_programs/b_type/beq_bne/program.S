# Simple RV32I program using B-type, R-type, S-type and I-type instructions
# Executes load instructions, compares two loaded registers, if they are equal then executes addition
# and stores results in a memory. Loads the product of addition from the memory and compares if not equal,
# if so performs OR operation and stores this value again in the memory.

.text
.global _start
_start:
    # Load words from memory into registers x5, x6
    lw x5, 0(x10)           # x5 = mem[0x1000] = 0x00000003
    lw x6, 4(x10)           # x6 = mem[0x1004] = 0x00000003

    # Compare x5 and x6, branch if equal to perform addition
    beq x5, x6, do_add      # If x5 == x6, jump to do_add
    j loop                  # If not equal, skip to loop 

do_add:
    add x7, x5, x6          # x7 = x5 + x6 = 0x00000003 + 0x00000003 = 0x00000006
    sw x7, 0xC(x0)          # Store x7 to mem[0xC]

    # Load the result and compare with a constant from memory
    lw x8, 0xC(x0)          # x8 = mem[0xC] = 0x00000006
    lw x9, 8(x10)           # x9 = mem[0x1008] = 0x00000007 (constant for comparison)
    bne x8, x9, do_or       # If x8 != x9, jump to do_or
    j loop                  # If equal, skip to loop 

do_or:
    lw x10, 12(x10)         # x10 = mem[0x100C] = 0x00000006 (second operand for OR)
    or x11, x8, x10         # x11 = x8 | x10 = 0x00000006 | 0x00000006 = 0x00000006
    sw x11, 0xC(x0)         # Store x11 to mem[0xC], updating the memory

    # Infinite loop to prevent undefined behavior
loop:
    j loop                  # Jump to loop (keeps processor running)