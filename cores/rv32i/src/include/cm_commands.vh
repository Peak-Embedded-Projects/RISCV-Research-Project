`ifndef CM_COMMANDS_VH
`define CM_COMMANDS_VH

/****************************************************************************
Inside this AXI slave we need to multiplex between different sub components:
- register file
- other registers of the core (PC)
- control options (starting / stopping the core)

Selecting which of these to talk to based on the address.
The lowest `SUB_ADDR_WIDTH bits are used to specify the address within the
component.
The next `SUB_SEL_WIDTH bits are used to specify which component to talk to.
The upper bits are ignored so this AXI slave can be placed freely in the
masters memory space.
Layout (h are the high bits, assummed to be used by the interconnect):
  - hhhh 01rr: control register r. one of the following
  - Status
  - Start core
  - Stop core
  - Step core
  - PC
  - hhhh 02rr: CPU register r (0 to 31 used to refer to x0 to x31)
******************************************************************************/

`define SUB_ADDR_WIDTH 8
`define SUB_SEL_WIDTH 8
`define USED_ADDR_WIDTH (`SUB_SEL_WIDTH+`SUB_ADDR_WIDTH)
`define SUB_SEL_CTRL `SUB_SEL_WIDTH'h01
`define SUB_SEL_REGFILE `SUB_SEL_WIDTH'h02
`define CTRL_REG_STATUS `SUB_ADDR_WIDTH'h00
`define CTRL_REG_START `SUB_ADDR_WIDTH'h04
`define CTRL_REG_STOP `SUB_ADDR_WIDTH'h08
`define CTRL_REG_STEP `SUB_ADDR_WIDTH'h0C
`define CTRL_REG_PC `SUB_ADDR_WIDTH'h10

`endif
