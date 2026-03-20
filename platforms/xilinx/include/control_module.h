#ifndef CONTROL_MODULE_H
#define CONTROL_MODULE_H

#include <stdint.h>

typedef enum {
	CM_FAULT_MODE_OVERWRITE = 0,
	CM_FAULT_MODE_XOR_MASK = 1,
	CM_FAULT_MODE_OR_MASK = 2,
	CM_FAULT_MODE_ANDN_MASK = 3,
} cm_fault_mode_t;

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
 * @brief Read the debug vector (data bits from the CPU for debugging purposes)
 *
 * @return uint32_t value of the debug vector
 */
uint32_t cm_debug_vector_read();

/**
 * @brief Build the AXI offset for a fault injection command
 *
 * @param register_num target register (0-31)
 * @param mode fault injection mode
 * @return uint32_t offset to add to XPAR_RISCV_MOD_NAME_BASEADDR
 */
uint32_t cm_fault_request(uint8_t register_num, cm_fault_mode_t mode);

/**
 * @brief Inject a fault into a register using mode+mask payload
 *
 * @param register_num target register (0-31)
 * @param mask fault payload/mask
 * @param mode fault injection mode
 */
void cm_regfile_fault_inject(uint8_t register_num, uint32_t mask,
							 cm_fault_mode_t mode);

#endif
