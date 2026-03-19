def get_alu_ctrl(is_branch: int, modifier: int, funct3: int) -> int:
    """
    Mirrors the Verilog concatenation: {is_branch, modifier, funct3}
    """

    return (is_branch << 4) | (modifier << 3) | funct3


def to_32b(val: int) -> int:
    """
    Helper to cleanly mask negative numbers to 32-bit unsigned integers
    """

    return val & 0xFFFFFFFF


def build_rtype(funct7, rs2, rs1, funct3, rd, opcode):
    """
    Create R-Type instruction
    """

    return (
        (funct7 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode
    )


def build_itype(imm, rs1, funct3, rd, opcode):
    """
    Create I-Type instruction
    """

    return ((imm & 0xFFF) << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode


def build_stype(imm, rs2, rs1, funct3, opcode):
    """
    Create S-Type instruction
    """

    imm_11_5 = (imm >> 5) & 0x7F
    imm_4_0 = imm & 0x1F
    return (
        (imm_11_5 << 25)
        | (rs2 << 20)
        | (rs1 << 15)
        | (funct3 << 12)
        | (imm_4_0 << 7)
        | opcode
    )


def build_btype(imm, rs2, rs1, funct3, opcode):
    """
    Create B-Type instruction
    """

    imm_12 = (imm >> 12) & 0x1
    imm_11 = (imm >> 11) & 0x1
    imm_10_5 = (imm >> 5) & 0x3F
    imm_4_1 = (imm >> 1) & 0xF
    return (
        (imm_12 << 31)
        | (imm_10_5 << 25)
        | (rs2 << 20)
        | (rs1 << 15)
        | (funct3 << 12)
        | (imm_4_1 << 8)
        | (imm_11 << 7)
        | opcode
    )


def build_utype(imm, rd, opcode):
    """
    Create U-Type instruction
    """

    return (imm & 0xFFFFF000) | (rd << 7) | opcode


def build_jtype(imm, rd, opcode):
    """
    Create J-Type instruction
    """

    imm_20 = (imm >> 20) & 0x1
    imm_19_12 = (imm >> 12) & 0xFF
    imm_11 = (imm >> 11) & 0x1
    imm_10_1 = (imm >> 1) & 0x3FF
    return (
        (imm_20 << 31)
        | (imm_10_1 << 21)
        | (imm_11 << 20)
        | (imm_19_12 << 12)
        | (rd << 7)
        | opcode
    )
