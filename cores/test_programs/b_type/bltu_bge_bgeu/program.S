# Simple RV32I program demonstrating B-type: bltu, bge, bgeu instructions.

.text
.global _start
_start:
    addi x5, x0, 5          # x5 = 5 (positive)
    addi x6, x0, -1         # x6 = -1 (0xFFFFFFFF unsigned large)
    bltu x5, x6, bltu_taken # If x5 <u x6 (5 <u 0xFFFFFFFF), jump to bltu_taken
    j after_bltu            # If not, skip
bltu_taken:
    addi x7, x5, 3          # x7 = 5 + 3 = 0x00000008 (indicate taken)
    sw x7, 0(x0)            # Store x7 to mem[0]
after_bltu:
    bge x5, x6, bge_taken   # If x5 >= x6 (5 >= -1 signed), jump to bge_taken
    j after_bge             # If not, skip
bge_taken:
    addi x8, x5, 5          # x8 = 5 + 5 = 0x0000000A (indicate taken)
    sw x8, 4(x0)            # Store x8 to mem[4]
after_bge:
    bgeu x6, x5, bgeu_taken # If x6 >=u x5 (0xFFFFFFFF >=u 5 unsigned), jump to bgeu_taken
    j after_bgeu            # If not, skip
bgeu_taken:
    addi x9, x5, 7          # x9 = 5 + 7 = 0x0000000C (indicate taken)
    sw x9, 8(x0)            # Store x9 to mem[8]
after_bgeu:
    j loop                  # Infinite loop
loop:
    j loop                  # Jump to loop
