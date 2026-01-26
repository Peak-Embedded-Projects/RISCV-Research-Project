#include "control_module.h"
#include "control_definitions.h"
#include "platform.h"
#include "xbram.h"
#include "xil_io.h"
#include <stdint.h>

#define REGFILE_REQUEST(register_num)                                          \
  ((SUB_SEL_REGFILE << 8) | (register_num << 2))

#define PC_REQUEST ((SUB_SEL_CTRL << 8) | CTRL_REG_PC)

#define STEP_REQUEST ((SUB_SEL_CTRL << 8) | CTRL_REG_STEP)

#define START_REQUEST ((SUB_SEL_CTRL << 8) | CTRL_REG_START)

#define STOP_REQUEST ((SUB_SEL_CTRL << 8) | CTRL_REG_STOP)

uint32_t cm_create_address(enum component_type comp, uint16_t request) {

  switch (comp) {

  case REGFILE:
    return XPAR_RISC_V_32I_CM_0_BASEADDR + request;

  case PC:
    return XPAR_RISC_V_32I_CM_0_BASEADDR + PC_REQUEST;

  case BRAM:
    return XPAR_XBRAM_0_BASEADDR;

  case STEP:
    return XPAR_RISC_V_32I_CM_0_BASEADDR + STEP_REQUEST;

  case START:
    return XPAR_RISC_V_32I_CM_0_BASEADDR + START_REQUEST;

  case STOP:
    return XPAR_RISC_V_32I_CM_0_BASEADDR + STOP_REQUEST;

  default:
    return XPAR_RISC_V_32I_CM_0_BASEADDR +
           STOP_REQUEST; // in case of an unrecognized type stall the core
  }
}

void cm_regfile_write(uint8_t register_num, int value) {
  uint32_t address = cm_create_address(REGFILE, REGFILE_REQUEST(register_num));
  Xil_Out32(address, value);
}

uint32_t cm_regfile_read(uint8_t register_num) {
  uint32_t address = cm_create_address(REGFILE, REGFILE_REQUEST(register_num));
  uint32_t read_value = Xil_In32(address);

  return read_value;
}

void cm_pc_set(uint32_t value) {
  uint32_t address = cm_create_address(PC, 0);
  Xil_Out32(address, value);
}

uint32_t cm_pc_read() {
  uint32_t address = cm_create_address(PC, 0);
  uint32_t pc_value = Xil_In32(address);

  return pc_value;
}

void cm_single_step_core() {
  uint32_t address = cm_create_address(STEP, 0);
  uint32_t step_trigger_val = 0x01;
  Xil_Out32(address, step_trigger_val);
}

void cm_core_start() {
  uint32_t address = cm_create_address(START, 0);
  uint32_t start_trigger_val = 0x01 >> 32;
  Xil_Out32(address, start_trigger_val);
}

void cm_core_stop() {
  uint32_t address = cm_create_address(STOP, 0);
  uint32_t stop_trigger_val = 0x01 >> 32;
  Xil_Out32(address, stop_trigger_val);
}

void cm_bram_write(uint32_t addr, uint32_t data) {
  uint32_t address =
      cm_create_address(BRAM, 0); // in fact just the base address of the BRAM
                                  // function XBram_WriteReg performs the offset
                                  // the a specified address
  XBram_WriteReg(address, addr, data);
}

uint32_t cm_bram_read(uint32_t addr) {
  uint32_t address =
      cm_create_address(BRAM, 0); // in fact just the base address of the BRAM
                                  // function XBram_ReadReg performs the offset
                                  // the a specified address
  return XBram_ReadReg(address, addr);
}