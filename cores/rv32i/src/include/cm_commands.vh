`ifndef CM_COMMANDS_VH
`define CM_COMMANDS_VH

/****************************************************************************
Inside this AXI slave we need to multiplex between different sub components:
- register file
- other registers of the core (PC)
- control options (starting / stopping the core)
- fault injection

Selecting which of these to talk to based on the address.
The lowest `SUB_ADDR_WIDTH bits are used to specify the address within the
component.
The next `SUB_SEL_WIDTH bits are used to specify which component to talk to.
The upper bits are ignored so this AXI slave can be placed freely in the
masters memory space.
Layout hhhhhhhh hhhhhhhh ssssaaaa aaaaaaaa:
- h are the high bits, assummed to be used by the interconnect
- s is the SUB_SEL, selecting which component to talk to
- a is the SUB_ADDR, address within the component
The components are:
- Control Registers (SUB_SEL_CTRL = 0001):
  - register such as Status, Start core, Stop core, Step core, PC. See below
- CPU Registers (0002)
  - SUB_ADDR is formatted as 0000 0rrrrr00
  - -> holds the register index r (0-31) multiplied by 4 (since registers are word-aligned)
- CPU Register Fault Injection (0003) 
    - 00mm 0rrrrr00
    - r: register index (0-31)
    - m: fault mode (see below)
    - write to this address injects a fault into the specified register according to the mode
******************************************************************************/

`define SUB_SEL_WIDTH 4
`define SUB_ADDR_WIDTH 12
`define USED_ADDR_WIDTH (`SUB_SEL_WIDTH+`SUB_ADDR_WIDTH) // 16 bit address space

`define SUB_SEL_CTRL `SUB_SEL_WIDTH'h1
`define SUB_SEL_REGFILE `SUB_SEL_WIDTH'h2
`define SUB_SEL_FAULT `SUB_SEL_WIDTH'h3

`define FAULT_MODE_MSB 9 // position in 00mm 0rrrrr00
`define FAULT_MODE_LSB 8

`define CTRL_REG_STATUS `SUB_ADDR_WIDTH'h000
`define CTRL_REG_START `SUB_ADDR_WIDTH'h004
`define CTRL_REG_STOP `SUB_ADDR_WIDTH'h008
`define CTRL_REG_STEP `SUB_ADDR_WIDTH'h00C
`define CTRL_REG_PC `SUB_ADDR_WIDTH'h010
`define CTRL_REG_DBG_VECTOR `SUB_ADDR_WIDTH'h01C

`define FAULT_MODE_WIDTH 2
`define FAULT_MODE_OVERWRITE `FAULT_MODE_WIDTH'b00
`define FAULT_MODE_XOR_MASK `FAULT_MODE_WIDTH'b01
`define FAULT_MODE_OR_MASK `FAULT_MODE_WIDTH'b10
`define FAULT_MODE_ANDN_MASK `FAULT_MODE_WIDTH'b11

// Address construction helper macros
`define CONTROL_ADDR(reg_offset) \
    ((`SUB_SEL_CTRL << `SUB_ADDR_WIDTH) | (reg_offset))
`define REGFILE_ADDR(reg_idx) \
    ((`SUB_SEL_REGFILE << `SUB_ADDR_WIDTH) | ((reg_idx) << 2))
`define FAULT_ADDR(fault_mode, reg_idx) \
    ((`SUB_SEL_FAULT << `SUB_ADDR_WIDTH) | ((fault_mode) << `FAULT_MODE_LSB) | ((reg_idx) << 2))
`define FAULT_ADDR_RAW(sub_addr) \
    ((`SUB_SEL_FAULT << `SUB_ADDR_WIDTH) | (sub_addr))

`endif
