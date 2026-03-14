#include "control_module.h"
#include "platform.h"
#include "xil_cache.h"
#include "xil_printf.h"
#include "xparameters.h"
#include <stdint.h>
#include <xil_io.h>

#define BRAM_BASE_ADDR XPAR_XBRAM_0_BASEADDR
#define CORE_CTRL_BASE_ADDR XPAR_RISCV_MOD_NAME_BASEADDR

#define BOOT_ADDR BRAM_BASE_ADDR
#define DATA_ADDR BRAM_BASE_ADDR + 0x1000

// -----------------------------------------------------------------------------
// PROGRAM DATA
// (sample program to test basic functionality of the core)
// -----------------------------------------------------------------------------
uint32_t program[] = {
    0x0AB00293, // 0: addi x5, x0, 171   (x5 = 0xAB)
    0x0CD00313, // 1: addi x6, x0, 205   (x6 = 0xCD)
    0x0EF00393, // 2: addi x7, x0, 239   (x7 = 0xEF)
    0x40001537, // 3: li x10, 0x40001000 (Memory out base addr)
    0x00550023, // 4: sb x5, 0(x10)      (Mem[0] = 0xAB)
    0x006500A3, // 5: sb x6, 1(x10)      (Mem[1] = 0xCD)
    0x005502A3, // 6: sb x5, 5(x10)      (Mem[5] = 0xAB)
    0x00750423, // 7: sb x7, 8(x10)      (Mem[8] = 0xEF)
    0x00752623, // 8: sw x7, 12(x10)     (Mem[12] = 0x000000EF)
    0x0000006F  // 9: j 0                (Loop forever)
};


void check_reg(uint8_t reg_idx, uint32_t expected) {
  uint32_t actual = cm_regfile_read(reg_idx);
  if (actual == expected) {
    xil_printf("[PASS] Reg x%d = 0x%08X\n", reg_idx, actual);
  } else {
    xil_printf("[FAIL] Reg x%d. Exp: 0x%08X, Got: 0x%08X\n", reg_idx, expected,
               actual);
  }
}

void check_pc(uint32_t expected) {
  // uint32_t dbg_vector = cm_debug_vector_read();
  // xil_printf("dbg_vector = 0x%08X\n", dbg_vector);

  uint32_t actual = cm_pc_read();
  if (actual == expected) {
    xil_printf("[PASS] PC = 0x%08X\n", actual);
  } else {
    xil_printf("[FAIL] PC. Exp: 0x%08X, Got: 0x%08X\n", expected,
               actual);
  }
}

void check_mem_byte(uint32_t byte_addr, uint8_t expected) {
  uint32_t word_addr = byte_addr & 0xFFFFFFFC; // Align to 4 bytes
  uint32_t word_val = Xil_In32(word_addr);

  uint32_t byte_offset = byte_addr & 0x3;
  uint8_t actual = (word_val >> (byte_offset * 8)) & 0xFF;

  if (actual == expected) {
    xil_printf("[PASS] Mem[0x%02X] = 0x%02X\n", byte_addr, actual);
  } else {
    xil_printf("[FAIL] Mem[0x%02X]. Exp: 0x%02X, Got: 0x%02X (Word: 0x%08X)\n",
               byte_addr, expected, actual, word_val);
  }
}

void check_mem_word(uint32_t word_addr, uint32_t expected) {
  uint32_t actual = Xil_In32(word_addr);
  if (actual == expected) {
    xil_printf("[PASS] Mem[0x%02X] = 0x%08X\n", word_addr, actual);
  } else {
    xil_printf("[FAIL] Mem[0x%02X]. Exp: 0x%08X, Got: 0x%08X\n", word_addr,
               expected, actual);
  }
}

