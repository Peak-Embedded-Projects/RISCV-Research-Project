`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: ISAE
// Engineer: Szymon Bogus
// 
// Create Date: 09/27/2025
// Design Name: 
// Module Name: byte_reader
// Project Name: rv32i_sc
// Target Devices: Zybo Z7-20
// Tool Versions: 
// Description: Module interpreting load commands for byte operations.
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


module byte_reader (
    input  wire [`DATA_WIDTH-1:0]  mem_data,  // from data_bram_output
    input  wire [`FUNC3_WIDTH-1:0] func3,
    input  wire [3:0]              byte_mask, // from load_store_decoder
    output reg  [`DATA_WIDTH-1:0]  wb_data,   // processed data to be written back to regfile
    output reg                     valid      // high when at least one byte in byte_mask is high

);
    wire sign_ext = ~func3[2]; // 3rd bit of func3 for byte loads informs about it

    reg [`DATA_WIDTH-1:0] masked_data;
    reg [`DATA_WIDTH-1:0] shifted_data;

    // masking data according to byte mask
    integer i;
    always @(*) begin
        for (i = 0; i < 4; i = i + 1) begin
            if (byte_mask[i] == 1'b1) begin
                masked_data[(i*8)+:8] = mem_data[(i*8)+:8];
            end else begin
                masked_data[(i*8)+:8] = 8'h0;
            end
        end
    end
    

    // shifting data
    always @(*) begin
        case (func3)
            `F3_WORD                 : shifted_data = masked_data;

            `F3_BYTE, `F3_BYTE_U     : begin // lb, lbu
                case (byte_mask)
                    4'b0001: shifted_data = masked_data;
                    4'b0010: shifted_data = masked_data >> 8;
                    4'b0100: shifted_data = masked_data >> 16;
                    4'b1000: shifted_data = masked_data >> 24;
                endcase
            end

            `F3_HALF_WORD, `F3_HALF_WORD_U: begin // lh, lhu
                case (byte_mask)
                    4'b0011: shifted_data = masked_data;
                    4'b1100: shifted_data = masked_data >> 16;
                endcase
            end
        endcase
    end

    // sign extending
    always @(*) begin
        case (func3)
            `F3_WORD:                       wb_data = shifted_data; // lw
            `F3_BYTE, `F3_BYTE_U:           wb_data = sign_ext ? {{24{shifted_data[7]}},shifted_data[7:0]}   : shifted_data; // lb, lbu
            `F3_HALF_WORD, `F3_HALF_WORD_U: wb_data = sign_ext ? {{16{shifted_data[15]}},shifted_data[15:0]} : shifted_data; // lh, lhu
        endcase
        valid = | byte_mask;
    end

endmodule