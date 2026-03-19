"""
ALU test:
ALU inputs
reg  [`ALU_CTRL_WIDTH-1:0] alu_ctrl;
reg  [`DATA_WIDTH-1:0]     src1;
reg  [`DATA_WIDTH-1:0]     src2;

ALU outputs
wire [`DATA_WIDTH-1:0]     result;
wire                       take_branch;

"""

import cocotb
from cocotb.triggers import Timer

from tb_utils.logging import log_alu_result
from tb_utils.bitops import get_alu_ctrl, to_32b
from tb_utils.constants import *


@cocotb.test()
async def test_alu_combinational(dut):

    dut.alu_ctrl.value = 0
    dut.src1.value = 0
    dut.src2.value = 0

    dut._log.info("Test 1: Reset / NOP state")
    await Timer(10, unit="ns")
    dut.alu_ctrl.value = 0  # NOP
    await Timer(1, unit="ns")
    assert dut.result.value == 0, f"Reset state failed, got {dut.result.value.hex()}"
    log_alu_result(dut)
    
    test_cases = [
        # ALU OP tests
        {
            "name": "ADD",
            "ctrl": get_alu_ctrl(0, 0, F3_ADD_SUB),
            "src1": 10,
            "src2": 20,
            "exp": 30,
        },
        {
            "name": "SUB",
            "ctrl": get_alu_ctrl(0, 1, F3_ADD_SUB),
            "src1": 50,
            "src2": 20,
            "exp": 30,
        },
        {
            "name": "AND",   
            "ctrl": get_alu_ctrl(0, 0, F3_AND), 
            "src1": 0xFF00FF00, 
            "src2": 0x0F0F0F0F, 
            "exp": 0x0F000F00
        },
        {
            "name": "OR",    
            "ctrl": get_alu_ctrl(0, 0, F3_OR),  
            "src1": 0xFF00FF00, 
            "src2": 0x0F0F0F0F, 
            "exp":  0xFF0FFF0F
        },
        {
            "name": "XOR",   
            "ctrl": get_alu_ctrl(0, 0, F3_XOR), 
            "src1": 0xAAAA5555, 
            "src2": 0xFFFF0000, 
            "exp": 0x55555555
        },        
        {
            "name": "SLL",
            "ctrl": get_alu_ctrl(0, 0, F3_SLL),
            "src1": 1,
            "src2": 4,
            "exp": 0x10,
        },
        {
            "name": "SRL",
            "ctrl": get_alu_ctrl(0, 0, F3_SRL_SRA),
            "src1": 0xFFFFFF80,
            "src2": 4,
            "exp": 0x0FFFFFF8,
        },
        {
            "name": "SRA",
            "ctrl": get_alu_ctrl(0, 1, F3_SRL_SRA),
            "src1": 0xFFFFFF80,
            "src2": 4,
            "exp": 0xFFFFFFF8,
        },
        {
            "name": "SLTI",
            "ctrl": get_alu_ctrl(0, 0, F3_SLTI),
            "src1": to_32b(-5),
            "src2": 7,
            "exp": 1,
        },
        {
            "name": "SLTIU",
            "ctrl": get_alu_ctrl(0, 0, F3_SLTIU),
            "src1": 0xFFFFFFFE,
            "src2": 1,
            "exp": 0,
        },
        # BRANCH tests
        {
            "name": "BEQ",
            "ctrl": get_alu_ctrl(1, 0, F3_BEQ),
            "src1": 0xA5A5A5A5,
            "src2": 0xA5A5A5A5,
            "exp": 1,
        },
        {
            "name": "BNE",
            "ctrl": get_alu_ctrl(1, 0, F3_BNE),
            "src1": 0x1234,
            "src2": 0x4321,
            "exp": 1,
        },
        {
            "name": "BLT",
            "ctrl": get_alu_ctrl(1, 0, F3_BLT),
            "src1": to_32b(-5),
            "src2": 7,
            "exp": 1,
        },
        {
            "name": "BGE",
            "ctrl": get_alu_ctrl(1, 0, F3_BGE),
            "src1": to_32b(-5),
            "src2": 7,
            "exp": 0,
        },
        {
            "name": "BLTU",
            "ctrl": get_alu_ctrl(1, 0, F3_BLTU),
            "src1": 1,
            "src2": 2,
            "exp": 1,
        },
        {
            "name": "BGEU",
            "ctrl": get_alu_ctrl(1, 0, F3_BGEU),
            "src1": 2,
            "src2": 1,
            "exp": 1,
        },
    ]

    for tc in test_cases:
        dut.alu_ctrl.value = tc["ctrl"]
        dut.src1.value = tc["src1"]
        dut.src2.value = tc["src2"]

        await Timer(1, unit="ns")
        dut._log.info(f"Test {tc["name"]:<5}")
        log_alu_result(dut)

        # using integer comparison by grabbing the integer value of the signal
        actual_result = dut.result.value.integer
        assert (
            actual_result == tc["exp"]
        ), f"[{tc['name']} ERROR] expected {hex(tc['exp'])}, got {hex(actual_result)}"

    dut._log.info("All ALU tests completed successfully!")
