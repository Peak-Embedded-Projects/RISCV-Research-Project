# RV32I program to test lb, lbu, lh, and lhu instructions
# Preloads D_MEM with 0x87654321 at byte address 0x0 for signed/unsigned testing
# Loads the full word, then performs partial loads at various offsets
# Stores results to memory starting at 0x4 for verification

.text
.global _start

_start:
    # Derive 64 KiB-aligned base from current PC and keep it in gp (x3)
    auipc x3, 0
    srli x3, x3, 16
    slli x3, x3, 16

    # Load test word from D_MEM
    lw x5, 0(x3)         # Load 0x87654321 from mem[0] (byte address 0x0)

    # Test lb (signed byte load) at different byte offsets
    lb x6, 0(x3)         # Load byte from mem[0x0] (0x21, signed: 0x00000021)
    lb x7, 1(x3)         # Load byte from mem[0x1] (0x43, signed: 0x00000043)
    lb x8, 2(x3)         # Load byte from mem[0x2] (0x65, signed: 0x00000065)
    lb x9, 3(x3)         # Load byte from mem[0x3] (0x87, signed: 0xFFFFFF87, negative)

    # Test lbu (unsigned byte load) at different byte offsets
    lbu x10, 0(x3)       # Load byte from mem[0x0] (0x21, unsigned: 0x00000021)
    lbu x11, 1(x3)       # Load byte from mem[0x1] (0x43, unsigned: 0x00000043)
    lbu x12, 2(x3)       # Load byte from mem[0x2] (0x65, unsigned: 0x00000065)
    lbu x13, 3(x3)       # Load byte from mem[0x3] (0x87, unsigned: 0x00000087)

    # Test lh (signed half-word load) at different half-word offsets
    lh x14, 0(x3)        # Load half-word from mem[0x0:0x1] (0x4321, signed: 0x00004321)
    lh x15, 2(x3)        # Load half-word from mem[0x2:0x3] (0x8765, signed: 0xFFFF8765, negative)

    # Test lhu (unsigned half-word load) at different half-word offsets
    lhu x16, 0(x3)       # Load half-word from mem[0x0:0x1] (0x4321, unsigned: 0x00004321)
    lhu x17, 2(x3)       # Load half-word from mem[0x2:0x3] (0x8765, unsigned: 0x00008765)

    # Store results to memory for testbench verification
    sw x5, 4(x3)         # Store original word 0x87654321 to mem[1] (byte address 0x4)
    sw x6, 8(x3)         # Store lb at 0x0 (0x00000021) to mem[2] (0x8)
    sw x7, 12(x3)        # Store lb at 0x1 (0x00000043) to mem[3] (0xC)
    sw x8, 16(x3)        # Store lb at 0x2 (0x00000065) to mem[4] (0x10)
    sw x9, 20(x3)        # Store lb at 0x3 (0xFFFFFF87) to mem[5] (0x14)
    sw x10, 24(x3)       # Store lbu at 0x0 (0x00000021) to mem[6] (0x18)
    sw x11, 28(x3)       # Store lbu at 0x1 (0x00000043) to mem[7] (0x1C)
    sw x12, 32(x3)       # Store lbu at 0x2 (0x00000065) to mem[8] (0x20)
    sw x13, 36(x3)       # Store lbu at 0x3 (0x00000087) to mem[9] (0x24)
    sw x14, 40(x3)       # Store lh at 0x0 (0x00004321) to mem[10] (0x28)
    sw x15, 44(x3)       # Store lh at 0x2 (0xFFFF8765) to mem[11] (0x2C)
    sw x16, 48(x3)       # Store lhu at 0x0 (0x00004321) to mem[12] (0x30)
    sw x17, 52(x3)       # Store lhu at 0x2 (0x00008765) to mem[13] (0x34)

loop:
    j loop             # Infinite loop to halt