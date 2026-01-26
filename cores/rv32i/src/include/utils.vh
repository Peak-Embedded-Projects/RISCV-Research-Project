`ifndef UTILS_VH
`define UTILS_VH

`define ASSERT(signal, value) \
        if (signal !== value) begin \
            $error("[ERROR] in %m (%t): signal != value (%h != %h)", $time, signal, value); \
            $finish; \
        end

// DATA_DIR points to the location of the data folder.
// Since in Vivado xsim, relative paths are interpreted relative to its
// "xsim.dir" rather than the file's location, DATA_DIR needs to be set using a
// -define directive in xvlog (part of simulate.tcl).
`ifndef DATA_DIR
`define DATA_DIR "../../data/"
`endif

`endif
