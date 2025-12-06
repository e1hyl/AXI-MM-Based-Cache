module read_fifo(
    parameter integer ADDR_WIDTH = 64,
    parameter integer ID_WIDTH = 4,
    parameter integer DEPTH = 8
)(
    input logic clk,
    input logic rst_n,

    // push_data signals
    input logic arvalid,
    input logic [ADDR_WIDTH-1:0] araddr,
    input logic [ID_WIDTH-1:0] arid,
    input logic [1:0] arburst,
    input logic [2:0] arsize,
    input logic [7:0] arlen



);




endmodule