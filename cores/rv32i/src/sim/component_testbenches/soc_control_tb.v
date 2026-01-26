`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: ISAE
// Engineer: Szymon Bogus
//
// Create Date: 29.11.2025
// Design Name:
// Module Name: soc_control_tb
// Project Name: rv32i_sc
// Target Devices: Zybo Z7-20
// Tool Versions:
// Description: Testbench for SOC control module, it simulates the AXI4Lite Master
//              requests and verifies stalling logic.
//
// Dependencies: rv32i_params.vh, axi4lite_configuration.vh
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////
`include "../../include/rv32i_params.vh"
`include "../../include/axi_configuration.vh"
`include "../include/cm_commands.vh"

module soc_control_tb ();

    // --- Clock and Reset ---
    localparam CLK_PERIOD = 10;  // 10ns = 100MHz clock
    reg                          CLK;
    reg                          RSTn;

    // AXI wires driven by the testbench
    reg                          S_AXI_AWVALID;
    reg  [  `AXI_ADDR_WIDTH-1:0] S_AXI_AWADDR;
    reg                          S_AXI_WVALID;
    reg  [  `AXI_DATA_WIDTH-1:0] S_AXI_WDATA;
    reg  [`AXI_STROBE_WIDTH-1:0] S_AXI_WSTRB;
    reg                          S_AXI_BREADY;
    reg                          S_AXI_ARVALID;
    reg  [  `AXI_ADDR_WIDTH-1:0] S_AXI_ARADDR;
    reg                          S_AXI_RREADY;

    // AXI wires driven byt DUT
    wire                         S_AXI_AWREADY;
    wire                         S_AXI_WREADY;
    wire                         S_AXI_BVALID;
    wire [  `AXI_RESP_WIDTH-1:0] S_AXI_BRESP;
    wire                         S_AXI_ARREADY;
    wire                         S_AXI_RVALID;
    wire [  `AXI_DATA_WIDTH-1:0] S_AXI_RDATA;
    wire [  `AXI_RESP_WIDTH-1:0] S_AXI_RRESP;

    // Wires related to the connection with RISC-V core and driven by DUT
    wire                         cm_regfile_we;
    wire [      `DATA_WIDTH-1:0] cm_regfile_write_data;
    wire [  `REG_ADDR_WIDTH-1:0] cm_regfile_addr;
    wire [      `DATA_WIDTH-1:0] cm_regfile_read_data;

    // --- Instantiate the Device Under Test (DUT) ---
    soc_control SOC_CONTROL_dut (
        .CLK(CLK),
        .RSTn(RSTn),
        // connections to RISC-V core
        .regfile_addr(cm_regfile_addr),
        .regfile_read_data(cm_regfile_read_data),
        .regfile_write_enable(cm_regfile_we),
        .regfile_write_data(cm_regfile_write_data),

        // connections to AXI4 Lite
        // AXI write address
        .S_AXI_AWREADY(S_AXI_AWREADY),
        .S_AXI_AWVALID(S_AXI_AWVALID),
        .S_AXI_AWADDR(S_AXI_AWADDR),
        .S_AXI_AWPROT(3'b0),  // Protection not used, tie to 0

        // AXI write data and write strobe
        .S_AXI_WREADY(S_AXI_WREADY),
        .S_AXI_WVALID(S_AXI_WVALID),
        .S_AXI_WDATA (S_AXI_WDATA),
        .S_AXI_WSTRB (S_AXI_WSTRB),

        // AXI write response
        .S_AXI_BVALID(S_AXI_BVALID),
        .S_AXI_BRESP (S_AXI_BRESP),
        .S_AXI_BREADY(S_AXI_BREADY),

        // AXI read address
        .S_AXI_ARREADY(S_AXI_ARREADY),
        .S_AXI_ARVALID(S_AXI_ARVALID),
        .S_AXI_ARADDR(S_AXI_ARADDR),
        .S_AXI_ARPROT(3'b0),  // Protection not used, tie to 0

        // AXI read data and response
        .S_AXI_RVALID(S_AXI_RVALID),
        .S_AXI_RDATA (S_AXI_RDATA),
        .S_AXI_RRESP (S_AXI_RRESP),
        .S_AXI_RREADY(S_AXI_RREADY)
    );

    register_file REG_FILE_dut (
        .CLK(CLK),
        .RSTn(RSTn),
        .rs1_addr(`REG_ADDR_WIDTH'b0),
        .rs2_addr(`REG_ADDR_WIDTH'b0),
        .rs1(),  // not used
        .rs2(),  // not used
        .write_enable(1'b0),
        .write_addr(`REG_ADDR_WIDTH'b0),
        .write_data(`DATA_WIDTH'b0),
        .extra_addr(cm_regfile_addr),
        .extra_read_data(cm_regfile_read_data),
        .extra_write_enable(cm_regfile_we),
        .extra_write_data(cm_regfile_write_data)
    );

    // Clock generator
    always begin
        CLK = 1'b0;
        #(CLK_PERIOD / 2);
        CLK = 1'b1;
        #(CLK_PERIOD / 2);
    end

    initial begin
        $dumpfile("soc_control_waves.vcd");
        $dumpvars(0, soc_control_tb);
        $dumpvars(0, REG_FILE_dut.registers[1]);
        $dumpvars(0, REG_FILE_dut.registers[2]);
        $dumpvars(0, REG_FILE_dut.registers[3]);
        $dumpvars(0, REG_FILE_dut.registers[4]);

        $display("--- Testbench Starting ---");

        // Reset
        RSTn          = 1'b0;
        S_AXI_AWVALID = 0;
        S_AXI_WVALID  = 0;
        S_AXI_BREADY  = 0;
        S_AXI_ARVALID = 0;
        S_AXI_RREADY  = 0;
        S_AXI_ARADDR  = 0;
        S_AXI_AWADDR  = 0;
        S_AXI_WDATA   = 0;
        S_AXI_WSTRB   = 0;

        #(CLK_PERIOD * 5);
        RSTn = 1'b1;
        $display("[%0t] Reset Released", $time);
        #(CLK_PERIOD * 2);

        // --- TEST 1: Basic Read/Write Verification ---
        // Write 0xDEADBEEF to Register 1
        $display("[%0t] Test 1: Write Reg 1 -> 0xDEADBEEF", $time);
        axi_write({`SUB_SEL_REGFILE, 1'b0, 5'd4, 2'b00}, 32'hDEADBEEF, 4'b1111, `AXI_RESP_OKAY);

        // Read Register 1
        $display("[%0t] Test 2: Read Reg 1 -> Expect 0xDEADBEEF", $time);
        axi_read({`SUB_SEL_REGFILE, 1'b0, 5'd4, 2'b00}, 32'hDEADBEEF, `AXI_RESP_OKAY);

        // --- TEST 2: Strobe (Partial Write) Verification ---
        // 1. Initialize Reg 2 with 0xFFFFFFFF
        $display("[%0t] Test 3: Write Reg 2 -> 0xFFFFFFFF", $time);
        axi_write({`SUB_SEL_REGFILE, 1'b0, 5'd8, 2'b00}, 32'hFFFFFFFF, 4'b1111, `AXI_RESP_OKAY);

        // 2. Overwrite middle bytes (Bits 15:8 and 23:16) with 0x55, 0xAA
        // Strobe 0110 means only write to byte 1 and 2.
        // Data: 0x00AA5500
        // This should fail since we only allow writes to all 32 bits at once
        $display("[%0t] Test 4: Strobe Write Reg 2 (Mask 0110) -> 0x..AA55..", $time);
        axi_write({`SUB_SEL_REGFILE, 1'b0, 5'd8, 2'b00}, 32'h00AA5500, 4'b0110, `AXI_RESP_SLVERR);

        // 3. Read Back. Expect 0xFFAA55FF
        $display("[%0t] Test 5: Read Reg 2 -> Expect still 0xFFFFFFFF", $time);
        axi_read({`SUB_SEL_REGFILE, 1'b0, 5'd8, 2'b00}, 32'hFFFFFFFF, `AXI_RESP_OKAY);

        // Check that writing/reading to/from an non existant register 34 fails
        $display("[%0t] Test 6: Write Reg 34", $time);
        axi_write({`SUB_SEL_REGFILE, 1'b1, 5'd2, 2'b00}, 32'hABABDEED, 4'b1111, `AXI_RESP_SLVERR);
        axi_read({`SUB_SEL_REGFILE, 1'b1, 5'd2, 2'b00}, 32'b0, `AXI_RESP_SLVERR);

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
