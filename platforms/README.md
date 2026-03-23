# Platforms

This directory contains platform targets used to build the full system.

Due to closed-source vendor tooling, synthesis/implementation scripts and source files are grouped by vendor. The root `build.py` script uses files from the selected vendor directory to instantiate the design with a selected IP core from `cores/`.

At the moment, the only supported target are Xilinx SoC boards.

## Requirements

### Digilent Zybo Z7-20 (Xilinx SoC)

- Tools: Vitis Unified IDE and Vivado (tested with 2025.1; newer versions may also work).
- [Create the right udev rules](https://digilent.com/reference/programmable-logic/guides/install-cable-drivers)
- For the board [Digilent Zybo Z7-20](https://digilent.com/shop/zybo-z7-zynq-7000-arm-fpga-soc-development-board/), also install [its board files](https://digilent.com/reference/programmable-logic/guides/install-board-files).

## Xilinx

This directory contains scripts and source files specific to Xilinx for deploying the framework on physical hardware.

Scripts in `xilinx/scripts/` are a combination of TCL and Python:

- `xilinx/scripts/package_riscv_ip.tcl`: creates a RISC-V IP core from a selected implementation from `cores/`.
- `xilinx/scripts/build_riscv_worker_pl.tcl`: instantiates the block design (BD), runs synthesis and implementation, and outputs an `xsa` file.
- `xilinx/scripts/build_riscv_worker_ps_pl.py`: creates a Vitis project for the programmable logic (PL) and processing system (PS) layers.
- `xilinx/riscv_build_utils.py`: Xilinx-specific helpers used by `build.py` to invoke Vivado and Vitis.

For repository-wide overview and workflow details, see the root [README](../README.md).

After the automated build completes, Vitis still needs to be launched manually to build/program the target board.

### Architecture

#### General

The diagram below follows the high-level and detailed worker architecture from the root [README](../README.md). It clarifies which components belong to PS and which to PL (implemented in HDL). Several IP blocks (AXI Interconnect, AXI BRAM Controller, AXI Protocol Converter) belong to the AMD IP core library. The RISC-V IP is custom and integrates the selected core with the fault injection/control module.

![SOC Detailed Architecture](../docs/soc_architecture.drawio.png)

#### Programmable Logic

This is the FPGA design layer. Most blocks from `Architecture/General` belong to this layer, and their relationships are defined in the BD created by `xilinx/scripts/build_riscv_worker_pl.tcl`.

#### Processing System

The software part of the framework contains the software-defined part of the control module and communication functions for the Master PC. Sources are in `xilinx/src` and `xilinx/include` and are used during Vitis project creation.

The output of `build.py` includes the `xilinx/build/vitis_ws/` directory.
**Vitis copies sources to a flat workspace, so changes should be made in `xilinx/src/` and `xilinx/include/` to keep them in source control.**
