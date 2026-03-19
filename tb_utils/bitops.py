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
