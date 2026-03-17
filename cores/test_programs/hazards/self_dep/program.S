# Simple RV32I program using I-type instructions
# It aims to trigger self dependency hazard

.text
.global _start
_start:
    # Load words from memory into registers x5, x6
    lw x10, 12(x0)
    lw x10, 24(x10)
    
loop:
    j loop              # Jump to loop (keeps processor running)