`timescale 1ns / 1ps

`include "axi_configuration.vh"
`include "rv32i_params.vh"

// god I wish we just enums
`define STATE_WIDTH 4
`define STATE_IDLE `STATE_WIDTH'd0
`define STATE_PC_WAIT_ARREADY `STATE_WIDTH'd1
`define STATE_PC_DATA `STATE_WIDTH'd2
`define STATE_L_WAIT_ARREADY `STATE_WIDTH'd3
`define STATE_L_DATA `STATE_WIDTH'd4
`define STATE_S_WAIT_BOTH `STATE_WIDTH'd5
`define STATE_S_WAIT_AWREADY `STATE_WIDTH'd6
`define STATE_S_WAIT_WREADY `STATE_WIDTH'd7
`define STATE_S_RESP `STATE_WIDTH'd8

module memory_arbiter (
    input CLK,
    input RSTn,

    // AXI4-lite connections
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

    // instruction fetching
    input                            pc_valid,
    output reg                       pc_ready,
    input      [`AXI_ADDR_WIDTH-1:0] pc,
    output reg                       instruction_valid,
    input                            instruction_ready,
    output reg [`AXI_DATA_WIDTH-1:0] instruction,

    // load/store
    input                              load_store_valid,
    output wire                        load_store_ready,
    input      [  `AXI_ADDR_WIDTH-1:0] load_store_addr,
    input                              load_store_is_write,
    input      [`AXI_STROBE_WIDTH-1:0] store_strobe,
    input      [  `AXI_DATA_WIDTH-1:0] store_data,
    output reg                         load_store_result_valid,
    input                              load_store_result_ready,
    output reg [      `DATA_WIDTH-1:0] load_data
);

    // state machine
    reg [`STATE_WIDTH-1:0] state;
    reg [`STATE_WIDTH-1:0] next_state;
    always @(*) begin
        next_state = state;
        case (state)
            `STATE_IDLE:
            // Skip address phase for instr fetch, if the slave was ready to receive the address
            if (pc_valid) begin
                if (M_AXI_ARVALID && M_AXI_ARREADY) next_state = `STATE_PC_DATA;
                else next_state = `STATE_PC_WAIT_ARREADY;
            end else if (load_store_valid && load_store_ready) begin
                if (load_store_is_write) next_state = `STATE_S_WAIT_BOTH;
                else next_state = `STATE_L_WAIT_ARREADY;
            end
            `STATE_PC_WAIT_ARREADY: if (M_AXI_ARREADY) next_state = `STATE_PC_DATA;
            `STATE_L_WAIT_ARREADY: if (M_AXI_ARREADY) next_state = `STATE_L_DATA;
            `STATE_S_WAIT_BOTH: begin
                if (M_AXI_AWREADY & M_AXI_WREADY) next_state = `STATE_S_RESP;
                else if (M_AXI_AWREADY) next_state = `STATE_S_WAIT_WREADY;
                else if (M_AXI_WREADY) next_state = `STATE_S_WAIT_AWREADY;
            end
            `STATE_S_WAIT_AWREADY: if (M_AXI_AWREADY) next_state = `STATE_S_RESP;
            `STATE_S_WAIT_WREADY: if (M_AXI_WREADY) next_state = `STATE_S_RESP;
            `STATE_PC_DATA: if (M_AXI_RVALID & instruction_ready) next_state = `STATE_IDLE;
            `STATE_L_DATA: if (M_AXI_RVALID) next_state = `STATE_IDLE;
            `STATE_S_RESP: if (M_AXI_BVALID) next_state = `STATE_IDLE;
        endcase
    end
    always @(posedge CLK or negedge RSTn)
        if (!RSTn) state <= `STATE_IDLE;
        else state <= next_state;

    // Assume for now that the load store inputs stay constant. In priciple
    // we have to latch them on the transaction.

    // AXI Read
    always @(*) begin
        M_AXI_ARVALID = 1'b0;
        M_AXI_ARADDR  = `AXI_ADDR_WIDTH'b0;
        M_AXI_RREADY  = 1'b0;
        M_AXI_ARPROT  = 3'b0;
        case (state)
            `STATE_IDLE: begin
                if (pc_valid) begin
                    // connect pc_valid and pc_ready to AXI_ARREADY and AXI_ARVALID
                    M_AXI_ARVALID = 1'b1;
                    M_AXI_ARADDR  = pc;
                end
            end
            `STATE_PC_WAIT_ARREADY: begin
                M_AXI_ARVALID = 1'b1;
                M_AXI_ARADDR  = pc;
            end
            `STATE_L_WAIT_ARREADY: begin
                M_AXI_ARVALID = 1'b1;
                M_AXI_ARADDR  = load_store_addr;
            end
            `STATE_PC_DATA: begin
                M_AXI_RREADY = instruction_ready;
            end
            `STATE_L_DATA: begin
                M_AXI_RREADY = 1'b1;
            end
        endcase
    end

    // PC / instruction
    always @(*) begin
        pc_ready          = 1'b0;
        instruction_valid = 1'b0;
        instruction       = `AXI_DATA_WIDTH'b0;
        case (state)
            `STATE_IDLE: begin
                if (pc_valid) begin
                    // connect pc_valid and pc_ready to AXI_ARREADY and AXI_ARVALID
                    pc_ready = M_AXI_ARREADY;
                end
            end
            `STATE_PC_WAIT_ARREADY: begin
                pc_ready = M_AXI_ARREADY;
            end
            `STATE_PC_DATA: begin
                instruction_valid = M_AXI_RVALID;
                instruction = M_AXI_RDATA;
            end
        endcase
    end

    // AXI Write
    always @(*) begin
        M_AXI_AWVALID = 1'b0;
        M_AXI_AWADDR  = `AXI_ADDR_WIDTH'b0;
        M_AXI_AWPROT  = 3'b0;
        M_AXI_WVALID  = 1'b0;
        M_AXI_WDATA   = `AXI_DATA_WIDTH'b0;
        M_AXI_WSTRB   = `AXI_STROBE_WIDTH'b0;
        M_AXI_BREADY  = 1'b0;
        case (state)
            `STATE_S_WAIT_BOTH: begin
                M_AXI_AWVALID = 1'b1;
                M_AXI_AWADDR  = load_store_addr;
                M_AXI_WVALID  = 1'b1;
                M_AXI_WDATA   = store_data;
                M_AXI_WSTRB   = store_strobe;
            end
            `STATE_S_WAIT_AWREADY: begin
                M_AXI_AWVALID = 1'b1;
                M_AXI_AWADDR  = load_store_addr;
            end
            `STATE_S_WAIT_WREADY: begin
                M_AXI_WVALID = 1'b1;
                M_AXI_WDATA  = store_data;
                M_AXI_WSTRB  = store_strobe;
            end
            `STATE_S_RESP: begin
                M_AXI_BREADY = 1'b1;
            end
        endcase
    end

    // Load store
    assign load_store_ready = (state == `STATE_IDLE) && (!pc_valid);
    always @(posedge CLK or negedge RSTn)
        if (!RSTn) begin
            load_store_result_valid <= 1'b0;
            load_data <= `AXI_DATA_WIDTH'b0;
        end else begin
            if (state == `STATE_L_DATA && next_state == `STATE_IDLE) begin
                load_store_result_valid <= 1'b1;
                load_data <= M_AXI_RDATA;
            end else if (state == `STATE_S_RESP && next_state == `STATE_IDLE) begin
                load_store_result_valid <= 1'b1;
            end else begin
                load_store_result_valid <= 1'b0;
            end
        end

endmodule
