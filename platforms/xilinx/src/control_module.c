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


void cm_regfile_write(uint8_t register_num, int value) {
  uint32_t address = XPAR_RISCV_MOD_NAME_BASEADDR + REGFILE_REQUEST(register_num);
  Xil_Out32(address, value);
}

uint32_t cm_regfile_read(uint8_t register_num) {
  uint32_t address = XPAR_RISCV_MOD_NAME_BASEADDR + REGFILE_REQUEST(register_num);
  uint32_t read_value = Xil_In32(address);

  return read_value;
}

void cm_pc_set(uint32_t value) {
  uint32_t address = XPAR_RISCV_MOD_NAME_BASEADDR + PC_REQUEST;
  Xil_Out32(address, value);
}

uint32_t cm_pc_read() {
  uint32_t address = XPAR_RISCV_MOD_NAME_BASEADDR + PC_REQUEST;
  uint32_t pc_value = Xil_In32(address);

  return pc_value;
}

void cm_single_step_core() {
  uint32_t address = XPAR_RISCV_MOD_NAME_BASEADDR + STEP_REQUEST;
  uint32_t step_trigger_val = 0x01;
  Xil_Out32(address, step_trigger_val);
  usleep(500);
}

void cm_core_start() {
  uint32_t address = XPAR_RISCV_MOD_NAME_BASEADDR + START_REQUEST;
  uint32_t start_trigger_val = 0x01;
  Xil_Out32(address, start_trigger_val);
}

void cm_core_stop() {
  uint32_t address = XPAR_RISCV_MOD_NAME_BASEADDR + STOP_REQUEST;
  uint32_t stop_trigger_val = 0x01;
  Xil_Out32(address, stop_trigger_val);
}
