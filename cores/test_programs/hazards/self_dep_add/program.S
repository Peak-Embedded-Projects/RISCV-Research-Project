# Simple RV32I program using R-type and I-type instructions
# It aims to trigger self dependency hazard

.text
.global _start
_start:
    # Derive 64 KiB-aligned base from current PC and keep it in gp (x3)
    auipc x3, 0
    srli x3, x3, 16
    slli x3, x3, 16

    # Load words from memory into registers x5, x6
    lw x10, 12(x3)
    lw x11, 4(x3)
    add x11, x11, x10
    
loop:
    j loop              # Jump to loop (keeps processor running)