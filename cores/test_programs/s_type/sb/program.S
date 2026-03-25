# RV32I program to test sb instruction
# Stores bytes at various addresses to verify byte-addressable BRAM

.text
.global _start

_start:
    # Derive 64 KiB-aligned base from current PC and keep it in gp (x3)
    auipc x3, 0
    srli x3, x3, 16
    slli x3, x3, 16

    # Initialize registers with test values
    addi x5, x0, 0xAB    # x5 = 0xAB (test byte value)
    addi x6, x0, 0xCD    # x6 = 0xCD (another test byte value)
    addi x7, x0, 0xEF    # x7 = 0xEF (marker value)

    # Test sb at different byte offsets
    sb x5, 0(x3)         # Store 0xAB to mem[0] (byte 0 of word 0)
    sb x6, 1(x3)         # Store 0xCD to mem[1] (byte 1 of word 0)
    sb x5, 5(x3)         # Store 0xAB to mem[5] (byte 1 of word 1)
    sb x7, 8(x3)         # Store 0xEF to mem[8] (byte 0 of word 2)

    # Store marker to verify program completion
    sw x7, 12(x3)        # Store 0xEF (full word) to mem[12] for verification

loop:
    j loop               # Infinite loop to halt