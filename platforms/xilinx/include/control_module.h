#ifndef CONTROL_MODULE_H
#define CONTROL_MODULE_H

#include <stdint.h>

enum component_type {
  REGFILE = 0,
  PC = 1,
  BRAM = 2,
  STEP = 3,
  START = 4,
  STOP = 5
};

/**
 * @brief Create an address used by xil_io
 *
 * @param comp type of component to handle
 * @param request address of a specific request
 * @return uint32_t address
 */
uint32_t cm_create_address(enum component_type comp, uint16_t request);

/**
 * @brief Write to the register file
 *
 * @param register_num specify which register (2-32) (cannot write to the 1st)
 * @param value
 */
void cm_regfile_write(uint8_t register_num, int value);

/**
 * @brief Read from the register file
 *
 * @param register_num specify which register (1-32)
 * @return uint32_t value stored inside
 */
uint32_t cm_regfile_read(uint8_t register_num);

/**
 * @brief Set the value of the Program Counter
 *
 * @param value address for the Program Counter
 */
void cm_pc_set(uint32_t value);

/**
 * @brief Get the current address of the Program Counter
 *
 * @return uint32_t current address of the Program Counter
 */
uint32_t cm_pc_read();

/**
 * @brief Step one instruction forward
 *
 */
void cm_single_step_core();

/**
 * @brief Unstall the core
 *
 */
void cm_core_start();

/**
 * @brief Stall the core
 *
 */
void cm_core_stop();

/**
 * @brief Write to the specific address of BRAM
 *
 * @param addr address where to wrtie
 * @param data data to write
 */
void cm_bram_write(uint32_t addr, uint32_t data);

/**
 * @brief Read a specific address of BRAM
 *
 * @param addr address to read from
 * @return uint32_t read value
 */
uint32_t cm_bram_read(uint32_t addr);

#endif