def load_hex_to_mem(file_path):
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
