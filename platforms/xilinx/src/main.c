#include "control_module.h"
#include "platform.h"
#include "xil_cache.h"
#include "xil_printf.h"
#include "xparameters.h"
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <xil_io.h>

#define BRAM_BASE_ADDR XPAR_XBRAM_0_BASEADDR
#define CORE_CTRL_BASE_ADDR XPAR_RISCV_MOD_NAME_BASEADDR

#define UART_LINE_MAX 160
#define MODE_MAX 3u

static void uart_readline(char *buf, uint32_t max_len) {
  uint32_t i = 0;

  while (i < (max_len - 1u)) {
    char c = inbyte();
    if (c == '\r' || c == '\n') {
      break;
    }
    buf[i++] = c;
  }

  buf[i] = '\0';
}

static bool parse_u32(const char *token, uint32_t *out) {
  char *endptr = NULL;
  unsigned long parsed = strtoul(token, &endptr, 0);
  if (token[0] == '\0' || endptr == token || *endptr != '\0') {
    return false;
  }
  *out = (uint32_t)parsed;
  return true;
}

static uint32_t apply_fault_mode(uint32_t original, uint32_t mode,
                                 uint32_t mask) {
  if (mode == CM_FAULT_MODE_OVERWRITE) {
    return mask;
  }
  if (mode == CM_FAULT_MODE_XOR_MASK) {
    return original ^ mask;
  }
  if (mode == CM_FAULT_MODE_OR_MASK) {
    return original | mask;
  }
  return original & ~mask;
}

static void print_help(void) {
  xil_printf("OK COMMANDS PING HELP START STOP STEP RESET GET_PC SET_PC ");
  xil_printf("GET_REG READ_WORD WRITE_WORD FAULT_REG FAULT_MEM\n");
}

int main(void) {
  char line[UART_LINE_MAX];

  init_platform();

  cm_core_stop();
  cm_pc_set(BRAM_BASE_ADDR);

  xil_printf("READY UART_BRIDGE BRAM=0x%08X CTRL=0x%08X\n", BRAM_BASE_ADDR,
             CORE_CTRL_BASE_ADDR);

  while (1) {
    char *cmd = NULL;

    uart_readline(line, UART_LINE_MAX);
    cmd = strtok(line, " \t");

    if (cmd == NULL) {
      continue;
    }

    if (strcmp(cmd, "PING") == 0) {
      xil_printf("OK PONG\n");
      continue;
    }

    if (strcmp(cmd, "HELP") == 0) {
      print_help();
      continue;
    }

    if (strcmp(cmd, "START") == 0) {
      cm_core_start();
      xil_printf("OK STARTED\n");
      continue;
    }

    if (strcmp(cmd, "STOP") == 0) {
      cm_core_stop();
      xil_printf("OK STOPPED\n");
      continue;
    }

    if (strcmp(cmd, "STEP") == 0) {
      cm_single_step_core();
      xil_printf("OK STEPPED\n");
      continue;
    }

    if (strcmp(cmd, "RESET") == 0) {
      uint32_t boot_addr = BRAM_BASE_ADDR;
      char *boot_token = strtok(NULL, " \t");
      if (boot_token != NULL && !parse_u32(boot_token, &boot_addr)) {
        xil_printf("ERR BAD_BOOT_ADDR\n");
        continue;
      }
      cm_core_stop();
      cm_pc_set(boot_addr);
      xil_printf("OK RESET PC=0x%08X\n", boot_addr);
      continue;
    }

    if (strcmp(cmd, "GET_PC") == 0) {
      xil_printf("OK 0x%08X\n", cm_pc_read());
      continue;
    }

    if (strcmp(cmd, "SET_PC") == 0) {
      uint32_t pc_val = 0;
      char *pc_token = strtok(NULL, " \t");
      if (pc_token == NULL || !parse_u32(pc_token, &pc_val)) {
        xil_printf("ERR BAD_PC\n");
        continue;
      }
      cm_pc_set(pc_val);
      xil_printf("OK PC=0x%08X\n", pc_val);
      continue;
    }

    if (strcmp(cmd, "GET_REG") == 0) {
      uint32_t reg_idx = 0;
      char *reg_token = strtok(NULL, " \t");
      if (reg_token == NULL || !parse_u32(reg_token, &reg_idx) || reg_idx > 31u) {
        xil_printf("ERR BAD_REG\n");
        continue;
      }
      xil_printf("OK 0x%08X\n", cm_regfile_read((uint8_t)reg_idx));
      continue;
    }

    if (strcmp(cmd, "READ_WORD") == 0) {
      uint32_t addr = 0;
      char *addr_token = strtok(NULL, " \t");
      if (addr_token == NULL || !parse_u32(addr_token, &addr)) {
        xil_printf("ERR BAD_ADDR\n");
        continue;
      }
      xil_printf("OK 0x%08X\n", Xil_In32(addr));
      continue;
    }

    if (strcmp(cmd, "WRITE_WORD") == 0) {
      uint32_t addr = 0;
      uint32_t value = 0;
      char *addr_token = strtok(NULL, " \t");
      char *value_token = strtok(NULL, " \t");
      if (addr_token == NULL || value_token == NULL ||
          !parse_u32(addr_token, &addr) || !parse_u32(value_token, &value)) {
        xil_printf("ERR BAD_WRITE\n");
        continue;
      }
      Xil_Out32(addr, value);
      Xil_DCacheFlushRange(addr, 4u);
      xil_printf("OK WROTE 0x%08X\n", value);
      continue;
    }

    if (strcmp(cmd, "FAULT_REG") == 0) {
      uint32_t reg_idx = 0;
      uint32_t mode = 0;
      uint32_t mask = 0;
      char *reg_token = strtok(NULL, " \t");
      char *mode_token = strtok(NULL, " \t");
      char *mask_token = strtok(NULL, " \t");

      if (reg_token == NULL || mode_token == NULL || mask_token == NULL ||
          !parse_u32(reg_token, &reg_idx) || !parse_u32(mode_token, &mode) ||
          !parse_u32(mask_token, &mask) || reg_idx > 31u || mode > MODE_MAX) {
        xil_printf("ERR BAD_FAULT_REG\n");
        continue;
      }

      cm_regfile_fault_inject((uint8_t)reg_idx, mask, (cm_fault_mode_t)mode);
      xil_printf("OK FAULT_REG x%u\n", reg_idx);
      continue;
    }

    if (strcmp(cmd, "FAULT_MEM") == 0) {
      uint32_t addr = 0;
      uint32_t mode = 0;
      uint32_t mask = 0;
      uint32_t current = 0;
      uint32_t updated = 0;
      char *addr_token = strtok(NULL, " \t");
      char *mode_token = strtok(NULL, " \t");
      char *mask_token = strtok(NULL, " \t");

      if (addr_token == NULL || mode_token == NULL || mask_token == NULL ||
          !parse_u32(addr_token, &addr) || !parse_u32(mode_token, &mode) ||
          !parse_u32(mask_token, &mask) || mode > MODE_MAX || (addr & 0x3u) != 0u) {
        xil_printf("ERR BAD_FAULT_MEM\n");
        continue;
      }

      current = Xil_In32(addr);
      updated = apply_fault_mode(current, mode, mask);
      Xil_Out32(addr, updated);
      Xil_DCacheFlushRange(addr, 4u);
      xil_printf("OK FAULT_MEM 0x%08X\n", updated);
      continue;
    }

    xil_printf("ERR UNKNOWN_CMD\n");
  }

  cleanup_platform();
  return 0;
}
