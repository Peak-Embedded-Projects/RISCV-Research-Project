"""
Memory Arbiter test:
AXI4-lite connections
output reg                         M_AXI_AWVALID,
input                              M_AXI_AWREADY,
output reg [  `AXI_ADDR_WIDTH-1:0] M_AXI_AWADDR,
output reg [  `AXI_PROT_WIDTH-1:0] M_AXI_AWPROT,
output reg                         M_AXI_WVALID,
input                              M_AXI_WREADY,
output reg [  `AXI_DATA_WIDTH-1:0] M_AXI_WDATA,
output reg [`AXI_STROBE_WIDTH-1:0] M_AXI_WSTRB,
input                              M_AXI_BVALID,
output reg                         M_AXI_BREADY,
input      [  `AXI_RESP_WIDTH-1:0] M_AXI_BRESP,
output reg                         M_AXI_ARVALID,
input                              M_AXI_ARREADY,
output reg [  `AXI_ADDR_WIDTH-1:0] M_AXI_ARADDR,
output reg [  `AXI_PROT_WIDTH-1:0] M_AXI_ARPROT,
input                              M_AXI_RVALID,
output reg                         M_AXI_RREADY,
input      [  `AXI_DATA_WIDTH-1:0] M_AXI_RDATA,
input      [  `AXI_RESP_WIDTH-1:0] M_AXI_RRESP,

instruction fetching
input                            pc_valid,
output reg                       pc_ready,
input      [`AXI_ADDR_WIDTH-1:0] pc,
output reg                       instruction_valid,
input                            instruction_ready,
output reg [`AXI_DATA_WIDTH-1:0] instruction,

load/store
input                              load_store_valid,
output wire                        load_store_ready,
input      [  `AXI_ADDR_WIDTH-1:0] load_store_addr,
input                              load_store_is_write,
input      [`AXI_STROBE_WIDTH-1:0] store_strobe,
input      [  `AXI_DATA_WIDTH-1:0] store_data,
output reg                         load_store_result_valid,
input                              load_store_result_ready,
output reg [      `DATA_WIDTH-1:0] load_data

"""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, ReadOnly
from cocotbext.axi import AxiLiteBus, AxiLiteRam

from tb_utils.constants import *
from tb_utils.resets import reset_active_low


async def fetch_driver(dut, address) -> int:
    """
    Mocking the core requesting an instruction fetch
    """

    await RisingEdge(dut.CLK)
    dut.pc.value = address
    dut.pc_valid.value = 1

    while True:
        await ReadOnly()  # wait untill all combinatorial logic is settled
        if dut.pc_ready.value == 1:
            await RisingEdge(dut.CLK)
            break
        await RisingEdge(dut.CLK)

    dut.pc_valid.value = 0
    dut.instruction_ready.value = 1

    while True:
        await ReadOnly()
        if dut.instruction_valid.value == 1:
            fetched_instruction = int(dut.instruction.value)
            await RisingEdge(dut.CLK)
            break
        await RisingEdge(dut.CLK)

    dut.instruction_ready.value = 0

    dut._log.info(
        f"[Fetch Driver] Successfully fetched {hex(fetched_instruction)} from PC {hex(address)}"
    )

    return fetched_instruction


async def load_store_driver(dut, is_write, address, data, strobe) -> int:
    await RisingEdge(dut.CLK)

    dut.load_store_addr.value = address
    dut.load_store_is_write.value = 1 if is_write else 0
    dut.store_data.value = data
    dut.store_strobe.value = strobe

    dut.load_store_valid.value = 1

    while True:
        await ReadOnly()
        if dut.load_store_ready.value == 1:
            await RisingEdge(dut.CLK)
            break
        await RisingEdge(dut.CLK)

    dut.load_store_valid.value = 0

    dut.load_store_result_ready.value = 1

    loaded_data = 0

    while True:
        await ReadOnly()
        if dut.load_store_result_valid.value == 1:

            if not is_write:
                loaded_data = int(dut.load_data.value)

            await RisingEdge(dut.CLK)
            break
        await RisingEdge(dut.CLK)

    dut.load_store_result_ready.value = 0

    op_name = "STORE" if is_write else "LOAD"
    val_str = f" Data: {hex(data)}" if is_write else f" Got: {hex(loaded_data)}"
    dut._log.info(f"[{op_name} Driver] Addr: {hex(address)} |{val_str}")

    return loaded_data


@cocotb.test()
async def test_memory_arbiter(dut):
    dut.pc_valid.value = 0
    dut.pc.value = 0
    dut.instruction_ready.value = 0

    dut.load_store_valid.value = 0
    dut.load_store_addr.value = 0
    dut.load_store_is_write.value = 0
    dut.store_data.value = 0
    dut.store_strobe.value = 0
    dut.load_store_result_ready.value = 0

    cocotb.start_soon(Clock(dut.CLK, 10, unit="ns").start())
    await Timer(
        1, unit="step"
    )  # freeze python and let initialization propagate through one step

    ram = AxiLiteRam(
        AxiLiteBus.from_prefix(dut, "M_AXI"),
        dut.CLK,
        dut.RSTn,
        reset_active_level=False,
        size=2**12,
    )

    ram.write(0x100, b"\x11\x22\x33\x44")

    await reset_active_low(dut.RSTn, dut.CLK)

    fetch_task = cocotb.start_soon(fetch_driver(dut, address=0x100))
    store_task = cocotb.start_soon(
        load_store_driver(
            dut, is_write=True, address=0x200, data=0xDEADBEEF, strobe=0xF
        )
    )

    # both instruction fetch and store task are run
    # simultaneously and the goal is to prove that
    # an instruction fetch has a priority over load/store task
    instruction = await fetch_task
    await store_task

    assert instruction == 0x44332211  # little-endian assumed

    stored_bytes = ram.read(0x200, 4)
    assert stored_bytes == b"\xef\xbe\xad\xde"
