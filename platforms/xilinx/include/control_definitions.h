/*************************************************************************
 * Definitions necessary to read/write to interact via AXI with
 * - register file
 * - other registers of the core (PC)
 * - control options (starting / stopping the core)
 *
 * Selecting which of these to talk to based on the address.
 * The lowest `SUB_ADDR_WIDTH bits are used to specify the address within the
 * component.
 *
 * The next `SUB_SEL_WIDTH bits are used to specify which component to talk to.
 * The upper bits are ignored so this AXI slave can be placed freely in the
 * masters memory space.
 * Layout (h are the high bits, assummed to be used by the interconnect):
 * - hhhh 01rr: control register r. one of the following
 * - Status
 * - Start core
 * - Stop core
 * - Step core
 * - PC
 * - hhhh 02rr: CPU register r (0 to 31 used to refer to x0 to x31)
 *************************************************************************/

#ifndef CONTROL_DEFINITIONS_H
#define CONTROL_DEFINITIONS_H

#define SUB_ADDR_WIDTH 8
#define SUB_SEL_WIDTH 8
#define USED_ADDR_WIDTH (SUB_SEL_WIDTH + SUB_ADDR_WIDTH)
#define SUB_SEL_CTRL 0x01
#define SUB_SEL_REGFILE 0x02
#define CTRL_REG_STATUS 0x00
#define CTRL_REG_START 0x04
#define CTRL_REG_STOP 0x08
#define CTRL_REG_STEP 0x0C
#define CTRL_REG_PC 0x10

#endif