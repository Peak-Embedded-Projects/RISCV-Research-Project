`timescale 1ns / 1ps

`include "rv32i_params.vh"
`include "rv32i_control.vh"
`include "axi_configuration.vh"


module riscv_cpu (
    input CLK,
    input RSTn,

    // AXI4-lite connections to the memory
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
    input  [  `AXI_RESP_WIDTH-1:0] M_AXI_RRESP,

    // connections to SOC Control Module
    input                        cm_pc_stall,
    output [    `DATA_WIDTH-1:0] cm_pc_read_data,
    input                        cm_pc_we,
    input  [    `DATA_WIDTH-1:0] cm_pc_write_data,
    input  [`REG_ADDR_WIDTH-1:0] cm_regfile_addr,
    output [    `DATA_WIDTH-1:0] cm_regfile_read_data,
    input                        cm_regfile_we,
    input  [    `DATA_WIDTH-1:0] cm_regfile_write_data
);

    // we have the following transactions, each one has ready and valid signals
    // and associated data.
    // - PC - INSTRUCTION - DECODED - ALU_RESULT (- MEM_RESULT) - NEXT_PC

    // PC
    wire pc_valid, pc_ready;
    reg [`DATA_WIDTH-1:0] pc;

    // INSTRUCTION
    wire instruction_valid, instruction_ready;
    wire [`DATA_WIDTH-1:0] instruction;

    // DECODED
    reg  decoded_valid;
    wire decoded_ready;
    wire                       is_jump;
    wire                       is_jalr;
    wire                       is_branch;
    wire [    `DATA_WIDTH-1:0] immediate;
    wire [   `FUNC3_WIDTH-1:0] func3;
    wire [`REG_ADDR_WIDTH-1:0] rs1_addr;
    wire [`REG_ADDR_WIDTH-1:0] rs2_addr;
    wire [`REG_ADDR_WIDTH-1:0] rd_addr;
    wire                       alu_src1_is_pc;
    wire                       alu_src2_is_imm;
    wire                       use_mem;
    wire                       mem_is_write;
    wire                       do_write_back;
    wire [`ALU_CTRL_WIDTH-1:0] alu_ctrl;
    wire [    `DATA_WIDTH-1:0] rs1;
    wire [    `DATA_WIDTH-1:0] rs2;

    // EXECUTE_RESULT
    wire execute_result_valid, execute_result_ready;
    reg  [`DATA_WIDTH-1:0] write_back_data;
    wire                   take_branch;
    // take either or
    reg                    alu_result_valid;
    wire [`DATA_WIDTH-1:0] alu_result;
    wire                   load_store_ready;
    wire                   mem_result_valid;
    wire                   mem_result_ready;

    // NEXT_PC
    reg  next_pc_valid;
    wire next_pc_ready;
    reg  [      `DATA_WIDTH-1:0] next_pc;


    // load/store
    wire [      `DATA_WIDTH-1:0] mem_addr;
    wire [      `DATA_WIDTH-1:0] mem_write_data;
    wire [      `DATA_WIDTH-1:0] mem_read_data;
    wire [`AXI_STROBE_WIDTH-1:0] mem_write_strobe;
    wire [      `DATA_WIDTH-1:0] mem_wb_data;  // parsed by byte_reader


    // =====   Clocked Components    =====

    // PC generator
    // do not accept the next pc if the current pc has not
    // yet been transferred to the fetch unit.
    reg                          pc_release_pending;
    assign next_pc_ready = !pc_release_pending;
    assign pc_valid = pc_release_pending && !cm_pc_stall;
    always @(posedge CLK or negedge RSTn) begin
        if (!RSTn) begin
            pc <= `BOOT_ADDR;
            pc_release_pending <= 1'b1;
        end else begin
            if (next_pc_valid && next_pc_ready) begin
                // NEXT_PC transaction
                pc <= next_pc;
                pc_release_pending <= 1'b1;
            end else if (pc_valid && pc_ready) begin
                // PC transaction
                pc_release_pending <= 1'b0;
            end else if (cm_pc_stall && cm_pc_we) begin
                pc <= cm_pc_write_data;
            end
        end
    end
    assign cm_pc_read_data = pc;

    reg [`DATA_WIDTH-1:0] instruction_latched;
    assign instruction_ready = 1'b1;  // always ready
    always @(posedge CLK or negedge RSTn) begin
        if (!RSTn) begin
            decoded_valid <= 1'b0;
            instruction_latched <= `INSTR_WIDTH'b0;
        end else begin
            if (instruction_valid & instruction_ready) begin
                // INSTRUCTION transaction
                decoded_valid <= 1'b1;
                instruction_latched <= instruction;
            end else if (decoded_valid & decoded_ready) begin
                // DECODED transaction
                decoded_valid <= 1'b0;
            end
        end
    end

    // MUX between ALU and memory paths
    assign decoded_ready = use_mem ? load_store_ready : 1'b1;
    assign execute_result_valid = use_mem ? mem_result_valid : alu_result_valid;
    assign mem_result_ready = use_mem ? execute_result_ready : 1'b0;
    always @(posedge CLK or negedge RSTn) begin
        if (!RSTn) begin
            alu_result_valid <= 1'b0;
        end else begin
            if (decoded_valid & decoded_ready) begin
                // DECODED transaction
                if (!use_mem) alu_result_valid <= 1'b1;
            end else if (execute_result_valid & execute_result_ready) begin
                // EXECUTE_RESULT transaction
                alu_result_valid <= 1'b0;
            end
        end
    end

    assign execute_result_ready = 1'b1;  // always ready
    always @(posedge CLK or negedge RSTn) begin
        if (!RSTn) begin
            next_pc_valid <= 1'b0;
        end else begin
            if (execute_result_valid & execute_result_ready) begin
                // EXECUTE_RESULT transaction
                next_pc_valid <= 1'b1;
            end else if (next_pc_valid & next_pc_ready) begin
                // NEXT_PC transaction
                next_pc_valid <= 1'b0;
            end
        end
    end

    register_file u_register_file (
        .CLK (CLK),
        .RSTn(RSTn),

        .rs1_addr    (rs1_addr),
        .rs2_addr    (rs2_addr),
        .rs1         (rs1),
        .rs2         (rs2),
        // WRITE BACK on NEXT_PC transaction
        .write_enable(do_write_back && next_pc_valid && next_pc_ready),
        .write_addr  (rd_addr),
        .write_data  (write_back_data),

        .extra_addr        (cm_regfile_addr),
        .extra_read_data   (cm_regfile_read_data),
        .extra_write_enable(cm_regfile_we),
        .extra_write_data  (cm_regfile_write_data)
    );

    memory_arbiter u_memory_arbiter (
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

        .pc_valid(pc_valid),
        .pc_ready(pc_ready),
        .pc(pc),
        .instruction_valid(instruction_valid),
        .instruction_ready(instruction_ready),
        .instruction(instruction),

        .load_store_valid       (decoded_valid && use_mem),
        .load_store_ready       (load_store_ready),
        .load_store_addr        (mem_addr),
        .load_store_is_write    (mem_is_write),
        .store_strobe           (mem_write_strobe),
        .store_data             (mem_write_data),
        .load_store_result_valid(mem_result_valid),
        .load_store_result_ready(mem_result_ready),
        .load_data              (mem_read_data)
    );


    // =====   Clocked Components    =====
    // =====   Fetch stage   =====


    // =====   Fetch stage    =====
    // =====   Decode stage   =====

    instruction_decode u_decode (
        .instr          (instruction_latched),
        .func3          (func3),
        .rs1_addr       (rs1_addr),
        .rs2_addr       (rs2_addr),
        .rd_addr        (rd_addr),
        .imm            (immediate),
        .alu_src1_is_pc (alu_src1_is_pc),
        .alu_src2_is_imm(alu_src2_is_imm),
        .use_mem        (use_mem),
        .mem_is_write   (mem_is_write),
        .is_branch      (is_branch),
        .is_jump        (is_jump),
        .is_jalr        (is_jalr),
        .do_write_back  (do_write_back),
        .alu_ctrl       (alu_ctrl)
    );

    // =====   Decode stage   =====
    // =====   Execute stage   =====

    alu u_alu (
        .alu_ctrl   (alu_ctrl),
        .src1       (alu_src1_is_pc ? pc : rs1),
        .src2       (alu_src2_is_imm ? immediate : rs2),
        .result     (alu_result),
        .take_branch(take_branch)
    );

    load_store_decoder u_load_store_decoder (
        .alu_result_addr(alu_result),
        .func3          (func3),
        .reg_read       (rs2),
        .byte_enb       (mem_write_strobe),
        .data           (mem_write_data)
    );

    // =====   Execute stage   =====
    // =====   Memory stage   =====

    wire [`DATA_WIDTH-1:0] mem_addr_aux = use_mem ? rs1 + immediate : `DATA_WIDTH'b0;
    assign mem_addr = mem_is_write ? {mem_addr_aux[`DATA_WIDTH-1:2], 2'b00} : mem_addr_aux;

    byte_reader u_byte_reader (
        .mem_data (mem_read_data),
        .func3    (func3),
        .byte_mask(mem_write_strobe),
        .wb_data  (mem_wb_data)
        // ,
        // .valid    (mem_valid)
    );
    // =====   Memory stage   =====
    // =====   Write back stage   =====

    wire [`DATA_WIDTH-1:0] pc_plus_4 = pc + 32'd4;
    always @(*)
        if (is_jump) begin
            write_back_data = pc_plus_4;
            next_pc = (is_jalr ? rs1 : pc) + immediate;
        end else if (use_mem) begin
            write_back_data = mem_wb_data;
            next_pc = pc_plus_4;
        end else begin
            write_back_data = alu_result;
            if (is_branch & take_branch) next_pc = pc + immediate;
            else next_pc = pc_plus_4;
        end

    // =====   Write back stage   =====

endmodule
