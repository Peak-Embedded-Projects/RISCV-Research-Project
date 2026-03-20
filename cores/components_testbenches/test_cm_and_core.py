"""
CM and Core test:
AXI 4 Lite connection to the control module
reg                          S_AXI_AWVALID;
wire                         S_AXI_AWREADY;
reg  [  `AXI_ADDR_WIDTH-1:0] S_AXI_AWADDR;
reg  [  `AXI_PROT_WIDTH-1:0] S_AXI_AWPROT;
reg                          S_AXI_WVALID;
wire                         S_AXI_WREADY;
reg  [  `AXI_DATA_WIDTH-1:0] S_AXI_WDATA;
reg  [`AXI_STROBE_WIDTH-1:0] S_AXI_WSTRB;
wire                         S_AXI_BVALID;
reg                          S_AXI_BREADY;
wire [  `AXI_RESP_WIDTH-1:0] S_AXI_BRESP;
reg                          S_AXI_ARVALID;
wire                         S_AXI_ARREADY;
reg  [  `AXI_ADDR_WIDTH-1:0] S_AXI_ARADDR;
reg  [  `AXI_PROT_WIDTH-1:0] S_AXI_ARPROT;
wire                         S_AXI_RVALID;
reg                          S_AXI_RREADY;
wire [  `AXI_DATA_WIDTH-1:0] S_AXI_RDATA;
wire [  `AXI_RESP_WIDTH-1:0] S_AXI_RRESP;

AXI 4 Lite connection from the core the memory
wire                         M_AXI_AWVALID;
wire                         M_AXI_AWREADY;
wire [  `AXI_ADDR_WIDTH-1:0] M_AXI_AWADDR;
wire [  `AXI_PROT_WIDTH-1:0] M_AXI_AWPROT;
wire                         M_AXI_WVALID;
wire                         M_AXI_WREADY;
wire [  `AXI_DATA_WIDTH-1:0] M_AXI_WDATA;
wire [`AXI_STROBE_WIDTH-1:0] M_AXI_WSTRB;
wire                         M_AXI_BVALID;
wire                         M_AXI_BREADY;
wire [  `AXI_RESP_WIDTH-1:0] M_AXI_BRESP;
wire                         M_AXI_ARVALID;
wire                         M_AXI_ARREADY;
wire [  `AXI_ADDR_WIDTH-1:0] M_AXI_ARADDR;
wire [  `AXI_PROT_WIDTH-1:0] M_AXI_ARPROT;
wire                         M_AXI_RVALID;
wire                         M_AXI_RREADY;
wire [  `AXI_DATA_WIDTH-1:0] M_AXI_RDATA;
wire [  `AXI_RESP_WIDTH-1:0] M_AXI_RRESP;

connections between control module and RISC-V core
wire [  `REG_ADDR_WIDTH-1:0] cm_regfile_addr;
wire [      `DATA_WIDTH-1:0] cm_regfile_read_data;
wire                         cm_regfile_write_enable;
wire [      `DATA_WIDTH-1:0] cm_regfile_write_data;

"""

from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, ClockCycles
from cocotbext.axi import AxiLiteBus, AxiLiteRam, AxiLiteMaster

from tb_utils.constants import *
from tb_utils.logging import log_err
from tb_utils.resets import reset_active_low
from tb_utils.memory import (
    read_program_from_file,
    read_expected_values_from_file,
    get_reg_addr,
)


