# RISCV-Research-Project

This repository contains a framework for injecting artificial SEU faults into a RISC-V core. This work was done as part of the ISAE Supaero Master Aerospace Engineering degree.

## Project Overview

RISC-V is an open-source instruction set architecture (ISA). Due to its non-proprietary nature, its adaptation to the space industry can reduce costs related to licensing.

Central processing units that operate in the space environment are subjected to different kinds of radiation. A common case is exposure to ionizing radiation, which interacts with electrical components of satellites in Earth orbit. A phenomenon known as [Single Event Upset (SEU)](https://en.wikipedia.org/wiki/Single-event_upset) can result in a bit flip in CPU memory or a register file, causing incorrect software execution.

This project focuses on two goals:

1. Adapting RISC-V architecture to the space environment with SEU mitigation techniques.
2. Establishing a generic test framework on SoC platforms that injects simulated SEU faults and analyzes outputs to evaluate mitigated core performance. The framework should support verification of different cores, as long as they can synthesize on the supported platform with minimal changes (mostly exposing ports).

### Architecture

The proposed architecture uses [Digilent Zybo Z7-20](https://digilent.com/shop/zybo-z7-zynq-7000-arm-fpga-soc-development-board/) boards and a master computer (Master PC).

#### High-level architecture

The idea is to use two workers (Zybo boards): one with a mitigated core and one without mitigation. Both workers communicate with the Master PC (labeled as the Fault Injection Orchestrator in the diagram below), which sends instruction workloads and fault injection commands.

![High Level Architecture](docs/high_level_arch.drawio.png)

The outputs from the cores are collected and compared to determine whether mitigation worked and what the time-performance impact of the mitigated CPU is.

#### Detailed Single-Worker Architecture

The detailed architecture of a single worker is shown below. The Master PC sends commands over UART, which are received by the built-in Zybo ARM Cortex CPU. The ARM Cortex acts as an AXI Master, interprets requests from the Master PC, and performs the following steps:

1. Inform the Control Module to stop the processor.
2. Modify the core instruction memory with a new instruction according to the fault-vector segment related to memory.
3. Inform the Control Module about values to write to the register file. The Control Module communicates with the Fault Injection Module (FIM) about faults to inject into the register file. Once FIM prepares the data, the Control Module updates the register file.
4. Once the register file is updated, the `unstall signal` is issued and the core executes instruction(s). In parallel, a timer is started to measure how long instruction execution takes.
5. When the processor finishes, it is stalled again via `Zynq PC -> Control Module`. After the stall, data is collected: memory, register file, and program counter.
6. Collected data is sent back to the Master PC.

All communication between Programmable Logic (PL) and the Processing System (PS, ARM) uses the [AMBA AXI](https://www.amd.com/en/products/adaptive-socs-and-fpgas/intellectual-property/axi.html) protocol.

![Single Worker Architecture](docs/single_worker_high_level_arch.drawio.png)

The component labeled as the RISC-V soft core can be any core that synthesizes on supported hardware such as the Zybo Z7-20. The main advantage of this approach is that it can mimic a debugger-like workflow without implementing full debug mode in the core (greatly simplifying integration) while still allowing SEU injection.

## Development

### Folder Structure

The project tree in simplified form:

```text
├── cores
├── docs
├── masterpc
└── platforms
```

- `cores/`: HDL RISC-V Core implementations and their local tests. \
  Currently this contains a single RV32I core. See [its README](cores/rv32i/README.md) for supported instructions and simulation/testbench workflow.
- `platforms/`: Implementation of the target platforms that the cores can be deployed to. \
  Includes build scripts and integration code.
  See [its README](platforms/README.md) for more details on supported targets and platform-specific information.
- `masterpc/`: The application running on the host computer to control the target.
  ([masterpc/README.md](masterpc/README.md))

### Requirements

Different parts of the project have different requirements.

In general, Python 3 (tested with >=3.11) is required, along with the dependencies specified in `pyproject.toml`. We recommend [uv](https://docs.astral.sh/uv/) to manage the Python virtual environment and dependency installation. Manual installation via pip or any other Python package manager is also possible.

To be able to compile new RISC-V test programs, the `riscv64-unknown-elf` toolchain is needed.
To avoid having a hard dependency on the toolchain, we also store the compiled programs in this repository.

For platform-specific requirements, see [the platforms README](platforms/README.md).


### Building and Running

In the repository root, `build.py` controls hardware build flow (interactive CLI or arguments).

Run interactive mode:

```bash
uv run python build.py
```

Run non-interactive mode (example):

```bash
uv run python build.py --runtime hardware --vendor xilinx --board "Zybo Z7-20" --core rv32i --hdl verilog
```

The hardware flow currently supports Xilinx and produces Vivado/Vitis build artifacts under `platforms/xilinx/build/`.

For Xilinx boards, after `build.py` completes, Vitis must be launched manually to upload the program to the board.

```bash
vitis -w platforms/xilinx/build/vitis_ws
```

### Simulation

Simulation is core-specific for now. See [cores/rv32i/README.md](cores/rv32i/README.md) for current simulation and test program instructions.

