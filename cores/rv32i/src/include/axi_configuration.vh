`ifndef AXI_CONFIGURATION_VH
`define AXI_CONFIGURATION_VH

// Data bus details
`define AXI_DATA_WIDTH 32
`define AXI_ADDR_WIDTH 32
`define AXI_STROBE_WIDTH 4
`define AXI_ADDR_LSB $clog2(`AXI_DATA_WIDTH / 8)    // bits used for the byte offset

// ARPROT & AWPROT flags
`define AXI_PROT_WIDTH 3

// BRESP & RRESP flags
`define AXI_RESP_WIDTH 2
`define AXI_RESP_OKAY 2'b00
`define AXI_RESP_EXOKAY 2'b01
`define AXI_RESP_SLVERR 2'b10
`define AXI_RESP_DECERR 2'b11

`define MEMORY_NUM_WORDS 1024 // Number of words in RAM (instruction and data)
`define MEMORY_INDEX_WIDTH $clog2(`MEMORY_NUM_WORDS)
`define MEMORY_ADDR_WIDTH (`MEMORY_INDEX_WIDTH + `AXI_ADDR_LSB)


`endif
