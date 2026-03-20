`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: ISAE
// Engineer: Szymon Bogus
// 
// Create Date: 05/27/2025 02:45:14 PM
// Design Name: 
// Module Name: register_file_tb
// Project Name: rv32i_sc
// Target Devices: Zybo Z7-20
// Tool Versions: 
// Description: testbench for register file module.
// 
// Dependencies: rv32i_params.vh
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
`include "../../include/rv32i_params.vh"
`include "../include/cm_commands.vh"


module register_file_tb(

    );
    
    reg clk;
    reg rst;
    wire RSTn = ~rst;
    
    reg [`REG_ADDR_WIDTH-1:0] rs1_addr;
    reg [`REG_ADDR_WIDTH-1:0] rs2_addr;
    
    reg                       rd_enbl;
    
    wire [`DATA_WIDTH-1:0]    rs1;
    wire [`DATA_WIDTH-1:0]    rs2;
    
    reg [`REG_ADDR_WIDTH-1:0]  wrt_addr;
    reg [`DATA_WIDTH-1:0]      wrt_dat;
    reg                        wrt_enbl;
    
    task display_results;
        begin
            $display("Time=%0t | rs1_addr=%h | rs2_addr=%h | rs1=%h | rs2=%h\n| wrt_addr=%h | wrt_dat=%h\n| read=%b | write=%b",
                     $time,
                     rs1_addr,
                     rs2_addr,
                     rs1,
                     rs2,
                     wrt_addr,
                     wrt_dat,
                     rd_enbl,
                     wrt_enbl);
        end
    endtask
    
    
    register_file uut(
        .CLK(clk),
        .RSTn(RSTn),
        .rs1_addr(rs1_addr),
        .rs2_addr(rs2_addr),
        .rs1(rs1),
        .rs2(rs2),
        .write_enable(wrt_enbl),
        .write_addr(wrt_addr),
        .write_data(wrt_dat),
        .extra_addr(`REG_ADDR_WIDTH'b0),
        .extra_read_data(),
        .extra_write_enable(1'b0),
        .extra_write_data(`DATA_WIDTH'b0),
        .fault_write_enable(1'b0),
        .fault_addr(`REG_ADDR_WIDTH'b0),
        .fault_mode(`FAULT_MODE_WIDTH'b0),
        .fault_mask(`DATA_WIDTH'b0)
    );
    
    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // toggle clk every 5 time units
    end
    
    initial begin
        // Reset
        rst   = 1'b1;
        rs1_addr = 5'b0;
        rs2_addr = 5'b0;
        wrt_addr = 5'b0;
        wrt_dat  = 32'h0;
        wrt_enbl = 1'b0; 
        rd_enbl  = 1'b0;    

        // Test 1: just after reset, all registers should be 0x0
        #15 rst = 1'b0;
        #5; // Wait for one clock cycle
        rd_enbl  = 1'b1; 
        rs1_addr = 5'd1; 
        rs2_addr = 5'd2; 
        display_results();
        if (rs1 !== 32'h0 || rs2 !== 32'h0) begin
            $display("Test 1 FAILED: Registers x1 or x2 not reset to 0");
        end else begin
            $display("Test 1 PASSED: Registers reset correctly");
        end
        rd_enbl  = 1'b0; 
        
        // Test 2: reg x0 should be 0x0 all the time for both read lines
        #10;
        rd_enbl  = 1'b1; 
        rs1_addr = 5'd0; 
        rs2_addr = 5'd0; 
        display_results();
        if (rs1 !== 32'h0 || rs2 !== 32'h0) begin
            $display("Test 2 FAILED: x0 not hardwired to 0");
        end else begin
            $display("Test 2 PASSED: x0 is 0 on both ports");
        end
        rd_enbl  = 1'b0; 
        
        // Try writing to x0 (should be ignored)
        rd_enbl  = 1'b1; 
        wrt_enbl = 1'b1;
        wrt_addr = 5'd0;
        wrt_dat = 32'hDEADBEEF;
        #10;
        display_results();
        if (rs1 !== 32'h0 || rs2 !== 32'h0) begin
            $display("Test 2 FAILED: Write to x0 affected output");
        end else begin
            $display("Test 2 PASSED: Write to x0 ignored");
        end
        wrt_enbl = 1'b0;
        rd_enbl  = 1'b0; 
        
        // Test 3: write to registers and retreat a value
        #10;
        wrt_enbl = 1'b1;
        wrt_addr = 5'd1; // Write to x1
        wrt_dat = 32'h12345678;
        #10; // Wait for write on posedge clk
        wrt_enbl = 1'b0;
        rd_enbl  = 1'b1; 
        rs1_addr = 5'd1; // Read x1
        rs2_addr = 5'd1; // Read x1
        #5;
        display_results();
        if (rs1 !== 32'h12345678 || rs2 !== 32'h12345678) begin
            $display("Test 3 FAILED: Write to x1 not read correctly");
        end else begin
            $display("Test 3 PASSED: Write to x1 read correctly");
        end
        rd_enbl  = 1'b0; 
        
        // Test 4: Simultaneous read and write to same register (verify forwarding)
        #10;
        rs1_addr = 5'd2; // Read x2
        rs2_addr = 5'd2; // Read x2
        wrt_enbl = 1'b1;
        rd_enbl  = 1'b1; 
        wrt_addr = 5'd2; // Write to x2
        wrt_dat = 32'hAABBCCDD;
        #5; // Check before posedge (should see forwarded value)
        display_results();
        if (rs1 !== 32'hAABBCCDD || rs2 !== 32'hAABBCCDD) begin
            $display("Test 4 FAILED: Forwarding not working");
        end else begin
            $display("Test 4 PASSED: Forwarding works");
        end
        #5; // After posedge, register should be updated
        wrt_enbl = 1'b0;
        #5;
        display_results();
        if (rs1 !== 32'hAABBCCDD || rs2 !== 32'hAABBCCDD) begin
            $display("Test 4 FAILED: Register x2 not updated correctly");
        end else begin
            $display("Test 4 PASSED: Register x2 updated correctly");
        end
        rd_enbl  = 1'b0; 
        
        // Test 5: Multiple writes and reads
        #10;
        wrt_enbl = 1'b1;
        wrt_addr = 5'd3; // Write to x3
        wrt_dat = 32'h5555AAAA;
        #10;
        wrt_addr = 5'd4; // Write to x4
        wrt_dat = 32'hFFFF0000;
        #10;
        wrt_enbl = 1'b0;
        rd_enbl  = 1'b1; 
        rs1_addr = 5'd3; // Read x3
        rs2_addr = 5'd4; // Read x4
        #5;
        display_results();
        if (rs1 !== 32'h5555AAAA || rs2 !== 32'hFFFF0000) begin
            $display("Test 5 FAILED: Multiple writes/reads incorrect");
        end else begin
            $display("Test 5 PASSED: Multiple writes/reads correct");
        end

        #10;
        $display("All tests completed");
        
        $finish;
    end
    
endmodule
