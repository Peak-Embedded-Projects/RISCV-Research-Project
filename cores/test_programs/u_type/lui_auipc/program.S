# Simple RV32I program using I-type, U-type instructions to load values.
# Primarly verifies lui and auipc

.text
.global _start
_start:
    # Derive 64 KiB-aligned base from current PC and keep it in gp (x3)
    auipc x3, 0
    srli x3, x3, 16
    slli x3, x3, 16

    lw x5, 0(x3)            # x5 = mem[base + 0x0] = 0x00000001 | pc=0x0c
    lw x6, 4(x3)            # x6 = mem[base + 0x4] = 0x00000002 | pc=0x10
    lw x7, 8(x3)            # x7 = mem[base + 0x8] = 0x00000003 | pc=0x14
    auipc x8, 0x200         # x8 = 0x200000 + 0x1018 = 0x201018 | pc=0x18
    lui x9, 0x2f2fa         # x9 = 0x2f2fa000                   | pc=0x1c
    j loop
    
loop:
    j loop              # Jump to loop (keeps processor running)