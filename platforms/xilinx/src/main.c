#include "control_module.h"
#include "platform.h"
#include "xil_cache.h"
#include "xil_printf.h"
#include "xparameters.h"
#include <stdbool.h>
#include <errno.h>
#include <limits.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <xil_io.h>

#define BRAM_BASE_ADDR XPAR_XBRAM_0_BASEADDR
#define CORE_CTRL_BASE_ADDR XPAR_RISCV_MOD_NAME_BASEADDR

#define UART_LINE_MAX 160
#define MODE_MAX 3u

static bool uart_readline(char *buf, uint32_t max_len) {
  uint32_t i = 0;
  bool is_truncated = false;

  while (1) {
    char c = inbyte();
    if (c == '\r' || c == '\n') {
      break;
    }
    if (i < (max_len - 1u)) {
      buf[i++] = c;
    } else {
      is_truncated = true;
    }
  }

  buf[i] = '\0';
  return !is_truncated;
}

static bool parse_u32(const char *token, uint32_t *out) {
  char *endptr = NULL;
  unsigned long parsed = 0;

  errno = 0;
  parsed = strtoul(token, &endptr, 0);
  if (token[0] == '\0' || endptr == token || *endptr != '\0') {
    return false;
  }
  if (errno == ERANGE || parsed > UINT_MAX) {
    return false;
  }
  *out = (uint32_t)parsed;
  return true;
}

static char *next_token(void) { return strtok(NULL, " \t"); }

static bool parse_next_u32(uint32_t *out) {
  char *token = next_token();
  if (token == NULL) {
    return false;
  }
  return parse_u32(token, out);
}

static void reply_ok(void) { xil_printf("OK\n"); }

static void reply_ok_u32(uint32_t value) { xil_printf("OK 0x%08X\n", value); }

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

int main(void) {
  char line[UART_LINE_MAX];

  init_platform();

  cm_core_stop();
  cm_pc_set(BRAM_BASE_ADDR);

  while (1) {
    char *cmd = NULL;

    if (!uart_readline(line, UART_LINE_MAX)) {
      xil_printf("ERR LINE_TOO_LONG\n");
      continue;
    }

    cmd = strtok(line, " \t");

    if (cmd == NULL) {
      continue;
    }

    if (strcmp(cmd, "PROTOCOL_VERSION") == 0) {
      reply_ok_u32(1u);
      continue;
    }

    if (strcmp(cmd, "START") == 0) {
      cm_core_start();
      reply_ok();
      continue;
    }

    if (strcmp(cmd, "STOP") == 0) {
      cm_core_stop();
      reply_ok();
      continue;
    }

    if (strcmp(cmd, "STEP") == 0) {
      cm_single_step_core();
      reply_ok();
      continue;
    }

    if (strcmp(cmd, "GET_PC") == 0) {
      reply_ok_u32(cm_pc_read());
      continue;
    }

    if (strcmp(cmd, "SET_PC") == 0) {
      uint32_t pc_val = 0;
      if (!parse_next_u32(&pc_val)) {
        xil_printf("ERR BAD_PC\n");
        continue;
      }
      cm_pc_set(pc_val);
      reply_ok();
      continue;
    }

    if (strcmp(cmd, "GET_REG") == 0) {
      uint32_t reg_idx = 0;
      if (!parse_next_u32(&reg_idx) || reg_idx > 31u) {
        xil_printf("ERR BAD_REG\n");
        continue;
      }
      reply_ok_u32(cm_regfile_read((uint8_t)reg_idx));
      continue;
    }

    if (strcmp(cmd, "SET_REG") == 0) {
      uint32_t reg_idx = 0;
      uint32_t value = 0;
      if (!parse_next_u32(&reg_idx) || !parse_next_u32(&value) || reg_idx > 31u) {
        xil_printf("ERR BAD_REG\n");
        continue;
      }
      cm_regfile_write((uint8_t)reg_idx, value);
      reply_ok();
      continue;
    }

    if (strcmp(cmd, "READ_WORD") == 0) {
      uint32_t addr = 0;
      if (!parse_next_u32(&addr)) {
        xil_printf("ERR BAD_ADDR\n");
        continue;
      }
      reply_ok_u32(Xil_In32(addr));
      continue;
    }

    if (strcmp(cmd, "WRITE_WORD") == 0) {
      uint32_t addr = 0;
      uint32_t value = 0;
      if (!parse_next_u32(&addr) || !parse_next_u32(&value)) {
        xil_printf("ERR BAD_WRITE\n");
        continue;
      }
      Xil_Out32(addr, value);
      Xil_DCacheFlushRange(addr, 4u);
      reply_ok();
      continue;
    }

    if (strcmp(cmd, "FAULT_REG") == 0) {
      uint32_t reg_idx = 0;
      uint32_t mode = 0;
      uint32_t mask = 0;
      if (!parse_next_u32(&reg_idx) || !parse_next_u32(&mode) ||
          !parse_next_u32(&mask) || reg_idx > 31u || mode > MODE_MAX) {
        xil_printf("ERR BAD_FAULT_REG\n");
        continue;
      }

      cm_regfile_fault_inject((uint8_t)reg_idx, mask, (cm_fault_mode_t)mode);
      reply_ok();
      continue;
    }

    if (strcmp(cmd, "FAULT_MEM") == 0) {
      uint32_t addr = 0;
      uint32_t mode = 0;
      uint32_t mask = 0;
      uint32_t current = 0;
      uint32_t updated = 0;
      if (!parse_next_u32(&addr) || !parse_next_u32(&mode) ||
          !parse_next_u32(&mask) || mode > MODE_MAX || (addr & 0x3u) != 0u) {
        xil_printf("ERR BAD_FAULT_MEM\n");
        continue;
      }

      current = Xil_In32(addr);
      updated = apply_fault_mode(current, mode, mask);
      Xil_Out32(addr, updated);
      Xil_DCacheFlushRange(addr, 4u);
      reply_ok();
      continue;
    }

    xil_printf("ERR UNKNOWN_CMD\n");
  }

  cleanup_platform();
  return 0;
}
