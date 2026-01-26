`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: ISAE
// Engineer: Szymon Bogus
// 
// Create Date: 09/27/2025
// Design Name: 
// Module Name: load_store_decoder
// Project Name: rv32i_sc
// Target Devices: Zybo Z7-20
// Tool Versions: 
// Description: Module decoding what type of w_enb flag bram module should get.
//              It also processes data to send to the memory 
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


module load_store_decoder (
    input  wire [`DATA_WIDTH-1:0]  alu_result_addr,
    input  wire [`FUNC3_WIDTH-1:0] func3,
    input  wire [`DATA_WIDTH-1:0]  reg_read,
    output reg  [3:0]              byte_enb,
    output reg  [`DATA_WIDTH-1:0]  data

);
    wire [1:0] addr_offset = alu_result_addr[1:0];

    always @(*) begin
        case (func3)
            `F3_BYTE, `F3_BYTE_U    : begin // sb, lb, lbu
                case (addr_offset) 
                    2'b00  : begin // 1st byte
                        byte_enb = 4'b0001;
                        data     = reg_read & 32'h000000FF;
                    end

                    2'b01  : begin // 2nd byte
                        byte_enb = 4'b0010;
                        data     = (reg_read & 32'h000000FF) << 8;
                    end

                    2'b10  : begin // 3rd byte
                        byte_enb = 4'b0100;
                        data     = (reg_read & 32'h000000FF) << 16;
                    end

                    2'b11  : begin // 4th byte
                        byte_enb = 4'b1000;
                        data     = (reg_read & 32'h000000FF) << 24;
                    end

                    default: byte_enb = 4'b0000;
                endcase
            end

            `F3_HALF_WORD, `F3_HALF_WORD_U: begin // sh, lh, lhu
                case (addr_offset)
                    2'b00  : begin
                        // lower half word
                        byte_enb = 4'b0011;
                        data     = (reg_read & 32'h0000FFFF);
                    end

                    2'b10  : begin
                        // upper half word
                        byte_enb = 4'b1100;
                        data     = (reg_read & 32'h0000FFFF) << 16;
                    end

                    default       : byte_enb = 4'b0000;
                endcase
            end

            `F3_WORD: begin // lw, sw
                byte_enb = (addr_offset == 2'b00) ? 4'b1111 : 4'b0000;
                data     = reg_read;
            end

            default: byte_enb = 4'b0000;
        endcase
    end

endmodule