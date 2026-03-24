/*************************************************************************
 * Definitions necessary to read/write to interact via AXI with
 * - register file
 * - other registers of the core (PC)
 * - control options (starting / stopping the core)
 * - fault injection
 *
 * Selecting which of these to talk to based on the address.
 * The lowest SUB_ADDR_WIDTH bits are used to specify the address within the
 * component.
 *
 * The next SUB_SEL_WIDTH bits are used to specify which component to talk to.
 * The upper bits are ignored so this AXI slave can be placed freely in the
 * masters memory space.
 * Layout (h are the high bits, assumed to be used by the interconnect):
 * hhhhhhhh hhhhhhhh ssssaaaa aaaaaaaa
 * - h: high bits (used by interconnect)
 * - s: SUB_SEL, selecting which component to talk to (4 bits)
 * - a: SUB_ADDR, address within the component (12 bits)
 *
 * The components are:
 * - Control Registers (SUB_SEL_CTRL = 0x1):
 *   - Status, Start, Stop, Step, PC
 * - CPU Registers (SUB_SEL_REGFILE = 0x2):
 *   - SUB_ADDR formatted as 0000 0rrrrr00
 *   - Holds the register index r (0-31) at bit positions [5:1]
 * - CPU Register Fault Injection (SUB_SEL_FAULT = 0x3):
 *   - SUB_ADDR formatted as 00mm 0rrrrr00
 *   - m: fault mode (bits [9:8])
 *   - r: register index (bits [5:1])
 *************************************************************************/

#ifndef CONTROL_DEFINITIONS_H
#define CONTROL_DEFINITIONS_H

#define SUB_ADDR_WIDTH 12
#define SUB_SEL_WIDTH 4
#define USED_ADDR_WIDTH (SUB_SEL_WIDTH + SUB_ADDR_WIDTH)
#define SUB_SEL_CTRL 0x1
#define SUB_SEL_REGFILE 0x2
#define SUB_SEL_FAULT 0x3

#define FAULT_MODE_WIDTH 2
#define FAULT_MODE_LSB 8
#define FAULT_MODE_MSB (FAULT_MODE_LSB + FAULT_MODE_WIDTH - 1)
#define FAULT_REGIDX_MASK 0x1F

#define FAULT_MODE_OVERWRITE 0x0
#define FAULT_MODE_XOR_MASK 0x1
#define FAULT_MODE_OR_MASK 0x2
#define FAULT_MODE_ANDN_MASK 0x3

#define FAULT_REQUEST(mode, reg_idx)                                           \
	((SUB_SEL_FAULT << SUB_ADDR_WIDTH) |                                       \
	 (((mode) & ((1u << FAULT_MODE_WIDTH) - 1u)) << FAULT_MODE_LSB) |         \
	 (((reg_idx) & FAULT_REGIDX_MASK) << 2))

#define CTRL_REG_STATUS 0x00
#define CTRL_REG_START 0x04
#define CTRL_REG_STOP 0x08
#define CTRL_REG_STEP 0x0C
#define CTRL_REG_PC 0x10
#define CTRL_REG_DBG_VECTOR 0x1C

/* Helper macros for constructing AXI addresses */
#define CONTROL_REG_ADDR(reg)                                                  \
	((SUB_SEL_CTRL << SUB_ADDR_WIDTH) | (reg))

#define REGFILE_ADDR(reg_idx)                                                  \
	((SUB_SEL_REGFILE << SUB_ADDR_WIDTH) |                                     \
	 (((reg_idx) & FAULT_REGIDX_MASK) << 2))

#endif