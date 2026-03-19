"""
Register File Test:
Register File input
reg [`REG_ADDR_WIDTH-1:0] rs1_addr;
reg [`REG_ADDR_WIDTH-1:0] rs2_addr;

reg                       rd_enbl;

wire [`DATA_WIDTH-1:0]    rs1;
wire [`DATA_WIDTH-1:0]    rs2;

reg [`REG_ADDR_WIDTH-1:0]  wrt_addr;
reg [`DATA_WIDTH-1:0]      wrt_dat;
reg                        wrt_enbl;

"""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, Timer, ClockCycles

from tb_utils.resets import reset_active_low
from tb_utils.logging import log_registers


@cocotb.test()
async def test_register_file(dut):
    cocotb.start_soon(Clock(dut.CLK, 10, unit="ns").start())

    dut.rs1_addr.value = 0
    dut.rs2_addr.value = 0
    dut.write_enable.value = 0
    dut.write_addr.value = 0
    dut.write_data.value = 0

    dut._log.info("Applying reset...")
    await reset_active_low(dut.RSTn, dut.CLK)

    dut._log.info("Test 1: Read after reset")
    await FallingEdge(dut.CLK)
    dut.rs1_addr.value = 1
    dut.rs2_addr.value = 2

    await Timer(1, unit="ns")
    log_registers(dut)
    assert dut.rs1.value == 0, f"Test 1 FAILED: x1 not 0, got {hex(dut.rs1.value)}"
    assert dut.rs2.value == 0, f"Test 1 FAILED: x2 not 0, got {hex(dut.rs2.value)}"

    dut._log.info("Test 2: Hardwired x0")
    await FallingEdge(dut.CLK)
    dut.rs1_addr.value = 0
    dut.rs2_addr.value = 0

    # Try writing to x0 simultaneously
    dut.write_enable.value = 1
    dut.write_addr.value = 0
    dut.write_data.value = 0xDEADBEEF

    await ClockCycles(dut.CLK, 1)
    await Timer(1, unit="ns")

    log_registers(dut)
    assert dut.rs1.value == 0, "Test 2 FAILED: Write to x0 affected output rs1"
    assert dut.rs2.value == 0, "Test 2 FAILED: Write to x0 affected output rs2"

    dut.write_enable.value = 0

    dut._log.info("Test 3: Standard Write and Read")
    await FallingEdge(dut.CLK)
    dut.write_enable.value = 1
    dut.write_addr.value = 1
    dut.write_data.value = 0x12345678

    await ClockCycles(dut.CLK, 1)

    await FallingEdge(dut.CLK)
    dut.write_enable.value = 0
    dut.rs1_addr.value = 1
    dut.rs2_addr.value = 1

    await Timer(1, unit="ns")
    log_registers(dut)
    assert dut.rs1.value == 0x12345678, "Test 3 FAILED: Write to x1 not read correctly"

    dut._log.info("Test 4: Multiple Writes and Reads")
    await FallingEdge(dut.CLK)
    dut.write_enable.value = 1
    dut.write_addr.value = 3
    dut.write_data.value = 0x5555AAAA
    await ClockCycles(dut.CLK, 1)

    await FallingEdge(dut.CLK)
    dut.write_addr.value = 4
    dut.write_data.value = 0xFFFF0000
    await ClockCycles(dut.CLK, 1)

    await FallingEdge(dut.CLK)
    dut.write_enable.value = 0
    dut.rs1_addr.value = 3
    dut.rs2_addr.value = 4

    await Timer(1, unit="ns")
    log_registers(dut)
    assert dut.rs1.value == 0x5555AAAA, "Test 4 FAILED: rs1 (x3) read incorrect"
    assert dut.rs2.value == 0xFFFF0000, "Test 4 FAILED: rs2 (x4) read incorrect"

    dut._log.info("All tests completed successfully!")