int main() {
  init_platform();

  xil_printf("\n--- RISC-V Core Verification Start ---\n");

  xil_printf("Reseting Core...\n");
  cm_core_stop();
  cm_pc_set(BOOT_ADDR);

  xil_printf("Loading Program to BRAM @ offset 0x%X...\n", BOOT_ADDR);
  for (uint32_t i = 0; i < (sizeof(program) / sizeof(program[0])); i++) {
    Xil_Out32(BOOT_ADDR + (i * 4), program[i]);
  }


  for (uint32_t i = 0; i < (sizeof(program) / sizeof(program[0])); i++) {
    check_mem_word(BOOT_ADDR + (i * 4), program[i]);
  }


  check_pc(BOOT_ADDR + 0 * 4);

  // As an alternative to single stepping, just run core in endless mode
  // cm_core_start();
  // usleep(5000);

  // ------------------------------------------------------------
  // addi x5, x0, 0xAB
  // ------------------------------------------------------------
  xil_printf("\nSingle Step: Execute 'addi x5, x0, 0xAB'\n");
  cm_single_step_core();
  check_pc(BOOT_ADDR + 1 * 4);
  check_reg(5, 0xAB);

  // ------------------------------------------------------------
  // addi x6, x0, 0xCD
  // ------------------------------------------------------------
  xil_printf("\nSingle Step: Execute 'addi x6, x0, 0xCD'\n");
  cm_single_step_core();
  check_pc(BOOT_ADDR + 2 * 4);
  check_reg(6, 0xCD);

  // ------------------------------------------------------------
  // addi x7, x0, 0xEF
  // ------------------------------------------------------------
  xil_printf("\nSingle Step: Execute 'addi x7, x0, 0xEF'\n");
  cm_single_step_core();
  check_pc(BOOT_ADDR + 3 * 4);
  check_reg(7, 0xEF);

  // ------------------------------------------------------------
  // li x10, 0x40001000 (Memory out base addr)
  // ------------------------------------------------------------
  xil_printf("\nSingle Step: Execute 'li x10, 0x40001000'\n");
  cm_single_step_core();
  check_pc(BOOT_ADDR + 4 * 4);
  check_reg(10, DATA_ADDR);

  // ------------------------------------------------------------
  // sb x5, 0(x10) -> Write 0xAB to DATA_ADDR + 0
  // ------------------------------------------------------------
  xil_printf("\nSingle Step: Execute 'sb x5, 0(x10)'\n");
  cm_single_step_core();
  check_pc(BOOT_ADDR + 5 * 4);
  check_mem_byte(DATA_ADDR + 0, 0xAB);

  // ------------------------------------------------------------
  // sb x6, 1(x10) -> Write 0xCD to DATA_ADDR + 1
  // ------------------------------------------------------------
  xil_printf("\nSingle Step: Execute 'sb x6, 1(x10)'\n");
  cm_single_step_core();
  check_pc(BOOT_ADDR + 6 * 4);
  check_mem_byte(DATA_ADDR + 1, 0xCD);

  // ------------------------------------------------------------
  // sb x5, 5(x10) -> Write 0xAB to DATA_ADDR + 5
  // DATA_ADDR + 5 is byte index 1 of the word at DATA_ADDR + 4
  // ------------------------------------------------------------
  xil_printf("\nSingle Step: Execute 'sb x5, 5(x10)'\n");
  cm_single_step_core();
  check_pc(BOOT_ADDR + 7 * 4);
  check_mem_byte(DATA_ADDR + 5, 0xAB);

  // ------------------------------------------------------------
  // sb x7, 8(x10) -> Write 0xEF to DATA_ADDR + 8
  // ------------------------------------------------------------
  xil_printf("\nSingle Step: Execute 'sb x7, 8(x10)'\n");
  cm_single_step_core();
  check_pc(BOOT_ADDR + 8 * 4);
  check_mem_byte(DATA_ADDR + 8, 0xEF);

  // ------------------------------------------------------------
  // sw x7, 12(x10) -> Write 0x000000EF to DATA_ADDR + 12
  // ------------------------------------------------------------
  xil_printf("\nSingle Step: Execute 'sw x7, 12(x10)'\n");
  cm_single_step_core();
  check_pc(BOOT_ADDR + 9 * 4);
  check_mem_word(DATA_ADDR + 12, 0x000000EF);

  xil_printf("\nChecking Results:\n");
  check_reg(5, 0xAB);
  check_reg(6, 0xCD);
  check_reg(7, 0xEF);
  check_mem_byte(DATA_ADDR + 0, 0xAB);
  check_mem_byte(DATA_ADDR + 1, 0xCD);
  check_mem_byte(DATA_ADDR + 5, 0xAB);
  check_mem_byte(DATA_ADDR + 8, 0xEF);
  check_mem_word(DATA_ADDR + 12, 0x000000EF);

  xil_printf("\n--- Verification Complete ---\n");

  cleanup_platform();
  return 0;
}
