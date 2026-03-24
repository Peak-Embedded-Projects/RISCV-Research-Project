# RV32I program to test sh instruction
# Stores half-words at various addresses to verify byte-addressable BRAM

.text
.global _start

_start:
    # Initialize registers with test values
    lw x5, 0(x0)          # Load 0x0000ABCD from mem[256] (byte address 0x100)
    lw x6, 4(x0)          # Load 0x00001234 from mem[260] (byte address 0x104)
    lw x7, 8(x0)          # Load 0x0000EF01 from mem[264] (byte address 0x108)

    # Test sh at different half-word-aligned addresses
    sh x5, 16(x0)         # Store 0xABCD to mem[16:17] (bytes 0x10-0x11)
    sh x6, 18(x0)         # Store 0x1234 to mem[18:19] (bytes 0x12-0x13)
    sh x5, 20(x0)         # Store 0xABCD to mem[20:21] (bytes 0x14-0x15)
    sh x7, 24(x0)         # Store 0xEF01 to mem[24:25] (bytes 0x18-0x19)

    # Store marker to verify program completion
    sw x7, 28(x0)         # Store 0x0000EF01 (full word) to mem[28:31] (byte address 0x1C)

loop:
    j loop               # Infinite loop to halt
