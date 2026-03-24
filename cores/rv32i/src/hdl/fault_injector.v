`timescale 1ns / 1ps

`include "rv32i_params.vh"
`include "cm_commands.vh"

module fault_injector (
    input  wire [    `DATA_WIDTH-1:0] current_value,
    input  wire [    `DATA_WIDTH-1:0] fault_mask,
    input  wire [`FAULT_MODE_WIDTH-1:0] fault_mode,
    output reg  [    `DATA_WIDTH-1:0] injected_value
);

    always @(*) begin
        case (fault_mode)
            `FAULT_MODE_OVERWRITE: injected_value = fault_mask;
            `FAULT_MODE_XOR_MASK:  injected_value = current_value ^ fault_mask;
            `FAULT_MODE_OR_MASK:   injected_value = current_value | fault_mask;
            `FAULT_MODE_ANDN_MASK: injected_value = current_value & (~fault_mask);
        endcase
    end

endmodule