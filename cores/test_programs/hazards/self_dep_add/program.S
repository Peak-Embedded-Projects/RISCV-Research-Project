# Simple RV32I program using R-type and I-type instructions
# It aims to trigger self dependency hazard

.text
.global _start
_start:
    # Load words from memory into registers x5, x6
    lw x10, 12(x0)
    lw x11, 4(x0)
    add x11, x11, x10
    
loop:
    j loop              # Jump to loop (keeps processor running)