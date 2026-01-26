`timescale 1ns / 1ps

`include "axi_configuration.vh"

// AXI 4 Lite slave that can be used to mock memory
module axi_memory_mock (
    input CLK,
    input RSTn,

    input                          S_AXI_AWVALID,
    output                         S_AXI_AWREADY,
    input  [  `AXI_ADDR_WIDTH-1:0] S_AXI_AWADDR,
    input  [                  2:0] S_AXI_AWPROT,
    input                          S_AXI_WVALID,
    output                         S_AXI_WREADY,
    input  [  `AXI_DATA_WIDTH-1:0] S_AXI_WDATA,
    input  [`AXI_STROBE_WIDTH-1:0] S_AXI_WSTRB,
    output                         S_AXI_BVALID,
    input                          S_AXI_BREADY,
    output [                  1:0] S_AXI_BRESP,
    input                          S_AXI_ARVALID,
    output                         S_AXI_ARREADY,
    input  [  `AXI_ADDR_WIDTH-1:0] S_AXI_ARADDR,
    input  [                  2:0] S_AXI_ARPROT,
    output                         S_AXI_RVALID,
    input                          S_AXI_RREADY,
    output [  `AXI_DATA_WIDTH-1:0] S_AXI_RDATA,
    output [                  1:0] S_AXI_RRESP
);

    reg [`AXI_DATA_WIDTH-1:0] i_data[`MEMORY_NUM_WORDS];
    reg [`AXI_DATA_WIDTH-1:0] d_data[`MEMORY_NUM_WORDS];

    wire [`MEMORY_INDEX_WIDTH-1:0] read_index;
    assign read_index = S_AXI_ARADDR[`MEMORY_ADDR_WIDTH-1:`AXI_ADDR_LSB];
    wire read_memory_selector = S_AXI_ARADDR[`MEMORY_ADDR_WIDTH];

    wire [`MEMORY_INDEX_WIDTH-1:0] write_index;
    assign write_index = S_AXI_AWADDR[`MEMORY_ADDR_WIDTH-1:`AXI_ADDR_LSB];
    wire write_memory_selector = S_AXI_AWADDR[`MEMORY_ADDR_WIDTH];

    // Internal registers
    // Write channel internal registers
    reg S_AXI_AWREADY_;
    reg S_AXI_WREADY_;
    reg S_AXI_BVALID_;
    reg [1:0] S_AXI_BRESP_;
    reg [`MEMORY_ADDR_WIDTH-1:0] axi_awaddr_latched;  // latched write address

    // Read channel internal registers
    reg S_AXI_ARREADY_;
    reg S_AXI_RVALID_;
    reg [1:0] S_AXI_RRESP_;
    reg [`AXI_DATA_WIDTH-1:0] S_AXI_RDATA_;  // pipelined read data output

    // Output wires
    // Write related
    assign S_AXI_AWREADY = S_AXI_AWREADY_;
    assign S_AXI_WREADY  = S_AXI_WREADY_;
    assign S_AXI_BVALID  = S_AXI_BVALID_;
    assign S_AXI_BRESP   = S_AXI_BRESP_;

    // Read related
    assign S_AXI_ARREADY = S_AXI_ARREADY_;
    assign S_AXI_RVALID  = S_AXI_RVALID_;
    assign S_AXI_RRESP   = S_AXI_RRESP_;
    assign S_AXI_RDATA   = S_AXI_RDATA_;

    // Read process
    always @(posedge CLK or negedge RSTn) begin
        if (!RSTn) begin
            S_AXI_ARREADY_ <= 1'b1;
            S_AXI_RVALID_  <= 1'b0;
            S_AXI_RDATA_   <= 0;
            S_AXI_RRESP_   <= `AXI_RESP_OKAY;
        end else begin
            if (S_AXI_ARVALID && S_AXI_ARREADY_) begin
                // Address handshake: slave is by default ready so the handshake happends immediately
                //                    once the master issue the address
                S_AXI_ARREADY_ <= 1'b0;
                S_AXI_RVALID_  <= 1'b1;  // data will be valid in the next cycle
                S_AXI_RRESP_   <= `AXI_RESP_OKAY;
                S_AXI_RDATA_   <= read_memory_selector ? i_data[read_index] : d_data[read_index];
            end else if (S_AXI_RREADY && S_AXI_RVALID_) begin
                // Transaction complete: master accepts the data
                S_AXI_RVALID_  <= 1'b0;
                S_AXI_ARREADY_ <= 1'b1;  // heres ready for the new read transaction
            end
        end
    end

    // Write process
    always @(posedge CLK or negedge RSTn) begin
        if (!RSTn) begin
            S_AXI_AWREADY_     <= 1'b1;
            S_AXI_WREADY_      <= 1'b0;
            S_AXI_BVALID_      <= 1'b0;
            S_AXI_BRESP_       <= `AXI_RESP_OKAY;
            axi_awaddr_latched <= 0;
        end else begin
            if (S_AXI_AWVALID && S_AXI_AWREADY_) begin
                // Address handshake: slave is by default READY and master has to issue VALID
                axi_awaddr_latched <= write_index;
                S_AXI_AWREADY_     <= 1'b0;
                S_AXI_WREADY_      <= 1'b1;
            end else if (S_AXI_WVALID && S_AXI_WREADY_) begin
                // Data handshake: slave is ready to accept new write data and it's waiting for the master to issue VALID
                S_AXI_WREADY_ <= 1'b0;
                S_AXI_BVALID_ <= 1'b1;
                S_AXI_BRESP_  <= `AXI_RESP_OKAY;
            end else if (S_AXI_BVALID && S_AXI_BREADY) begin
                // Response
                S_AXI_BVALID_  <= 1'b0;
                S_AXI_AWREADY_ <= 1'b1;  // heres ready for the new write transaction
            end
        end
    end

    // Register write and reset process
    integer reg_id;
    integer byte_id;
    always @(posedge CLK or negedge RSTn) begin
        if (!RSTn) begin
            for (reg_id = 0; reg_id < `MEMORY_NUM_WORDS; reg_id = reg_id + 1) begin
                i_data[reg_id] <= `AXI_DATA_WIDTH'h0;
                d_data[reg_id] <= `AXI_DATA_WIDTH'h0;
            end
        end else begin
            if (S_AXI_WVALID && S_AXI_WREADY_) begin
                for (byte_id = 0; byte_id < `AXI_STROBE_WIDTH; byte_id = byte_id + 1) begin
                    if (S_AXI_WSTRB[byte_id]) begin
                        // Example to illustrate how strobe mechanism works:
                        // if byte_id = 0 then [(0*8)+:8] -> [0+:8] this selects [7:0]
                        // the line performs: 
                        // data[axi_awaddr_latched][7:0]         <= S_AXI_WDATA[7:0]
                        if (write_memory_selector)
                            i_data[axi_awaddr_latched][(byte_id*8)+:8] <= S_AXI_WDATA[(byte_id*8)+:8];
                        else
                            d_data[axi_awaddr_latched][(byte_id*8)+:8] <= S_AXI_WDATA[(byte_id*8)+:8];
                    end
                end
            end
        end
    end

endmodule
