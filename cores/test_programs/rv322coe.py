# -----------------------------------------------------------------------
# Author: Szymon Bogus
# Date:   I don't remember
#
# Description:
# Script used to assembly and then translate into HEX RISC-V assembly 
# programs.
# License: GNU GPL
# -----------------------------------------------------------------------
import subprocess
import argparse
from pathlib import Path


def execute(args) -> None:
    if args.verbosity:
        print("Verbose output ON")
    
    file = Path(args.file)
    if not file.is_file():
        raise FileNotFoundError("Couldn't find file: {}".format(file))
    elif args.verbosity:
        print("Located file: {}".format(file))
        
    file_o = file.with_suffix(".o")
    file_elf = file.with_suffix(".elf")
    file_tmp_hex = file.with_suffix(".tmp_hex")
    file_coe = file.with_suffix(".coe")
    file_hex = file.with_suffix(".hex")
    
    if args.verbosity:
        print("Creating:\n{}\n{}\n{}".format(file_o, file_elf, file_tmp_hex))
        
    make_o = "riscv64-unknown-elf-as -march=rv32i -mabi=ilp32 -o " + str(file_o) + " " + args.file
    make_elf = "riscv64-unknown-elf-ld -march=rv32i -melf32lriscv -Ttext=0x0 -o " + str(file_elf) + " " + str(file_o)
    make_hex = "riscv64-unknown-elf-objcopy -O verilog " + str(file_elf) + " " + str(file_tmp_hex)
    commands = (make_o, make_elf, make_hex)
    
    for command in commands:
        try:
            if args.verbosity:
                print("Executing: {}".format(command))
            subprocess.run(command, shell=True, check=True)
        except subprocess.CalledProcessError as cpe:
            raise RuntimeError("Couldn't run: {}, command returned: {}".format(command, cpe))
    
    # Convert .hex to .coe
    try:
        with open(file_tmp_hex, 'r') as hex_file, open(file_coe, 'w') as coe_file, open(file_hex, 'w') as new_hex_file:
            coe_file.write("memory_initialization_radix=16;\nmemory_initialization_vector=\n")
            instruction_count = 0
            for line in hex_file:
                line = line.strip()
                if not line.startswith('@'):
                    # Split into bytes (little-endian)
                    bytes = line.split()
                    # Process groups of 4 bytes (each instruction)
                    for i in range(0, len(bytes), 4):
                        if i + 3 < len(bytes):  # Ensure 4 bytes for an instruction
                            # Reorder to big-endian (e.g., 93 00 50 00 -> 00500093)
                            word = f"{bytes[i+3]}{bytes[i+2]}{bytes[i+1]}{bytes[i]}"
                            coe_file.write(f"{word},\n")
                            new_hex_file.write(f"{word}\n")
                            instruction_count += 1
            

            if instruction_count > 0:
                coe_file.seek(coe_file.tell() - 2) 
                coe_file.write(";")
            else:
                raise RuntimeError("No valid instructions found in .hex file")
    
    except IOError as e:
        raise RuntimeError("Failed to convert .hex to .coe: {}".format(e))
    
    if not file_coe.is_file():
        raise FileNotFoundError(".coe file not created: {}".format(file_coe))
    
    if file_coe.stat().st_size < 50:  
        raise RuntimeError(".coe file is empty or nearly empty: {}".format(file_coe))
    
    if args.verbosity:
        print("Successfully created {} with {} instructions".format(file_coe, instruction_count))
    
    # Remove intermediate files
    for f in (file_o, file_elf, file_tmp_hex, file_coe):
        if f.exists():
            f.unlink()
    

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    
    parser.add_argument("--file", type=str, help="Path to the *.S file", required=True)
    parser.add_argument("--verbosity", type=bool, default=False, choices=[True, False], help="Verbose output")
    
    args = parser.parse_args()
    execute(args)
    