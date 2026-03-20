"""
SOC Control Module test:

connections to RISC-V register file
output reg                       pc_stall,
input      [    `DATA_WIDTH-1:0] pc_read_data,
output reg                       pc_write_enable,
output reg [    `DATA_WIDTH-1:0] pc_write_data,
output reg [`REG_ADDR_WIDTH-1:0] regfile_addr,
input      [    `DATA_WIDTH-1:0] regfile_read_data,
output reg                       regfile_write_enable,
output reg [    `DATA_WIDTH-1:0] regfile_write_data,

AXI4-lite connections
AXI write address
output reg                         S_AXI_AWREADY,
input                              S_AXI_AWVALID,
input      [  `AXI_ADDR_WIDTH-1:0] S_AXI_AWADDR,
input      [  `AXI_PROT_WIDTH-1:0] S_AXI_AWPROT,

AXI write data and write strobe
output reg                         S_AXI_WREADY,
input                              S_AXI_WVALID,
input      [  `AXI_DATA_WIDTH-1:0] S_AXI_WDATA,
input      [`AXI_STROBE_WIDTH-1:0] S_AXI_WSTRB,

AXI write response
output reg                         S_AXI_BVALID,
output reg [  `AXI_RESP_WIDTH-1:0] S_AXI_BRESP,
input                              S_AXI_BREADY,

AXI read address
output reg                         S_AXI_ARREADY,
input                              S_AXI_ARVALID,
input      [  `AXI_ADDR_WIDTH-1:0] S_AXI_ARADDR,
input      [  `AXI_PROT_WIDTH-1:0] S_AXI_ARPROT,

AXI read data and response
output reg                         S_AXI_RVALID,
output reg [  `AXI_DATA_WIDTH-1:0] S_AXI_RDATA,
output reg [  `AXI_RESP_WIDTH-1:0] S_AXI_RRESP,
input                              S_AXI_RREADY

"""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotbext.axi import AxiLiteBus, AxiLiteMaster

from tb_utils.constants import *
from tb_utils.resets import reset_active_low


def get_reg_addr(reg: int) -> int:
    """
    Calculate 16-bit AXI address for a specific register
    """

    return SUB_SEL_REGFILE | (reg << 2)


async def regfile_write_monitor(dut, writes_list):
    """
    Catches pulses on regfile_write_enable
    """

    while True:
        await RisingEdge(dut.CLK)
        if dut.regfile_write_enable.value == 1:
            writes_list.append(
                {
                    "addr": int(dut.regfile_addr.value),
                    "data": int(dut.regfile_write_data.value),
                }
            )


async def pc_write_monitor(dut, writes_list):
    """
    Catches pulses on pc_write_enable
    """

    while True:
        await RisingEdge(dut.CLK)
        if dut.pc_write_enable.value == 1:
            writes_list.append(int(dut.pc_write_data.value))


@cocotb.test()
async def test_soc_control(dut):
    cocotb.start_soon(Clock(dut.CLK, 10, unit="ns").start())

    axim = AxiLiteMaster(
        AxiLiteBus.from_prefix(dut, "S_AXI"),
        dut.CLK,
        dut.RSTn,
        reset_active_level=False,  # informs that RSTn is active-low
    )

    reg_writes = []
    pc_writes = []
    cocotb.start_soon(regfile_write_monitor(dut, reg_writes))
    cocotb.start_soon(pc_write_monitor(dut, pc_writes))

    dut.pc_read_data.value = 0
    dut.regfile_read_data.value = 0

    # Reset
    await reset_active_low(dut.RSTn, dut.CLK)
    dut._log.info("Reset complete.")

    dut._log.info("Test 1: Write to Register 4")

    await axim.write_dword(get_reg_addr(4), 0xDEADBEEF)

    assert len(reg_writes) == 1, "DUT did not pulse regfile_write_enable!"
    assert reg_writes[0]["addr"] == 4, "Wrong register address outputted!"
    assert reg_writes[0]["data"] == 0xDEADBEEF, "Wrong register data outputted!"

    dut._log.info("Test 2: Read from Register 8")

    dut.regfile_read_data.value = 0xCAFEBABE  # mock register file returning data back

    read_result = await axim.read_dword(get_reg_addr(8))
    assert (
        read_result == 0xCAFEBABE
    ), f"Expected 0xCAFEBABE, got {hex(read_result.data)}"

    dut._log.info("Test 3: CPU Execution Control")

    # check default status (should be stalled after reset)
    result = await axim.read_dword(SUB_SEL_CTRL | CTRL_REG_STATUS)
    assert result == 1, "CPU should be stalled on reset!"

    # send START command
    await axim.write_dword(SUB_SEL_CTRL | CTRL_REG_START, 0x1)
    await Timer(1, unit="ns")
    assert dut.pc_stall.value == 0, "pc_stall did not de-assert after START command!"

    # send STOP command
    await axim.write_dword(SUB_SEL_CTRL | CTRL_REG_STOP, 0x1)
    await Timer(1, unit="ns")
    assert dut.pc_stall.value == 1, "pc_stall did not assert after STOP command!"

    dut._log.info("Test 4: PC Read and Write")

    await axim.write_dword(SUB_SEL_CTRL | CTRL_REG_PC, 0x0000100C)
    assert len(pc_writes) == 1, "DUT did not pulse pc_write_enable!"
    assert pc_writes[0] == 0x0000100C, "Wrong PC data outputted!"

    dut.pc_read_data.value = 0x00002048  # Mock the PC returning a value
    result = await axim.read_dword(SUB_SEL_CTRL | CTRL_REG_PC)
    assert result == 0x00002048, "Failed to read PC back through AXI!"

    dut._log.info("All SOC Control tests passed!")
