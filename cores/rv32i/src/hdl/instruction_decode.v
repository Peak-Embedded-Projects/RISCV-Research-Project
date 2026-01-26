`timescale 1ns / 1ps

`include "rv32i_params.vh"
`include "rv32i_control.vh"


module instruction_decode (
    input [`INSTR_WIDTH-1:0] instr,

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
);
    wire   [`OPCODE_WIDTH-1:0]    opcode;
    reg has_rs1;
    reg has_rs2;
    reg has_rd;
    reg has_func3;
    reg has_func7;
    
    reg [`INSTR_TYPE_WIDTH-1:0] instr_type;

    assign use_mem         = (opcode == `OPCODE_LOAD) || (opcode == `OPCODE_STORE);
    assign mem_is_write    = (opcode == `OPCODE_STORE);
    assign is_branch       = (opcode == `OPCODE_BRANCH);
    assign is_jump         = (opcode == `OPCODE_JAL) || (opcode == `OPCODE_JALR);
    assign is_jalr         = (opcode == `OPCODE_JALR);
    assign alu_src1_is_pc  = (opcode == `OPCODE_AUIPC);
    assign alu_src2_is_imm = (instr_type != `INSTR_TYPE_R) && (instr_type != `INSTR_TYPE_B);
    assign do_write_back   = has_rd;

    // Extract parts of the instruction
    assign opcode          = instr[6:0];
    assign rs1_addr        = has_rs1 ? instr[19:15] : 5'b0;
    assign rs2_addr        = has_rs2 ? instr[24:20] : 5'b0;
    assign rd_addr         = do_write_back ? instr[11:7] : 5'b0;
    assign func3           = has_func3 ? instr[14:12] : 3'b0;
    assign func7           = has_func7 ? instr[31:25] : 7'b0;

    // Opcode decoder, determine instruction type
    always @(*) begin
        case (opcode)
            `OPCODE_LOAD, `OPCODE_OP_IMM, `OPCODE_JALR: instr_type = `INSTR_TYPE_I;
            `OPCODE_AUIPC, `OPCODE_LUI:                 instr_type = `INSTR_TYPE_U;
            `OPCODE_STORE:                              instr_type = `INSTR_TYPE_S;
            `OPCODE_OP:                                 instr_type = `INSTR_TYPE_R;
            `OPCODE_BRANCH:                             instr_type = `INSTR_TYPE_B;
            `OPCODE_JAL:                                instr_type = `INSTR_TYPE_J;
            default:                                    instr_type = `INSTR_TYPE_INVALID;
        endcase
    end

    // assign has_[rs1, rs2, rd, func3, func7] based on instruction type
    always @(*)
        case (instr_type)
            `INSTR_TYPE_R, `INSTR_TYPE_I, `INSTR_TYPE_S, `INSTR_TYPE_B: has_rs1 = 1'b1;
            default:                                                    has_rs1 = 1'b0;
        endcase
    always @(*)
        case (instr_type)
            `INSTR_TYPE_R, `INSTR_TYPE_S, `INSTR_TYPE_B: has_rs2 = 1'b1;
            default:                                     has_rs2 = 1'b0;
        endcase
    always @(*)
        case (instr_type)
            `INSTR_TYPE_R, `INSTR_TYPE_I, `INSTR_TYPE_U, `INSTR_TYPE_J: has_rd = 1'b1;
            default:                                                    has_rd = 1'b0;
        endcase
    always @(*)
        case (instr_type)
            `INSTR_TYPE_R, `INSTR_TYPE_I, `INSTR_TYPE_S, `INSTR_TYPE_B: has_func3 = 1'b1;
            default:                                                    has_func3 = 1'b0;
        endcase
    always @(*)
        case (instr_type)
            `INSTR_TYPE_R: has_func7 = 1'b1;
            `INSTR_TYPE_I:
            if (opcode == `OPCODE_OP_IMM && func3 == `F3_SRL_SRA) has_func7 = 1'b1;
            else has_func7 = 1'b0;
            default: has_func7 = 1'b0;
        endcase

    // Construct and sign extend immediate based on instruction type
    always @(*) begin
        case (instr_type)
            `INSTR_TYPE_R: imm = 32'b0;
            `INSTR_TYPE_I: imm = {{20{instr[31]}}, instr[31:20]};
            `INSTR_TYPE_S: imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};
            `INSTR_TYPE_B: imm = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0};
            `INSTR_TYPE_U: imm = {instr[31:12], 12'b0};
            `INSTR_TYPE_J: imm = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0};
            `INSTR_TYPE_INVALID: imm = 32'b0;
            default: imm = 32'b0;
        endcase
    end

    // ALU control
    // alu_ctrl[4] distinguishes OP/OP-IMM and BRANCH
    // alu_ctrl[3] distinguishes ADD-SUB or SRA-SRL
    // alu_ctrl[2:0] is func3
    always @(*) begin
        case (opcode)
            `OPCODE_LOAD, `OPCODE_STORE: alu_ctrl = `ALU_CTRL_ADD;
            `OPCODE_LUI, `OPCODE_AUIPC:  alu_ctrl = `ALU_CTRL_ADD;
            `OPCODE_OP, `OPCODE_OP_IMM:  alu_ctrl = {1'b0, (func7 == `F7_SUB), func3};
            `OPCODE_BRANCH:              alu_ctrl = {1'b1, 1'b0, func3};
            `OPCODE_JAL, `OPCODE_JALR:   alu_ctrl = `ALU_CTRL_NOP;
            default:                     alu_ctrl = `ALU_CTRL_NOP;
        endcase
    end

endmodule
