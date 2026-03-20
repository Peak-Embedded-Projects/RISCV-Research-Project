`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: ISAE
// Engineer: Szymon Bogus
// 
// Create Date: 05/26/2025 11:21:05 PM
// Design Name: 
// Module Name: register_file
// Project Name: rv32i_sc
// Target Devices: Zybo Z7-20
// Tool Versions: 
// Description: Register file holding 32 general use registers.
//              RISC-V is byte-addressed: in order to store 32x32-bit registers we need an array, each byte is addressed.
//              Next register begins +4 bytes w.r.t the previous one.
// 
// Dependencies: rv32i_params.vh
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
`include "rv32i_params.vh"
`include "cm_commands.vh"


module register_file (
    input CLK,
    input RSTn,

    // READ
    input  wire [`REG_ADDR_WIDTH-1:0] rs1_addr,
    input  wire [`REG_ADDR_WIDTH-1:0] rs2_addr,
    output reg  [    `DATA_WIDTH-1:0] rs1,       // carries value that has been read with rs1_addr
    output reg  [    `DATA_WIDTH-1:0] rs2,       // carries value that has been read with rs2_addr

    // WRITE
    input wire                       write_enable,
    input wire [`REG_ADDR_WIDTH-1:0] write_addr,    // specifies which register to write to
    input wire [    `DATA_WIDTH-1:0] write_data,    // value to write

    // EXTRA (for reading and writing registers from outside the core while it is stopped)
    input      [`REG_ADDR_WIDTH-1:0] extra_addr,
    output reg [    `DATA_WIDTH-1:0] extra_read_data,
    input                            extra_write_enable,
    input      [    `DATA_WIDTH-1:0] extra_write_data,

    // FAULT injection interface
    input                            fault_write_enable,
    input      [`REG_ADDR_WIDTH-1:0] fault_addr,
    input      [`FAULT_MODE_WIDTH-1:0] fault_mode,
    input      [    `DATA_WIDTH-1:0] fault_mask
);

    reg [`DATA_WIDTH-1:0] registers [1:`NUM_REGISTERS-1]; // skipping x0, which is hard-wired to 32'b0

    wire [`DATA_WIDTH-1:0] fault_current_value =
        (fault_addr == `REG_ADDR_WIDTH'b0) ? `DATA_WIDTH'b0 : registers[fault_addr];
    wire [`DATA_WIDTH-1:0] fault_injected_data;

    fault_injector u_fault_injector (
        .current_value (fault_current_value),
        .fault_mask    (fault_mask),
        .fault_mode    (fault_mode),
        .injected_value(fault_injected_data)
    );

    // WRITE
    integer reg_id;
    always @(posedge CLK or negedge RSTn) begin
        if (!RSTn) begin
            // Looping only until 31st register as x0 is always 0x0
            // therefore skipping reg_id=0 (not defined in the array)
            for (reg_id = 1; reg_id < `NUM_REGISTERS; reg_id = reg_id + 1) begin
                registers[reg_id] <= 32'b0;
            end
        end else begin
            if (write_enable && write_addr != `REG_ADDR_WIDTH'b0) begin
                registers[write_addr] <= write_data;
            end else if (extra_write_enable && extra_addr != `REG_ADDR_WIDTH'b0) begin
                registers[extra_addr] <= extra_write_data;
            end else if (fault_write_enable && fault_addr != `REG_ADDR_WIDTH'b0) begin
                registers[fault_addr] <= fault_injected_data;
            end
        end
    end

    always @(*) begin
        rs1 = (rs1_addr == `REG_ADDR_WIDTH'b0) ? 32'h0 : registers[rs1_addr];
        rs2 = (rs2_addr == `REG_ADDR_WIDTH'b0) ? 32'h0 : registers[rs2_addr];
    end

    always @(posedge CLK or negedge RSTn) begin
        if (!RSTn) begin
            extra_read_data <= `DATA_WIDTH'b0;
        end else begin
            extra_read_data <= (extra_addr == `REG_ADDR_WIDTH'b0) ? 32'h0 : registers[extra_addr];
        end
    end

endmodule
