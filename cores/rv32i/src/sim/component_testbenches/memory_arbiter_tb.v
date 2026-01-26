`timescale 1ns / 1ps

`include "../../include/utils.vh"
`include "../../include/rv32i_params.vh"
`include "../../include/axi_configuration.vh"


module memory_arbiter_tb ();

    reg                          CLK = 0;
    reg                          RSTn = 0;

    // AXI4-lite connections
    wire                         M_AXI_AWVALID;
    reg                          M_AXI_AWREADY = 0;
    wire [  `AXI_ADDR_WIDTH-1:0] M_AXI_AWADDR;
    wire [                  2:0] M_AXI_AWPROT;
    wire                         M_AXI_WVALID;
    reg                          M_AXI_WREADY = 0;
    wire [  `AXI_DATA_WIDTH-1:0] M_AXI_WDATA;
    wire [`AXI_STROBE_WIDTH-1:0] M_AXI_WSTRB;
    reg                          M_AXI_BVALID = 0;
    wire                         M_AXI_BREADY;
    reg  [  `AXI_RESP_WIDTH-1:0] M_AXI_BRESP = 0;
    wire                         M_AXI_ARVALID;
    reg                          M_AXI_ARREADY = 0;
    wire [  `AXI_ADDR_WIDTH-1:0] M_AXI_ARADDR;
    wire [                  2:0] M_AXI_ARPROT;
    reg                          M_AXI_RVALID = 0;
    wire                         M_AXI_RREADY;
    reg  [  `AXI_DATA_WIDTH-1:0] M_AXI_RDATA = 0;
    reg  [  `AXI_RESP_WIDTH-1:0] M_AXI_RRESP = 0;

    // instruction fetching
    reg  [      `DATA_WIDTH-1:0] pc = 0;
    reg                          pc_valid = 0;
    wire [     `INSTR_WIDTH-1:0] instruction;
    wire                         instruction_valid;

    // load/store
    reg  [      `DATA_WIDTH-1:0] read_write_addr = 0;
    reg  [      `DATA_WIDTH-1:0] write_data = 0;
    wire [      `DATA_WIDTH-1:0] read_data;
    reg                          read_enable = 0;
    reg                          write_enable = 0;
    reg  [`AXI_STROBE_WIDTH-1:0] write_strobe = 0;
    wire                         read_write_valid;

    memory_arbiter dut (
        .CLK (CLK),
        .RSTn(RSTn),

        // AXI4-lite connections
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

        // instruction fetching
        .pc(pc),
        .pc_valid(pc_valid),
        .instruction(instruction),
        .instruction_valid(instruction_valid),

        // load/store
        .read_write_addr(read_write_addr),
        .store_data(write_data),
        .load_data(read_data),
        .read_enable(read_enable),
        .write_enable(write_enable),
        .store_strobe(write_strobe),
        .read_write_valid(read_write_valid)
    );

    initial begin
        CLK = 0;
        #5;
        forever #5 CLK = ~CLK;
    end

    initial begin
        RSTn = 1;
        RSTn = 0;
        $dumpvars(0, memory_arbiter_tb);
        @(posedge CLK);
        @(posedge CLK);
        RSTn = 1;

        `ASSERT(M_AXI_ARVALID, 0)
        `ASSERT(M_AXI_AWVALID, 0)
        #20;
        @(posedge CLK);
        #1;
        pc = 32'habac;
        pc_valid = 1;

        @(posedge CLK);
        @(posedge CLK);
        #1;
        `ASSERT(M_AXI_ARVALID, 1)
        `ASSERT(M_AXI_ARADDR, pc)
        M_AXI_ARREADY = 1;

        @(posedge CLK);
        #1;
        `ASSERT(M_AXI_ARVALID, 0)
        `ASSERT(M_AXI_RREADY, 1)  // in theory it would also be correct for this to be set later
        M_AXI_ARREADY = 0;
        M_AXI_RVALID  = 1;
        M_AXI_RDATA   = 32'hdeadaaaa;

        @(posedge CLK);
        #1;
        `ASSERT(M_AXI_RREADY, 0)
        `ASSERT(instruction_valid, 1)
        `ASSERT(instruction, 32'hdeadaaaa)
        M_AXI_RVALID = 0;
        pc_valid = 0;

        #100;
        $display("All tests completed");
        $finish;
    end


endmodule
