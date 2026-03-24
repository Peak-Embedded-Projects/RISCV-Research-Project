"""
Instruction Decode Test:
Instruction Decode input
input [`INSTR_WIDTH-1:0] instr,

Instruction decode output
output     [   `FUNC3_WIDTH-1:0] func3,
output     [   `FUNC7_WIDTH-1:0] func7,
output     [`REG_ADDR_WIDTH-1:0] rs1_addr,
output     [`REG_ADDR_WIDTH-1:0] rs2_addr,
output     [`REG_ADDR_WIDTH-1:0] rd_addr,
output reg [    `DATA_WIDTH-1:0] imm,
output                           alu_src1_is_pc,
output                           alu_src2_is_imm,
output                           use_mem,
output                           is_branch,
output                           is_jump,
output                           is_jalr,
output                           mem_is_write,
output                           do_write_back,
output reg [`ALU_CTRL_WIDTH-1:0] alu_ctrl

"""

import cocotb
from cocotb.triggers import Timer

from tb_utils.constants import *
from tb_utils.bitops import (
    to_32b,
    build_btype,
    build_itype,
    build_jtype,
    build_rtype,
    build_stype,
    build_utype,
)


@cocotb.test()
async def test_instruction_decode(dut):

    def default_expect():
        return {
            "rs1_addr": 0,
            "rs2_addr": 0,
            "rd_addr": 0,
            "imm": 0,
            "alu_src1_is_pc": 0,
            "alu_src2_is_imm": 0,
            "use_mem": 0,
            "is_branch": 0,
            "is_jump": 0,
            "is_jalr": 0,
            "mem_is_write": 0,
            "do_write_back": 0,
            "alu_ctrl": 0,
        }

    test_cases = [
        # R-Type: add x1, x2, x3
        {
            "name": "ADD (R-Type)",
            "instr": build_rtype(F7_ADD_AND_OR, 3, 2, F3_ADD_SUB, 1, OPCODE_OP),
            "exp": {
                **default_expect(),
                "rs1_addr": 2,
                "rs2_addr": 3,
                "rd_addr": 1,
                "do_write_back": 1,
                "alu_ctrl": F3_ADD_SUB,
            },
        },
        # I-Type (ALU): addi x4, x5, -15
        {
            "name": "ADDI (I-Type)",
            "instr": build_itype(-15, 5, F3_ADD_SUB, 4, OPCODE_OP_IMM),
            "exp": {
                **default_expect(),
                "rs1_addr": 5,
                "rd_addr": 4,
                "imm": to_32b(-15),
                "alu_src2_is_imm": 1,
                "do_write_back": 1,
                "alu_ctrl": F3_ADD_SUB,
            },
        },
        # I-Type (Load): lw x6, 4(x7)
        {
            "name": "LW (I-Type)",
            "instr": build_itype(4, 7, F3_WORD, 6, OPCODE_LOAD),
            "exp": {
                **default_expect(),
                "rs1_addr": 7,
                "rd_addr": 6,
                "imm": 4,
                "alu_src2_is_imm": 1,
                "use_mem": 1,
                "do_write_back": 1,
                "alu_ctrl": F3_ADD_SUB,
            },
        },
        # S-Type: sw x8, 16(x9)
        {
            "name": "SW (S-Type)",
            "instr": build_stype(16, 8, 9, F3_WORD, OPCODE_STORE),
            "exp": {
                **default_expect(),
                "rs1_addr": 9,
                "rs2_addr": 8,
                "imm": 16,
                "alu_src2_is_imm": 1,
                "use_mem": 1,
                "mem_is_write": 1,
                "alu_ctrl": F3_ADD_SUB,
            },
        },
        # B-Type: beq x10, x11, -8
        {
            "name": "BEQ (B-Type)",
            "instr": build_btype(-8, 11, 10, F3_BEQ, OPCODE_BRANCH),
            "exp": {
                **default_expect(),
                "rs1_addr": 10,
                "rs2_addr": 11,
                "imm": to_32b(-8),
                "is_branch": 1,
                "alu_ctrl": (1 << 4) | F3_BEQ,
            },
        },
        # U-Type: lui x12, 0x12345000
        {
            "name": "LUI (U-Type)",
            "instr": build_utype(0x12345000, 12, OPCODE_LUI),
            "exp": {
                **default_expect(),
                "rd_addr": 12,
                "imm": 0x12345000,
                "alu_src2_is_imm": 1,
                "do_write_back": 1,
                "alu_ctrl": F3_ADD_SUB,
            },
        },
        # J-Type: jal x13, 32
        {
            "name": "JAL (J-Type)",
            "instr": build_jtype(32, 13, OPCODE_JAL),
            "exp": {
                **default_expect(),
                "rd_addr": 13,
                "imm": 32,
                "is_jump": 1,
                "alu_src2_is_imm": 1,
                "do_write_back": 1,
                "alu_ctrl": ALU_CTRL_NOP,
            },
        },
    ]

    for tc in test_cases:
        dut._log.info(f"Running {tc['name']}...")

        dut.instr.value = tc["instr"]

        await Timer(1, unit="ns")

        exp = tc["exp"]

        def check_val(signal, exp_val, name):
            actual = int(signal.value)
            assert (
                actual == exp_val
            ), f"[{tc['name']}] {name} mismatch! Exp: {hex(exp_val)}, Got: {hex(actual)}"

        check_val(dut.rs1_addr, exp["rs1_addr"], "rs1_addr")
        check_val(dut.rs2_addr, exp["rs2_addr"], "rs2_addr")
        check_val(dut.rd_addr, exp["rd_addr"], "rd_addr")
        check_val(dut.imm, exp["imm"], "imm")

        check_val(dut.alu_src1_is_pc, exp["alu_src1_is_pc"], "alu_src1_is_pc")
        check_val(dut.alu_src2_is_imm, exp["alu_src2_is_imm"], "alu_src2_is_imm")
        check_val(dut.use_mem, exp["use_mem"], "use_mem")
        check_val(dut.is_branch, exp["is_branch"], "is_branch")
        check_val(dut.is_jump, exp["is_jump"], "is_jump")
        check_val(dut.is_jalr, exp["is_jalr"], "is_jalr")
        check_val(dut.mem_is_write, exp["mem_is_write"], "mem_is_write")
        check_val(dut.do_write_back, exp["do_write_back"], "do_write_back")
        check_val(dut.alu_ctrl, exp["alu_ctrl"], "alu_ctrl")

    dut._log.info("All decoding tests passed perfectly!")
