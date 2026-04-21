`timescale 1ns / 1ps

module write_fifo #(
    parameter integer ADDR_WIDTH = 32,
    parameter integer DATA_WIDTH = 64,
    parameter integer ID_WIDTH   = 4,
    parameter integer DEPTH      = 8,
    localparam integer WIDTH = ADDR_WIDTH + ID_WIDTH + 2 + 3 + 8
                             + DATA_WIDTH + DATA_WIDTH/8,
    localparam integer PTR_W = $clog2(DEPTH)
)(
    input  logic                      clk,
    input  logic                      rst_n,

    input  logic [ADDR_WIDTH-1:0]     awaddr,
    input  logic [ID_WIDTH-1:0]       awid,
    input  logic [1:0]                awburst,
    input  logic [2:0]                awsize,
    input  logic [7:0]                awlen,
    input  logic [DATA_WIDTH-1:0]     wdata,
    input  logic [DATA_WIDTH/8-1:0]   wstrb,
    input  logic                      push_awvalid,
    output logic                      push_awready,

    output logic                      pop_awvalid,
    input  logic                      pop_awready,
    output logic [WIDTH-1:0]          pop_data
);

    logic [WIDTH-1:0] mem [0:DEPTH-1];
    logic [PTR_W:0]   wr_ptr, rd_ptr, count;

    logic [WIDTH-1:0] push_data;
    assign push_data = {awaddr, awid, awburst, awsize, awlen, wdata, wstrb};

    logic full, empty;
    assign full         = (count == DEPTH[PTR_W:0]);
    assign empty        = (count == '0);
    assign pop_awvalid  = !empty;
    assign push_awready = !full;
    assign pop_data     = empty ? '0 : mem[rd_ptr];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= '0;
            rd_ptr <= '0;
            count  <= '0;
        end else begin
            if (push_awvalid && push_awready) begin
                mem[wr_ptr] <= push_data;
                wr_ptr      <= wr_ptr + 1'b1;
            end
            if (pop_awvalid && pop_awready)
                rd_ptr <= rd_ptr + 1'b1;
            case ({push_awvalid && push_awready, pop_awvalid && pop_awready})
                2'b10:   count <= count + 1'b1;
                2'b01:   count <= count - 1'b1;
                default: ;
            endcase
        end
    end

endmodule
