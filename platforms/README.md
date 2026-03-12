# Platforms
This directory contains various targets to build the whole system for. This could be both harware platforms as well as simulation.

Due to close-source nature of build tools for different FPGA vendors the implementation of necessary synthesis and implementation scripts and source files are stored in a directory related to a particular vendor. The python `build.py` script from the root direcotry uses scripts from the selected vendor directory to instantiate the design in conjunction with fetched IP Core from `cores/`.

So far only Xilinx platforms are supported.

## Xilinx
This directory contains neccessary scripts and source files exclusive to Xilinx in order to deply the functioning framework on the physical board.

Scripts from `scripts/` are a combination of TCL and python:

- `xiilinx/scripts/package_riscv_ip.tcl`: creats RISC-V IP Core from a selected implementation from `cores/`
- `xiilinx/scripts/build_riscv_worker_pl.tcl/`: instantiates the block diagram project (BD) of the framework with a selected IP Core: performs synthesis and implementation steps, outputs `xsa` file
- `xiilinx/scripts/build_riscv_worker_ps_pl.py`: creates Vitis project in order to deploy both Porgrammable Logic (PL) and Processing System (PS) layers on the target
- `xilinx/riscv_build_utils.py`: Xilinx specific utilities that are able to run both Vivado and Vitis with TCL or python scripts (used by `build.py`)

### Architecture
#### General
The diagram below was created in accordance to [High Level Architecture and Detailed Single Worker Architecture](../README.md). It clarifies, which components belong to PS and which to PL- implemented in HDL. Several indicated IP cores: AXI Interconnecct, AXI BRAM Controller, AXI Protocol Converter belong to AMD IP Cores Library. RISC-V IP is the custom made IP Core which integrates the core of choice with Fault Injection/Controll Module.

![SOC Detailed Architecture](../docs/soc_architecture.drawio.png)

#### Programmable Logic
An FPGA design. Most of the building blocks mentioned in `Architecture/General` belong to this layer and their properties, relationships between each other are defined in BD inside `xiilinx/scripts/build_riscv_worker_pl.tcl/`.

#### Processing System
The software part of the framework contains the software defined part of the Control Module as well as functions crucial to communicate with the Master PC. Sources are spread inside: `xilinx/src` and `xilinx/include` and are used during Vitis project creation. The outcome of `build.py` is `xilinx/build/vitis_ws/` directory that contains `elf` and `xsa` files as well as fetched sources (**Vitis copies sources to flat directory so any change to them should happen inside `xilinx/src/` or `xilinx/include/` otherwise such changes will not be included into source control**). 
