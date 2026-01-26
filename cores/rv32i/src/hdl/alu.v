`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: ISAE
// Engineer: Szymon Bogus
// 
// Create Date: 06/13/2025 05:19:21 PM
// Design Name: 
// Module Name: alu
// Project Name: rv32i_sc
// Target Devices: Zybo Z7-20
// Tool Versions: 
// Description: ALU with IGNORED overflow detection.
// 
// Dependencies: rv32i_params.vh, rv32i_control.vh
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
`include "rv32i_params.vh"
`include "rv32i_control.vh"


module alu(
    input  wire [`ALU_CTRL_WIDTH-1:0] alu_ctrl,     // alu opcode provided by the instr decode
    input  wire [`INSTR_WIDTH-1:0]    src1,         // 1st source
    input  wire [`INSTR_WIDTH-1:0]    src2,         // 2nd source
    output reg  [`INSTR_WIDTH-1:0]    result,
    output wire                       take_branch // comparison result (for branch evaluation)
);

    wire [4:0] shamt         = src2[4:0];

    wire eq  = src1 == src2;
    wire lt  = $signed(src1) < $signed(src2);
    wire ltu = src1 < src2;

    always @(*) begin
        if (alu_ctrl[4] == 1'b0) begin // OP, OP-IMM
            case (alu_ctrl[2:0])
                `F3_ADD_SUB:
                    if (!alu_ctrl[3]) result = src1 + src2;
                    else              result = src1 - src2;
                `F3_AND:              result = src1 & src2;
                `F3_OR:               result = src1 | src2;
                `F3_XOR:              result = src1 ^ src2;
                `F3_SLTI:             result = {31'b0, lt};
                `F3_SLTIU:            result = {31'b0, ltu};
                `F3_SLL:              result = src1 << shamt;
                `F3_SRL_SRA:
                    if (!alu_ctrl[3]) result = src1 >> shamt;
                    else              result = $signed(src1) >>> shamt;
                default:              result = 32'h0;
            endcase
        end else if (alu_ctrl[3] == 1'b0) begin // BRANCH
            case (alu_ctrl[2:0])
                `F3_BEQ:              result = {31'b0,  eq};
                `F3_BNE:              result = {31'b0, ~eq};
                `F3_BLT:              result = {31'b0,  lt};
                `F3_BGE:              result = {31'b0, ~lt};
                `F3_BLTU:             result = {31'b0,  ltu};
                `F3_BGEU:             result = {31'b0, ~ltu};
                default:              result = 32'h0;
            endcase
        end else                      result = 32'h0;
    end

    assign take_branch = result[0];

endmodule
