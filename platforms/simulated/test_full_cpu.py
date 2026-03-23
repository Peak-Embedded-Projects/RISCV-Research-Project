"""
Cocotb based generic test for running any arbitrary RISC-V
assembly program. This test is supposed to be executed via
test_runner.py from the root directory and should use as dut
any user specified RISC-V core from cores/.
"""

import os
from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge
from cocotbext.axi import AxiLiteBus, AxiLiteRam

from tb_utils.constants import *
from tb_utils.logging import log_err
from tb_utils.resets import reset_active_low
from tb_utils.memory import (
    read_program_from_file,
    read_expected_values_from_file,
)


@cocotb.test()
async def test_riscv_full(dut):
    cocotb.start_soon(Clock(dut.CLK, 10, unit="ns").start())

    CURRENT_DIR = Path(__file__).resolve().parent
    ROOT_DIR = CURRENT_DIR.parent.parent

    which_program = os.environ.get("TEST_TO_RUN")
    dut._log.info(f"TEST PROGRAM: {which_program}")
    rv_program_path = ROOT_DIR / "cores" / "test_programs" / which_program

    program = read_program_from_file(str(rv_program_path / "program.hex"))
    exp_registers = read_expected_values_from_file(
        str(rv_program_path / "expected_registers.hex")
    )
    exp_memory = read_expected_values_from_file(
        str(rv_program_path / "expected_memory.hex")
    )
    init_memory = read_expected_values_from_file(str(rv_program_path / "memory.hex"))

    # Control Module is not active here, therefore inputs
    # to the core related to it should be fixed
    # (except of cm_pc_stall: this one will be used)

    dut.cm_pc_stall.value = 1
    # dut.cm_pc_read_data.value =
    dut.cm_pc_we.value = 0
    dut.cm_pc_write_data.value = 0
    dut.cm_regfile_addr.value = 0
    # dut.cm_regfile_read_data.value =
    dut.cm_regfile_we.value = 0
    dut.cm_regfile_write_data.value = 0

    await Timer(
        1, unit="step"
    )  # freeze python and let initialization propagate through one step, otherwise it crushes

    ram = AxiLiteRam(
        AxiLiteBus.from_prefix(dut, "M_AXI"),
        dut.CLK,
        dut.RSTn,
        reset_active_level=False,
        size=2 * 4096,
    )

    INSTR_BASE_ADDR = BOOT_ADDR
    DATA_BASE_ADDR = 0x00000000

    dut._log.info("Loading initial data to mock ram...")
    for i, data_val in enumerate(init_memory):
        data_bytes = int(data_val).to_bytes(4, byteorder="little")
        addr = DATA_BASE_ADDR + (i * 4)
        ram.write(addr, data_bytes)

    dut._log.info("Loading program to mock ram...")
    for i, instr_bytes in enumerate(program):
        addr = INSTR_BASE_ADDR + (i * 4)
        ram.write(addr, instr_bytes)

    await reset_active_low(dut.RSTn, dut.CLK)
    dut._log.info("Reset complete. Starting CPU...")

    # CPU starts here
    dut.cm_pc_stall.value = 0

    timeout_cycles = 1000
    cycles = 0

    while cycles < timeout_cycles:
        await RisingEdge(dut.CLK)
        cycles += 1
        try:
            current_instr = int(dut.instruction.value)
            if current_instr == 0x0000006F:  # check for JAL x0, 0 loop
                dut._log.info(f"Program HALT reached after {cycles} cycles.")
                break
        except ValueError:
            pass  # ignore 'X' states during the first few clock cycles

    assert (
        cycles < timeout_cycles
    ), f"Simulation timed out! Exceeded {timeout_cycles} cycles."

    # The end of CPU execution
    dut.cm_pc_stall.value = 1

    dut._log.info("Verifying Registers...")

    for reg_id in range(1, 32):
        actual_val = int(dut.u_register_file.registers[reg_id].value)
        expected_val = int(exp_registers[reg_id - 1])

        dut._log.info(f"Reg. {reg_id} check ...")
        assert actual_val == expected_val, log_err(expected_val, actual_val)

    dut._log.info("Verifying Memory...")
    for i, exp_val in enumerate(exp_memory):
        addr = DATA_BASE_ADDR + (i * 4)

        actual_bytes = ram.read(addr, 4)
        actual_val = int.from_bytes(actual_bytes, byteorder="little")
        expected_val = int(exp_val)

        dut._log.info(f"Mem [0x{addr}] check ...")
        assert actual_val == expected_val, log_err(expected_val, actual_val)

    dut._log.info(f"Verification of {which_program} complete!")
