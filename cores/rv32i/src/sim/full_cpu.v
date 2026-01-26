`timescale 1ns / 1ps

`include "rv32i_params.vh"
`include "axi_configuration.vh"

module full_cpu ();

    reg                          CLK;
    reg                          RSTn;
    reg                          pc_stall;

    // AXI 4 Lite connection between CPU and memory
    wire                         AXI_AWVALID;
    wire                         AXI_AWREADY;
    wire [  `AXI_ADDR_WIDTH-1:0] AXI_AWADDR;
    wire [  `AXI_PROT_WIDTH-1:0] AXI_AWPROT;
    wire                         AXI_WVALID;
    wire                         AXI_WREADY;
    wire [  `AXI_DATA_WIDTH-1:0] AXI_WDATA;
    wire [`AXI_STROBE_WIDTH-1:0] AXI_WSTRB;
    wire                         AXI_BVALID;
    wire                         AXI_BREADY;
    wire [  `AXI_RESP_WIDTH-1:0] AXI_BRESP;
    wire                         AXI_ARVALID;
    wire                         AXI_ARREADY;
    wire [  `AXI_ADDR_WIDTH-1:0] AXI_ARADDR;
    wire [  `AXI_PROT_WIDTH-1:0] AXI_ARPROT;
    wire                         AXI_RVALID;
    wire                         AXI_RREADY;
    wire [  `AXI_DATA_WIDTH-1:0] AXI_RDATA;
    wire [  `AXI_RESP_WIDTH-1:0] AXI_RRESP;


    // Mocked Memory
    axi_memory_mock u_mem (
        .CLK (CLK),
        .RSTn(RSTn),

        .S_AXI_AWVALID(AXI_AWVALID),
        .S_AXI_AWREADY(AXI_AWREADY),
        .S_AXI_AWADDR (AXI_AWADDR),
        .S_AXI_AWPROT (AXI_AWPROT),
        .S_AXI_WVALID (AXI_WVALID),
        .S_AXI_WREADY (AXI_WREADY),
        .S_AXI_WDATA  (AXI_WDATA),
        .S_AXI_WSTRB  (AXI_WSTRB),
        .S_AXI_BVALID (AXI_BVALID),
        .S_AXI_BREADY (AXI_BREADY),
        .S_AXI_BRESP  (AXI_BRESP),
        .S_AXI_ARVALID(AXI_ARVALID),
        .S_AXI_ARREADY(AXI_ARREADY),
        .S_AXI_ARADDR (AXI_ARADDR),
        .S_AXI_ARPROT (AXI_ARPROT),
        .S_AXI_RVALID (AXI_RVALID),
        .S_AXI_RREADY (AXI_RREADY),
        .S_AXI_RDATA  (AXI_RDATA),
        .S_AXI_RRESP  (AXI_RRESP)
    );

    // CPU
    riscv_cpu u_cpu (
        .CLK (CLK),
        .RSTn(RSTn),

        .M_AXI_AWVALID(AXI_AWVALID),
        .M_AXI_AWREADY(AXI_AWREADY),
        .M_AXI_AWADDR (AXI_AWADDR),
        .M_AXI_AWPROT (AXI_AWPROT),
        .M_AXI_WVALID (AXI_WVALID),
        .M_AXI_WREADY (AXI_WREADY),
        .M_AXI_WDATA  (AXI_WDATA),
        .M_AXI_WSTRB  (AXI_WSTRB),
        .M_AXI_BVALID (AXI_BVALID),
        .M_AXI_BREADY (AXI_BREADY),
        .M_AXI_BRESP  (AXI_BRESP),
        .M_AXI_ARVALID(AXI_ARVALID),
        .M_AXI_ARREADY(AXI_ARREADY),
        .M_AXI_ARADDR (AXI_ARADDR),
        .M_AXI_ARPROT (AXI_ARPROT),
        .M_AXI_RVALID (AXI_RVALID),
        .M_AXI_RREADY (AXI_RREADY),
        .M_AXI_RDATA  (AXI_RDATA),
        .M_AXI_RRESP  (AXI_RRESP),

        .cm_pc_stall(pc_stall),
        .cm_pc_read_data(),
        .cm_pc_we(1'b0),
        .cm_pc_write_data(`DATA_WIDTH'b0),
        .cm_regfile_addr(`REG_ADDR_WIDTH'b0),
        .cm_regfile_read_data(),
        .cm_regfile_we(1'b0),
        .cm_regfile_write_data(`DATA_WIDTH'b0)
    );

    // task automatic display_results;
    //     begin
    //         $display("Time=%0t, pc=%h, instr=%h", $time, u_cpu.pc, u_cpu.instruction);
    //         $display("  Decode");
    //         $display("   op=%b, func3=%b, func7=%b", u_cpu.u_decode.opcode, u_cpu.u_decode.func3,
    //                  u_cpu.u_decode.func7);
    //         $display("   rd_addr=%h, rs1_addr=%h, rs2_addr=%h, imm=%h", u_cpu.rd_addr,
    //                  u_cpu.rs1_addr, u_cpu.rs2_addr, u_cpu.immediate);
    //         $display("  ALU");
    //         $display("   input: rs1=%h, rs2=%h, alu_ctrl=%b", u_cpu.rs1, u_cpu.rs2, u_cpu.alu_ctrl);
    //         $display("   output: alu_result=%h", u_cpu.alu_result);
    //         // $display("  Memory");
    //         // $display("   input: use_mem=%h, d_r_addr=%h, d_w_addr=%h, d_w_dat=%h", u_cpu.use_mem,
    //         //          u_cpu.d_r_addr, u_cpu.d_w_addr, u_cpu.d_w_dat);
    //         // $display("   output: d_r_dat=%h", u_cpu.d_r_dat);
    //         $display("  Write back");
    //         $display("   write_back_data=%h", u_cpu.write_back_data);
    //     end
    // endtask

    initial begin
        CLK = 0;
        #5;
        forever #5 CLK = ~CLK;
    end

    string                    data_folder;
    reg     [`DATA_WIDTH-1:0] expected_registers[1:`NUM_REGISTERS-1];
    reg     [`DATA_WIDTH-1:0] expected_memory   [ `MEMORY_NUM_WORDS];

    // temporary variables
    integer                   total_steps;
    integer                   reg_id;
    integer                   mem_addr;
    integer                   found_error;
    reg     [`DATA_WIDTH-1:0] value;
    reg     [`DATA_WIDTH-1:0] expected_value;

    initial begin
        RSTn = 1;
        RSTn = 0;

        $dumpfile("full_cpu_tb.vcd");
        $dumpvars(0, full_cpu);
        $dumpvars(0, u_mem.i_data[0]);
        $dumpvars(0, u_mem.i_data[1]);
        $dumpvars(0, u_mem.i_data[2]);
        $dumpvars(0, u_mem.i_data[3]);
        $dumpvars(0, u_mem.d_data[0]);
        $dumpvars(0, u_mem.d_data[1]);
        $dumpvars(0, u_mem.d_data[2]);
        $dumpvars(0, u_mem.d_data[3]);
        $dumpvars(0, expected_memory[0]);
        $dumpvars(0, u_cpu.u_register_file.registers[5]);
        $dumpvars(0, u_cpu.u_register_file.registers[6]);
        for (reg_id = 1; reg_id < `NUM_REGISTERS; reg_id = reg_id + 1) begin
            expected_registers[reg_id] = 32'b0;
        end
        for (mem_addr = 0; mem_addr < `MEMORY_NUM_WORDS; mem_addr = mem_addr + 1) begin
            expected_memory[mem_addr] = 32'b0;
        end

        pc_stall = 1'b1;
        #10;
        // De-assert reset
        RSTn = 1'b1;

        #10 $value$plusargs("data=%s", data_folder);
        $display("Loading data from %s", data_folder);
        $readmemh({data_folder, "/memory.hex"}, u_mem.d_data);
        $readmemh({data_folder, "/program.hex"}, u_mem.i_data);
        $readmemh({data_folder, "/expected_registers.hex"}, expected_registers);
        $readmemh({data_folder, "/expected_memory.hex"}, expected_memory);

        #20;

        // Execute program
        $display("Executing program...");
        // De-assert pc_stall
        pc_stall = 1'b0;
        #5;
        total_steps = 0;
        while (u_cpu.instruction != 32'h0000006F && total_steps < 1000) begin
            total_steps = total_steps + 1;
            #10;
        end

        found_error = 0;
        if (total_steps >= 1000) begin
            $display("[ERROR] Exceeded allowed number of cycles");
            found_error = 1;
        end

        $display("Verifying results...");
        #1;
        for (reg_id = 1; reg_id < `NUM_REGISTERS; reg_id = reg_id + 1) begin
            value = u_cpu.u_register_file.registers[reg_id];
            expected_value = expected_registers[reg_id];
            if (value == expected_value) begin
                $display("[INFO]  registers[%d] = 0x%h, matches expected", reg_id, value);
            end else begin
                found_error = 1;
                $display("[ERROR] registers[%d] = 0x%h, expected 0x%h", reg_id, value,
                         expected_value);
            end
        end
        for (mem_addr = 0; mem_addr < `MEMORY_NUM_WORDS; mem_addr = mem_addr + 1) begin
            value = u_mem.d_data[mem_addr];
            expected_value = expected_memory[mem_addr];
            if (value == expected_value) begin
                // only print unexpected values since memory is quite large
                // $display("[INFO]  mem[0x%h] = 0x%h, matches expected",
                //     mem_addr * `BYTES_PER_WORD, value);
            end else begin
                found_error = 1;
                $display("[ERROR] mem[0x%h] = 0x%h, expected 0x%h", mem_addr * `BYTES_PER_WORD,
                         value, expected_value);
            end
        end

        if (found_error == 0) begin
            $display("No error found");
        end else begin
            $display("Found errors (see output above)");
        end

        $display("All tests completed");
        $finish;
    end

endmodule