@cocotb.test()
async def test_cm_and_core(dut):
    cocotb.start_soon(Clock(dut.CLK, 10, unit="ns").start())

    CURRENT_DIR = Path(__file__).resolve().parent
    ROOT_DIR = CURRENT_DIR.parent.parent

    s_type_sb_program_path = (
        ROOT_DIR / "cores" / "test_programs" / "s_type" / "sb" / "program.hex"
    )
    s_type_sb_expected_regs_path = (
        ROOT_DIR
        / "cores"
        / "test_programs"
        / "s_type"
        / "sb"
        / "expected_registers.hex"
    )

    program_as_list = read_program_from_file(str(s_type_sb_program_path))
    expected_registers_as_list = read_expected_values_from_file(
        str(s_type_sb_expected_regs_path)
    )

    dut.S_AXI_AWVALID.value = 0
    dut.S_AXI_WVALID.value = 0
    dut.S_AXI_AWPROT.value = 0b0
    dut.S_AXI_BREADY.value = 0
    dut.S_AXI_ARVALID.value = 0
    dut.S_AXI_RREADY.value = 0
    dut.S_AXI_ARADDR.value = 0
    dut.S_AXI_AWADDR.value = 0
    dut.S_AXI_ARPROT.value = 0b0
    dut.S_AXI_WDATA.value = 0
    dut.S_AXI_WSTRB.value = 0

    await Timer(
        1, unit="step"
    )  # freeze python and let initialization propagate through one step, otherwise it crushes

    axim = AxiLiteMaster(
        AxiLiteBus.from_prefix(dut, "S_AXI"),
        dut.CLK,
        dut.RSTn,
        reset_active_level=False,
    )

    ram = AxiLiteRam(
        AxiLiteBus.from_prefix(dut, "M_AXI"),
        dut.CLK,
        dut.RSTn,
        reset_active_level=False,
        size=2**12,
    )

    dut._log.info("Loading program to mock ram")
    base_addr = 0x00000000

    for i, instr_bytes in enumerate(program_as_list):
        addr = base_addr + (i * 4)
        ram.write(addr, instr_bytes)

    await reset_active_low(dut.RSTn, dut.CLK)
    dut._log.info("Reset complete. CPU is currently stalled.")

    await ClockCycles(dut.CLK, 10)
    dut._log.info("Reading Reg 5")
    read_result = await axim.read_dword(get_reg_addr(5))
    assert read_result == 0x0, log_err(0, read_result)

    dut._log.info("Single Step Core (lw x5, 0xAB)")
    await axim.write_dword(SUB_SEL_CTRL | CTRL_REG_STEP, 0x1)
    await ClockCycles(dut.CLK, 10)

    dut._log.info("Read Reg 5")
    read_result = await axim.read_dword(get_reg_addr(5))
    assert read_result == expected_registers_as_list[4], log_err(
        expected_registers_as_list[4], read_result
    )

    dut._log.info("Read Reg 6")
    read_result = await axim.read_dword(get_reg_addr(6))
    assert read_result == 0x0, log_err(0, read_result)

    dut._log.info("Single Step Core (lw x6, 0xCD)")
    await axim.write_dword(SUB_SEL_CTRL | CTRL_REG_STEP, 0x1)
    await ClockCycles(dut.CLK, 10)

    dut._log.info("Read Reg 6")
    read_result = await axim.read_dword(get_reg_addr(6))
    assert read_result == expected_registers_as_list[5], log_err(
        expected_registers_as_list[5], read_result
    )

    dut._log.info("Read Status Reg")
    read_result = await axim.read_dword(SUB_SEL_CTRL | CTRL_REG_STATUS)
    assert read_result == 0x1, log_err(1, read_result)

    dut._log.info("Read PC")
    read_result = await axim.read_dword(SUB_SEL_CTRL | CTRL_REG_PC)
    assert read_result == 0x1008, log_err(0x1008, read_result)

    dut._log.info("Write PC")
    await axim.write_dword(SUB_SEL_CTRL | CTRL_REG_PC, 0x100C)

    dut._log.info("Read PC")
    read_result = await axim.read_dword(SUB_SEL_CTRL | CTRL_REG_PC)
    assert read_result == 0x100C, log_err(0x100C, read_result)

    dut._log.info("Single Step Core (sb x5, 0(x0))")
    await axim.write_dword(SUB_SEL_CTRL | CTRL_REG_STEP, 1)
    await ClockCycles(dut.CLK, 10)

    dut._log.info("Read Reg 7")
    read_result = await axim.read_dword(get_reg_addr(7))
    assert read_result == 0x0, log_err(0, read_result)

    dut._log.info("Set core to freerun")
    await axim.write_dword(SUB_SEL_CTRL | CTRL_REG_START, 1)

    dut._log.info("Read Status Reg")
    read_result = await axim.read_dword(SUB_SEL_CTRL | CTRL_REG_STATUS)
    assert read_result == 0x0, log_err(0, read_result)

    await ClockCycles(dut.CLK, 100)

    dut._log.info("Stop core")
    await axim.write_dword(SUB_SEL_CTRL | CTRL_REG_STOP, 1)

    dut._log.info("Read Status Reg")
    read_result = await axim.read_dword(SUB_SEL_CTRL | CTRL_REG_STATUS)
    assert read_result == 0x1, log_err(1, read_result)

    dut._log.info("Read PC")
    read_result = await axim.read_dword(SUB_SEL_CTRL | CTRL_REG_PC)
    assert read_result == 0x1020, log_err(0x1020, read_result)
