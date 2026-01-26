`timescale 1ns / 1ps

`include "../include/rv32i_params.vh"
`include "../include/utils.vh"
`include "../include/axi_configuration.vh"
`include "../include/cm_commands.vh"

module cm_and_core_tb ();

    localparam data_folder = {`DATA_DIR, "s_type/sb/"};  // just an example program

    // --- Clock and Reset ---
    localparam CLK_PERIOD = 10;  // 10ns = 100MHz clock
    reg                          CLK;
    reg                          RSTn;

    // AXI 4 Lite connection to the control module
    reg                          S_AXI_AWVALID;
    wire                         S_AXI_AWREADY;
    reg  [  `AXI_ADDR_WIDTH-1:0] S_AXI_AWADDR;
    reg  [  `AXI_PROT_WIDTH-1:0] S_AXI_AWPROT;
    reg                          S_AXI_WVALID;
    wire                         S_AXI_WREADY;
    reg  [  `AXI_DATA_WIDTH-1:0] S_AXI_WDATA;
    reg  [`AXI_STROBE_WIDTH-1:0] S_AXI_WSTRB;
    wire                         S_AXI_BVALID;
    reg                          S_AXI_BREADY;
    wire [  `AXI_RESP_WIDTH-1:0] S_AXI_BRESP;
    reg                          S_AXI_ARVALID;
    wire                         S_AXI_ARREADY;
    reg  [  `AXI_ADDR_WIDTH-1:0] S_AXI_ARADDR;
    reg  [  `AXI_PROT_WIDTH-1:0] S_AXI_ARPROT;
    wire                         S_AXI_RVALID;
    reg                          S_AXI_RREADY;
    wire [  `AXI_DATA_WIDTH-1:0] S_AXI_RDATA;
    wire [  `AXI_RESP_WIDTH-1:0] S_AXI_RRESP;

    // AXI 4 Lite connection from the core the memory
    wire                         M_AXI_AWVALID;
    wire                         M_AXI_AWREADY;
    wire [  `AXI_ADDR_WIDTH-1:0] M_AXI_AWADDR;
    wire [  `AXI_PROT_WIDTH-1:0] M_AXI_AWPROT;
    wire                         M_AXI_WVALID;
    wire                         M_AXI_WREADY;
    wire [  `AXI_DATA_WIDTH-1:0] M_AXI_WDATA;
    wire [`AXI_STROBE_WIDTH-1:0] M_AXI_WSTRB;
    wire                         M_AXI_BVALID;
    wire                         M_AXI_BREADY;
    wire [  `AXI_RESP_WIDTH-1:0] M_AXI_BRESP;
    wire                         M_AXI_ARVALID;
    wire                         M_AXI_ARREADY;
    wire [  `AXI_ADDR_WIDTH-1:0] M_AXI_ARADDR;
    wire [  `AXI_PROT_WIDTH-1:0] M_AXI_ARPROT;
    wire                         M_AXI_RVALID;
    wire                         M_AXI_RREADY;
    wire [  `AXI_DATA_WIDTH-1:0] M_AXI_RDATA;
    wire [  `AXI_RESP_WIDTH-1:0] M_AXI_RRESP;

    // connections between control module and RISC-V core
    wire [  `REG_ADDR_WIDTH-1:0] cm_regfile_addr;
    wire [      `DATA_WIDTH-1:0] cm_regfile_read_data;
    wire                         cm_regfile_write_enable;
    wire [      `DATA_WIDTH-1:0] cm_regfile_write_data;

    // Mocked Memory
    axi_memory_mock u_mem (
        .CLK (CLK),
        .RSTn(RSTn),

        .S_AXI_AWVALID(M_AXI_AWVALID),
        .S_AXI_AWREADY(M_AXI_AWREADY),
        .S_AXI_AWADDR (M_AXI_AWADDR),
        .S_AXI_AWPROT (M_AXI_AWPROT),
        .S_AXI_WVALID (M_AXI_WVALID),
        .S_AXI_WREADY (M_AXI_WREADY),
        .S_AXI_WDATA  (M_AXI_WDATA),
        .S_AXI_WSTRB  (M_AXI_WSTRB),
        .S_AXI_BVALID (M_AXI_BVALID),
        .S_AXI_BREADY (M_AXI_BREADY),
        .S_AXI_BRESP  (M_AXI_BRESP),
        .S_AXI_ARVALID(M_AXI_ARVALID),
        .S_AXI_ARREADY(M_AXI_ARREADY),
        .S_AXI_ARADDR (M_AXI_ARADDR),
        .S_AXI_ARPROT (M_AXI_ARPROT),
        .S_AXI_RVALID (M_AXI_RVALID),
        .S_AXI_RREADY (M_AXI_RREADY),
        .S_AXI_RDATA  (M_AXI_RDATA),
        .S_AXI_RRESP  (M_AXI_RRESP)
    );

    // Control Module
    cm_and_core u_main (
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
        .M_AXI_RRESP  (M_AXI_RRESP)
    );

    // Clock generator
    always begin
        CLK = 1'b0;
        #(CLK_PERIOD / 2);
        CLK = 1'b1;
        #(CLK_PERIOD / 2);
    end

    initial begin
        $dumpvars(0, cm_and_core_tb);
        $display("--- Testbench Starting ---");

        // Reset
        RSTn          = 1'b0;
        S_AXI_AWVALID = 0;
        S_AXI_WVALID  = 0;
        S_AXI_AWPROT  = 3'b0;
        S_AXI_BREADY  = 0;
        S_AXI_ARVALID = 0;
        S_AXI_RREADY  = 0;
        S_AXI_ARADDR  = 0;
        S_AXI_AWADDR  = 0;
        S_AXI_ARPROT  = 3'b0;
        S_AXI_WDATA   = 0;
        S_AXI_WSTRB   = 0;

        #(CLK_PERIOD * 5);
        RSTn = 1'b1;
        $display("[%0t] Reset Released", $time);
        #(CLK_PERIOD * 1);
        $display("Loading data from %s", data_folder);
        $readmemh({data_folder, "/memory.hex"}, u_mem.d_data);
        $readmemh({data_folder, "/program.hex"}, u_mem.i_data);
        #(CLK_PERIOD * 10);

        $display("[%0t] Read Reg 5 -> Expect 0x00000000", $time);
        axi_read({`SUB_SEL_REGFILE, 1'b0, 5'd5, 2'b00}, 32'h00000000, `AXI_RESP_OKAY);
        $display("[%0t] Single Step Core (lw x5, 0xAB)", $time);
        axi_write({`SUB_SEL_CTRL, `CTRL_REG_STEP}, 32'h00000001, 4'b1111, `AXI_RESP_OKAY);
        #(CLK_PERIOD * 10);  // give core time to execute
        $display("[%0t] Read Reg 5 -> Expect 0x000000AB", $time);
        axi_read({`SUB_SEL_REGFILE, 1'b0, 5'd5, 2'b00}, 32'h000000AB, `AXI_RESP_OKAY);
        $display("[%0t] Read Reg 6 -> Expect 0x00000000", $time);
        axi_read({`SUB_SEL_REGFILE, 1'b0, 5'd6, 2'b00}, 32'h00000000, `AXI_RESP_OKAY);
        $display("[%0t] Single Step Core (lw x6, 0xCD)", $time);
        axi_write({`SUB_SEL_CTRL, `CTRL_REG_STEP}, 32'h00000001, 4'b1111, `AXI_RESP_OKAY);
        #(CLK_PERIOD * 10);  // give core time to execute
        $display("[%0t] Read Reg 6 -> Expect 0x000000CD", $time);
        axi_read({`SUB_SEL_REGFILE, 1'b0, 5'd6, 2'b00}, 32'h000000CD, `AXI_RESP_OKAY);

        $display("[%0t] Read Status Reg -> Expect 0x00000001 (pc stalled)", $time);
        axi_read({`SUB_SEL_CTRL, `CTRL_REG_STATUS}, 32'h00000001, `AXI_RESP_OKAY);
        $display("[%0t] Read PC -> Expect 0x00001008", $time);
        axi_read({`SUB_SEL_CTRL, `CTRL_REG_PC}, 32'h00001008, `AXI_RESP_OKAY);
        $display("[%0t] Write PC -> 0x0000100C (skip one instruction)", $time);
        axi_write({`SUB_SEL_CTRL, `CTRL_REG_PC}, 32'h0000100C, 4'b1111, `AXI_RESP_OKAY);
        $display("[%0t] Read PC -> Expect 0x0000100C", $time);
        axi_read({`SUB_SEL_CTRL, `CTRL_REG_PC}, 32'h0000100C, `AXI_RESP_OKAY);

        $display("[%0t] Single Step Core (sb x5, 0(x0)", $time);
        axi_write({`SUB_SEL_CTRL, `CTRL_REG_STEP}, 32'h00000001, 4'b1111, `AXI_RESP_OKAY);
        $display("[%0t] Read Reg 7 -> Expect 0x00000000 since (lw x7, 0xEF) was skipped", $time);
        axi_read({`SUB_SEL_REGFILE, 1'b0, 5'd7, 2'b00}, 32'h00000000, `AXI_RESP_OKAY);

        $display("[%0t] Set core to freerun", $time);
        axi_write({`SUB_SEL_CTRL, `CTRL_REG_START}, 32'h00000001, 4'b1111, `AXI_RESP_OKAY);
        $display("[%0t] Read Status Reg -> Expect 0x00000000 (pc not stalled)", $time);
        axi_read({`SUB_SEL_CTRL, `CTRL_REG_STATUS}, 32'h00000000, `AXI_RESP_OKAY);
        #(CLK_PERIOD * 100);  // give core time to execute
        $display("[%0t] Stop core", $time);
        axi_write({`SUB_SEL_CTRL, `CTRL_REG_STOP}, 32'h00000001, 4'b1111, `AXI_RESP_OKAY);
        $display("[%0t] Read Status Reg -> Expect 0x00000001 (pc stalled)", $time);
        axi_read({`SUB_SEL_CTRL, `CTRL_REG_STATUS}, 32'h00000001, `AXI_RESP_OKAY);
        $display("[%0t] Read PC -> Expect 0x00001020 (end of program)", $time);
        axi_read({`SUB_SEL_CTRL, `CTRL_REG_PC}, 32'h00001020, `AXI_RESP_OKAY);

        #(CLK_PERIOD * 5);
        $display("\n--- TB Done ---\n");
        $finish;
    end


    // AXI master write task
    task axi_write(input [`AXI_ADDR_WIDTH-1:0] addr, input [`AXI_DATA_WIDTH-1:0] data,
                   input [`AXI_STROBE_WIDTH-1:0] strobe, input [`AXI_RESP_WIDTH-1:0] expected_resp);
        begin
            $display("[%0t] AXI_WRITE: addr=%x, data=%x, strobe=%x", $time, addr, data, strobe);
            // Address Phase
            @(posedge CLK);
            S_AXI_AWADDR  <= addr;
            S_AXI_AWVALID <= 1'b1;
            S_AXI_WDATA   <= data;
            S_AXI_WSTRB   <= strobe;
            S_AXI_WVALID  <= 1'b1;
            S_AXI_BREADY  <= 1'b1;

            // Wait for Address Acceptance
            fork
                begin : wait_addr
                    wait (S_AXI_AWREADY);
                    @(posedge CLK);
                    S_AXI_AWVALID <= 1'b0;
                end
                begin : wait_data
                    wait (S_AXI_WREADY);
                    @(posedge CLK);
                    S_AXI_WVALID <= 1'b0;
                end
            join

            // Response Phase
            wait (S_AXI_BVALID);
            if (S_AXI_BRESP != expected_resp)
                $error("WRITE RESP MISMATCH! Exp: %h, Got: %h", expected_resp, S_AXI_BRESP);
            else $display("[SUCCESS]: Write resp OK: %h", S_AXI_BRESP);


            @(posedge CLK);
            S_AXI_BREADY <= 1'b0;

            // Safety gap
            @(posedge CLK);
        end
    endtask

    // AXI master read task
    task axi_read(input [`AXI_ADDR_WIDTH-1:0] addr, input [`AXI_DATA_WIDTH-1:0] expected_data,
                  input [`AXI_RESP_WIDTH-1:0] expected_resp);
        begin
            $display("[%0t] AXI_READ: addr=%x", $time, addr);
            // Address Phase
            @(posedge CLK);
            S_AXI_ARADDR  <= addr;
            S_AXI_ARVALID <= 1'b1;

            wait (S_AXI_ARREADY);
            @(posedge CLK);
            S_AXI_ARVALID <= 1'b0;

            // Data Phase
            S_AXI_RREADY  <= 1'b1;

            wait (S_AXI_RVALID);
            if (S_AXI_RRESP != expected_resp)
                $error("READ RESP MISMATCH! Exp: %h, Got: %h", expected_resp, S_AXI_RRESP);
            else if (S_AXI_RDATA != expected_data)
                $error("READ MISMATCH! Exp: %h, Got: %h", expected_data, S_AXI_RDATA);
            else $display("[SUCCESS]: Read OK: %h", S_AXI_RDATA);


            @(posedge CLK);
            S_AXI_RREADY <= 1'b0;

            // Safety gap
            @(posedge CLK);
        end
    endtask

endmodule
