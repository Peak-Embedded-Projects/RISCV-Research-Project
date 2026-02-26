# RISCV-Research-Project
This repository contains a framework for injecting artificial SEU faults into RISC-V core. This work was done as a part of ISAE Supaero Master Aerospace Engineering degree.

## Project's overview
RISC-V is an open-source Instruction Set Architecture. Due to its non-proprietary nature its adaptation to space industry offers great costs cut related to the lack of any licensing. 

Central Processing Units that operate in the space environment are subjected to different kinds of radiation. A very common case is the exposition to an ionizing radiation which interacts with electrical components of satellites on Earth's orbit. A physical phenomena known as [Single Event Upset (SEU)](https://en.wikipedia.org/wiki/Single-event_upset) can result in a bit flip within CPU's memory, register file causing incorrect execution of a running software. Reprecussions of such an accident can be fatal to the mission.

This project focuses on two goals:

1. Adapting RISC-V architecture to the space environment with respect to SEU: applying hardware mitigation techniques.
2. Establishing a generic test framework within Zybo line of ARM/FPGA SoC platforms, which injects simulate SEU faults and analyzes outputs to evaluate mitigated core performance. The framework should allow for a verification of different cores as long as they can synthesize on the supported platform with minial changes (mostly ports expositions).

### Architecture
The proposed architecture uses [Digilent Zybo Z7-20](https://digilent.com/shop/zybo-z7-zynq-7000-arm-fpga-soc-development-board/) development boards and a master computer (later called as Master PC).

#### High Level Architecture
The idea is to have two workers (Zybo boards) one implements mitigated core, another one unmitigated. Both workers communicate with the Master PC (on the diagram below Fault Injection Orchestrator) which sends to them what kind of instruction to execute and what kind of fault to inject.

![High Level Architecture](docs/high_level_arch.drawio.png)

The outputs from cores are collected and compared against each other to establish, if mitigation worked and what was the time performance of the mitgated CPU.

#### Detailed Single Worker Architecture
The detailed aritecture of a single worker is depicted below. Master PC sends commands through UART, which is received by built-in Zybo ARM Cortex CPU. ARM Cortex implements AXI Master which interprets requests from Master PC and does the following:

1. Inform the Control Module to stop the processor.
2. Modify instruction memory of the core with a new instruction and according to the fault vector part related to the memory.
3. Inform Control Module of the values to write to the register file. This module communicates with Fault Injection Module (FIM) about the fault to inject- into register file. Once FIM prepares the data, then Control Module updates the register file.
4. Once register file is updated the ```unstall signal``` is issued and the core executes instruction(s). In the meantime a timer is launched to measure how long it takes to complete the instruction.
5. When the processor finishes it is being stalled once again via ```Zynq PC -> Control Module```. After stall the data is collected: memory, register file, program counter.
6. Collected data is send back to the Master PC.

Entire communication between Programmable Logic (PL) and Processing System (PS)- ARM, is done through [AMBA AXI](https://www.amd.com/en/products/adaptive-socs-and-fpgas/intellectual-property/axi.html) protocol.

![Single Worker Architecture](docs/single_worker_high_level_arch.drawio.png)

Component labeled as RISC-V soft-core is meant to be any core that can synthesize on the supported hardware like Zybo Z7-20. The principal advantage of this approach is that this architecture can mimick debugger workflow without having to implement full debug mode within the core (greately simplyfying it) and inject SEU into the processor.

## Development
The project's tree in the simplified form form looks as follows:
```
├── cores
├── docs
├── masterpc
└── platforms
```

* ```cores```: contains HDL implementations of soft-cores to verify + any build system they use
* ```masterpc```: Master PC application
* ```platforms```: contains platform related builds and elements of build system

### Building and Simulating
In the root directory `build.py` script controls building the hardware and running simulations with an interactive CLI or via terminal arguments.

#### Building hardware
Run either:
```bash
uv run python build.py
```
or (just an example)
```bash
uv run python build.py --runtime hardware --vendor xilinx --board "Zybo Z7-20" --core rv32i --hdl verilog
```

Make sure that the target hardware is listed inside `hardware.json` as well as the backend building scripts etc... are there.

So far the workflow supports only Xilinx products.

#### Simulation
TODO

