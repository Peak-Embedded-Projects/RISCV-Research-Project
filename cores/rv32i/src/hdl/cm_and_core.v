`timescale 1ns / 1ps

`include "rv32i_params.vh"
`include "rv32i_control.vh"
`include "axi_configuration.vh"

module cm_and_core (
    input CLK,
    input RSTn,

    // AXI 4 Lite connection to the control module
    input                          S_AXI_AWVALID,
    output                         S_AXI_AWREADY,
    input  [  `AXI_ADDR_WIDTH-1:0] S_AXI_AWADDR,
    input  [  `AXI_PROT_WIDTH-1:0] S_AXI_AWPROT,
    input                          S_AXI_WVALID,
    output                         S_AXI_WREADY,
    input  [  `AXI_DATA_WIDTH-1:0] S_AXI_WDATA,
    input  [`AXI_STROBE_WIDTH-1:0] S_AXI_WSTRB,
    output                         S_AXI_BVALID,
    input                          S_AXI_BREADY,
    output [  `AXI_RESP_WIDTH-1:0] S_AXI_BRESP,
    input                          S_AXI_ARVALID,
    output                         S_AXI_ARREADY,
    input  [  `AXI_ADDR_WIDTH-1:0] S_AXI_ARADDR,
    input  [  `AXI_PROT_WIDTH-1:0] S_AXI_ARPROT,
    output                         S_AXI_RVALID,
    input                          S_AXI_RREADY,
    output [  `AXI_DATA_WIDTH-1:0] S_AXI_RDATA,
    output [  `AXI_RESP_WIDTH-1:0] S_AXI_RRESP,

    // AXI 4 Lite connection from the core the memory
    output                         M_AXI_AWVALID,
    input                          M_AXI_AWREADY,
    output [  `AXI_ADDR_WIDTH-1:0] M_AXI_AWADDR,
    output [  `AXI_PROT_WIDTH-1:0] M_AXI_AWPROT,
    output                         M_AXI_WVALID,
    input                          M_AXI_WREADY,
    output [  `AXI_DATA_WIDTH-1:0] M_AXI_WDATA,
    output [`AXI_STROBE_WIDTH-1:0] M_AXI_WSTRB,
    input                          M_AXI_BVALID,
    output                         M_AXI_BREADY,
    input  [  `AXI_RESP_WIDTH-1:0] M_AXI_BRESP,
    output                         M_AXI_ARVALID,
    input                          M_AXI_ARREADY,
    output [  `AXI_ADDR_WIDTH-1:0] M_AXI_ARADDR,
    output [  `AXI_PROT_WIDTH-1:0] M_AXI_ARPROT,
    input                          M_AXI_RVALID,
    output                         M_AXI_RREADY,
    input  [  `AXI_DATA_WIDTH-1:0] M_AXI_RDATA,
    input  [  `AXI_RESP_WIDTH-1:0] M_AXI_RRESP
);

    // connections between control module and RISC-V core
    wire                       cm_pc_stall;
    wire [    `DATA_WIDTH-1:0] cm_pc_read_data;
    wire                       cm_pc_write_enable;
    wire [    `DATA_WIDTH-1:0] cm_pc_write_data;
    wire [`REG_ADDR_WIDTH-1:0] cm_regfile_addr;
    wire [    `DATA_WIDTH-1:0] cm_regfile_read_data;
    wire                       cm_regfile_write_enable;
    wire [    `DATA_WIDTH-1:0] cm_regfile_write_data;

    // Control Module
    soc_control u_soc_control (
        .CLK (CLK),
        .RSTn(RSTn),

        .S_AXI_AWVALID(S_AXI_AWVALID),
        .S_AXI_AWREADY(S_AXI_AWREADY),
        .S_AXI_AWADDR (S_AXI_AWADDR),
        .S_AXI_AWPROT (S_AXI_AWPROT),
        .S_AXI_WVALID (S_AXI_WVALID),
        .S_AXI_WREADY (S_AXI_WREADY),
        .S_AXI_WDATA  (S_AXI_WDATA),
        .S_AXI_WSTRB  (S_AXI_WSTRB),
        .S_AXI_BVALID (S_AXI_BVALID),
        .S_AXI_BREADY (S_AXI_BREADY),
        .S_AXI_BRESP  (S_AXI_BRESP),
        .S_AXI_ARVALID(S_AXI_ARVALID),
        .S_AXI_ARREADY(S_AXI_ARREADY),
        .S_AXI_ARADDR (S_AXI_ARADDR),
        .S_AXI_ARPROT (S_AXI_ARPROT),
        .S_AXI_RVALID (S_AXI_RVALID),
        .S_AXI_RREADY (S_AXI_RREADY),
        .S_AXI_RDATA  (S_AXI_RDATA),
        .S_AXI_RRESP  (S_AXI_RRESP),

        .pc_stall(cm_pc_stall),
        .pc_read_data(cm_pc_read_data),
        .pc_write_enable(cm_pc_write_enable),
        .pc_write_data(cm_pc_write_data),
        .regfile_addr(cm_regfile_addr),
        .regfile_read_data(cm_regfile_read_data),
        .regfile_write_enable(cm_regfile_write_enable),
        .regfile_write_data(cm_regfile_write_data)
    );


    // CPU
    riscv_cpu u_cpu (
        .CLK (CLK),
        .RSTn(RSTn),

        .M_AXI_AWVALID(M_AXI_AWVALID),
        .M_AXI_AWREADY(M_AXI_AWREADY),
        .M_AXI_AWADDR (M_AXI_AWADDR),
        .M_AXI_AWPROT (M_AXI_AWPROT),
        .M_AXI_WVALID (M_AXI_WVALID),
        .M_AXI_WREADY (M_AXI_WREADY),
        .M_AXI_WDATA  (M_AXI_WDATA),
        .M_AXI_WSTRB  (M_AXI_WSTRB),
        .M_AXI_BVALID (M_AXI_BVALID),
        .M_AXI_BREADY (M_AXI_BREADY),
        .M_AXI_BRESP  (M_AXI_BRESP),
        .M_AXI_ARVALID(M_AXI_ARVALID),
        .M_AXI_ARREADY(M_AXI_ARREADY),
        .M_AXI_ARADDR (M_AXI_ARADDR),
        .M_AXI_ARPROT (M_AXI_ARPROT),
        .M_AXI_RVALID (M_AXI_RVALID),
        .M_AXI_RREADY (M_AXI_RREADY),
        .M_AXI_RDATA  (M_AXI_RDATA),
        .M_AXI_RRESP  (M_AXI_RRESP),

        .cm_pc_stall(cm_pc_stall),
        .cm_pc_read_data(cm_pc_read_data),
        .cm_pc_we(cm_pc_write_enable),
        .cm_pc_write_data(cm_pc_write_data),
        .cm_regfile_addr(cm_regfile_addr),
        .cm_regfile_read_data(cm_regfile_read_data),
        .cm_regfile_we(cm_regfile_write_enable),
        .cm_regfile_write_data(cm_regfile_write_data)
    );

endmodule
