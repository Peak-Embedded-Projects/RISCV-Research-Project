from typing import List

from tb_utils.constants import SUB_SEL_REGFILE


def load_hex_to_mem(file_path: str) -> List[str]:
    """
    Reads a standard Verilog hex file and returns a list of integers
    """

    memory_array = []
    with open(file_path, "r") as f:
        for line in f:
            clean_line = line.split("//")[0].strip()
            if clean_line:
                memory_array.append(int(clean_line, 16))
    return memory_array


def read_program_from_file(file_path: str) -> List[bytes]:
    """
    Read assembled program from *.hex file
    """

    program = []
    with open(file_path, "r") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            instruction = int(line, 16)
            instruction_bytes = instruction.to_bytes(4, byteorder="little")
            program.append(instruction_bytes)

    return program


def read_expected_values_from_file(file_path: str) -> List[int]:
    """
    Read expected register/memory values from a file
    """

    values = []
    with open(file_path, "r") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            values.append(int(line, 16))

    return values


def get_reg_addr(reg: int) -> int:
    """
    Calculate 16-bit AXI address for a specific register
    """

    return SUB_SEL_REGFILE | (reg << 2)
